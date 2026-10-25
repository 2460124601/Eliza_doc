
require "digest"
require "rbconfig"
require "time"
require "open3"
require "fileutils"

ROOT   = File.expand_path(__dir__)
CONTENT_DIR  = File.join(ROOT, "content")
PUBLIC_DIR   = File.join(ROOT, "public")
TEMPLATE_ERB = File.join(ROOT, "template.html.erb")
BUILD_RB     = File.join(ROOT, "build.rb")

WATCH_EXTS = %w[.md .markdown .mkd .mkdn .mdown .erb .html .css .js .png .jpg .jpeg .gif .svg].freeze

TMP_DIR = File.join(ROOT, "tmp")
FileUtils.mkdir_p(TMP_DIR)
STAMP_PATH = File.join(TMP_DIR, ".stamp")

def files_to_watch
  content_files =
    Dir.glob(File.join(CONTENT_DIR, "**", "*"), File::FNM_DOTMATCH)
       .select { |f|
         File.file?(f) &&
           WATCH_EXTS.include?(File.extname(f).downcase) &&
           File.basename(f) !~ /(~$|\.swp$|\.tmp$|\.DS_Store\z)/i
       }

  core_files = [BUILD_RB, TEMPLATE_ERB].select { |f| File.file?(f) }

  (content_files + core_files).uniq
end

def snapshot
  dig = Digest::SHA256.new
  files = files_to_watch.sort
  files.each do |f|
    st = File.stat(f)
    dig.update(f)
    dig.update(st.size.to_s)
    dig.update(st.mtime.utc.to_f.to_s)
  end
  dig.hexdigest
end

def build_once
  puts "Rebuilding at #{Time.now.strftime("%H:%M:%S")}..."
  cmd = ["bundle", "exec", RbConfig.ruby, BUILD_RB]
  stdout_str, stderr_str, status = Open3.capture3({ "ELIZA_LIVE_RELOAD" => "1" }, *cmd)
  if status.success?
    File.write(STAMP_PATH, Time.now.to_i.to_s) rescue nil
    puts "Rebuilt."
    unless stdout_str.strip.empty?
      puts stdout_str
    end
  else
    puts "❌ Rebuild failed."
    $stderr.puts stderr_str
  end
end

def start_server
  port = ENV.fetch("PORT", "8080")
  bind = ENV.fetch("BIND", "0.0.0.0")
  puts "Serving #{PUBLIC_DIR} on http://#{bind}:#{port}"

  spawn("bundle", "exec", RbConfig.ruby, "-run", "-e", "httpd",
        PUBLIC_DIR, "-p", port.to_s, "-b", bind.to_s)
end

build_once
server_pid = start_server

at_exit do
  begin
    Process.kill("TERM", server_pid) if server_pid
  rescue StandardError
    # ignore
  end
end

puts "Watching: content/**/*, template.html.erb, build.rb"
puts "   (not watching public/** to avoid rebuild loops)"
prev_sig = snapshot

DEBOUNCE_SECONDS = 0.5
last_built_at = Time.at(0)

loop do
  sleep 0.8
  curr = snapshot
  next if curr == prev_sig

  now = Time.now
  if (now - last_built_at) < DEBOUNCE_SECONDS
    next
  end

  prev_sig = curr
  last_built_at = now
  build_once
end
