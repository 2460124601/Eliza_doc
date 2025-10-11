require "yaml"
require "erb"
require "fileutils"
require "kramdown"
require "nokogiri"
require "kramdown-parser-gfm"
require "set"
require "json"

def load_config(path)
  return {} unless File.file?(path)
  YAML.safe_load_file(
    path,
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false
  ) || {}
rescue StandardError
  {}
end

def dig_flex(h, *keys)
  keys.reduce(h) do |acc, k|
    break nil unless acc.is_a?(Hash)
    acc.key?(k) ? acc[k] : acc[(k.is_a?(Symbol) ? k.to_s : k.to_sym)]
  end
end

CONFIG = load_config(File.join(__dir__, "config", "config.yml"))

DEFAULT_LANG    = ENV["ELIZA_DEFAULT_LANG"]    || dig_flex(CONFIG, "defaults", "lang")    || "zh-TW"
DEFAULT_VERSION = ENV["ELIZA_DEFAULT_VERSION"] || dig_flex(CONFIG, "defaults", "version") 
keeps_from_cfg  = dig_flex(CONFIG, "defaults", "keeps")
KEEPS           = (keeps_from_cfg.is_a?(Array) ? keeps_from_cfg : [])
KEEPS           = %w[assets prism-okaidia.min.css favicon.ico robots.txt] if KEEPS.empty?

ROOT    = File.expand_path(__dir__)
CONTENT = File.join(ROOT, "content")
PUBLIC  = File.join(ROOT, "public")

FileUtils.mkdir_p(PUBLIC)

Dir.children(PUBLIC).each do |entry|
  path = File.join(PUBLIC, entry)
  next if KEEPS.include?(entry)
  File.delete(path) if File.file?(path) && File.extname(path) == ".html"
end

def slugify(s)
  s.to_s.downcase.strip
    .gsub(/<.*?>/, "")
    .gsub(/[^a-z0-9\u4e00-\u9fa5\- ]/i, "")
    .gsub(/\s+/, "-")
end

Dir.glob(File.join(CONTENT, "**", "*"), File::FNM_DOTMATCH).each do |src|
  next if File.directory?(src)
  next if File.extname(src).downcase == ".md"
  rel = src.sub(%r{\A#{Regexp.escape(CONTENT)}[\\/]}, "")
  dst = File.join(PUBLIC, rel)
  FileUtils.mkdir_p(File.dirname(dst))
  FileUtils.cp(src, dst)
end

LANG_PATTERN    = /\A[a-z]{2}(?:-[a-z]{2,3})?\z/i
VERSION_PATTERN = /\Av?\d+(?:\.\d+)*\z/i

def normalize_lang(tag)
  parts = tag.to_s.split('-')
  return "zh-TW" if parts.empty? || parts[0].to_s.empty?
  base = parts[0].downcase
  rest = parts[1..].map { |p| p.upcase }
  ([base] + rest).join('-')
end

def normalize_ver(v)
  s = v.to_s
  s = "v#{s}" unless s.start_with?('v','V')
  s.downcase
end

def parse_lang_version_from_path(path)
  base = path
  rel = base.sub(%r{\A#{Regexp.escape(CONTENT)}[\\/]}, "")
  parts = rel.split(/[\\\/]/)
  return [nil, nil] unless parts.size >= 3
  a, b = parts[0], parts[1]

  if a =~ LANG_PATTERN && b =~ VERSION_PATTERN
    [normalize_lang(a), normalize_ver(b)]
  elsif a =~ VERSION_PATTERN && b =~ LANG_PATTERN
    [normalize_lang(b), normalize_ver(a)]
  else
    [nil, nil]
  end
end

md_files = Dir.glob(File.join(CONTENT, "**", "*.md"))
puts "[build] Found #{md_files.size} markdown files under #{CONTENT}"

records = []

md_files.each do |path|
  raw = File.read(path, encoding: "UTF-8")
  fm  = {}
  md  = raw

  if raw.lstrip.start_with?('---') && raw =~ /\A---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)\z/m
    fm_text = Regexp.last_match(1)
    md      = Regexp.last_match(2)
    fm = YAML.safe_load(
      fm_text,
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false
    ) || {}
  end

  lang0, ver0 = parse_lang_version_from_path(path)
  lang = normalize_lang(fm["lang"] || lang0 || DEFAULT_LANG || "zh-TW")
  ver  = normalize_ver(fm["version"] || ver0 || DEFAULT_VERSION || "v1")
  aliases = Array(fm["aliases"]).compact.map(&:to_s)

  puts "  - #{path.sub(ROOT + '/', '')} => lang=#{lang.inspect}, version=#{ver.inspect}"

  title = fm["title"] || File.basename(path, ".md")
  slug  = fm["slug"]  || slugify(File.basename(path, ".md"))
  order = fm["order"] || 9999

  html = Kramdown::Document.new(md, input: "GFM", hard_wrap: false).to_html

  frag = Nokogiri::HTML::DocumentFragment.parse(html)
  sections   = []
  current_h2 = nil

  frag.css("h2, h3").each do |h|
    text = h.inner_text
    id   = h["id"].to_s.strip
    id   = "#{slugify(slug)}-#{slugify(text)}" if id.empty?
    h["id"] = id
    href = "##{id}"

    if h.name == "h2"
      current_h2 = { text: text, href: href, children: [] }
      sections << current_h2
    else
      if current_h2
        current_h2[:children] << { text: text, href: href }
      else
        sections << { text: text, href: href, children: [] }
      end
    end
  end
  toc = sections

  frag.css("img").each do |img|
    classes = img["class"].to_s.split(/\s+/)
    classes << "showImage" unless classes.include?("showImage")
    img["class"] = classes.join(" ").strip

    src = img["src"].to_s.strip
    case src
    when /\A\.?\/?assets\//i
      img["src"] = "/" + src.sub(/\A\.?\//, "")
    when /\A\.?\/?images\//i
      img["src"] = "/assets/" + src.sub(/\A\.?\//, "")
    end
  end

  frag.css('script[src], link[href], source[src], video[src], audio[src]').each do |el|
    %w[src href].each do |attr|
      next unless el.has_attribute?(attr)
      v = el[attr].to_s.strip
      next if v.empty?
      if v =~ /\A\.?\/?assets\//i
        el[attr] = "/" + v.sub(/\A\.?\//, "")
      elsif v =~ /\A\.?\/?images\//i
        el[attr] = "/assets/" + v.sub(/\A\.?\//, "")
      end
    end
  end

  html = frag.to_html
  html = html
           .gsub(/(\s(?:src|href)=["'])\.?\/?assets\//i, '\1/assets/')
           .gsub(/(\s(?:src|href)=["'])\.?\/?images\//i, '\1/assets/images/')

  filename_key = File.basename(path, ".md")

  records << {
    lang: lang, version: ver, title: title, slug: slug, order: order,
    html: html, toc: toc, src_path: path, key: filename_key, aliases: aliases
  }
end

puts "[build] Parsed #{records.size} records"

def version_key(v)
  v.to_s.sub(/\Av/i, "").split(".").map { |x| x.to_i }
end
versions = records.map { |r| r[:version] }.uniq.sort_by { |v| version_key(v) }
versions = ["v1"] if versions.empty?
latest_version = versions.max_by { |v| version_key(v) }

languages = records.map { |r| r[:lang] }.uniq
puts "[build] Languages: #{languages.inspect}"
puts "[build] Versions:  #{versions.inspect} (latest=#{latest_version})"

groups = Hash.new { |h,k| h[k] = [] }
records.each { |r| groups[[r[:lang], r[:version]]] << r }
groups.each_value { |arr| arr.sort_by! { |p| [p[:order], p[:slug]] } }

if groups.empty?
  warn "[build] WARNING: no groups to render. Check your content layout and patterns."
end

groups.each do |(_lang, _ver), pages|
  counter = 0
  pages.each_with_index do |p, i|
    if p[:slug].to_s.strip.downcase == "index" || i == 0
      p[:is_index]     = true
      p[:out_filename] = "index.html"
    else
      counter         += 1
      p[:num2]         = format("%02d", counter)
      p[:out_filename] = "#{p[:num2]}-#{p[:slug]}.html"
    end
  end
end

map_by_lang_and_key = Hash.new { |h,k| h[k] = {} }
groups.each do |(lang, ver), pages|
  pages.each do |p|
    map_by_lang_and_key[lang][p[:key]] ||= {}
    map_by_lang_and_key[lang][p[:key]][ver] = "/#{lang}/#{ver}/#{p[:out_filename]}"
  end
end

def nearest_version_href(map, lang, key, versions, prefer_ver)
  map.dig(lang, key, prefer_ver) ||
    versions.reverse.map { |v| map.dig(lang, key, v) }.compact.first
end

template_path = File.join(ROOT, "template.html.erb")
template = ERB.new(File.read(template_path, encoding: "UTF-8"), trim_mode: "-")

EXPECTED_HTML = Set.new

MANIFEST_PATH = File.join(PUBLIC, ".manifest.json")
prev_manifest = {}
begin
  prev_manifest = JSON.parse(File.read(MANIFEST_PATH))
rescue
  prev_manifest = {}
end
new_manifest = {}

groups.each do |(lang, ver), pages|
  puts "[build] Rendering #{lang}/#{ver} (#{pages.size} pages)"

  out_dir = File.join(PUBLIC, lang, ver)
  FileUtils.mkdir_p(out_dir)

  nav = pages.map { |p| { title: p[:title], href: "./#{p[:out_filename]}" } }

  pages.each do |page|
    key = page[:key]

    alt_langs = languages.map do |l|
      { lang: l, href: nearest_version_href(map_by_lang_and_key, l, key, versions, ver) }
    end

    alt_versions = versions.map do |v|
      { version: v, href: map_by_lang_and_key.dig(lang, key, v) }
    end

    out = template.result_with_hash(
      page: page, nav: nav, html: page[:html], toc: page[:toc],
      current_lang: lang, current_version: ver,
      alt_langs: alt_langs, alt_versions: alt_versions
    )

    out_fullpath = File.join(out_dir, page[:out_filename])
    EXPECTED_HTML << out_fullpath
    File.write(out_fullpath, out, encoding: "UTF-8")

    new_manifest[lang] ||= {}
    new_manifest[lang][ver] ||= {}
    new_manifest[lang][ver][key] = page[:out_filename]

    Array(page[:aliases]).each do |ali|
      ali_fname =
        if ali.end_with?(".html")
          ali
        else
          "#{page.fetch(:num2, '00')}-#{slugify(ali)}.html"
        end
      ali_fullpath = File.join(out_dir, ali_fname)
      next if ali_fullpath == out_fullpath

      EXPECTED_HTML << ali_fullpath
      redirect_html = <<~HTML
        <!doctype html><meta charset="utf-8">
        <meta http-equiv="refresh" content="0; url=./#{ERB::Util.h(page[:out_filename])}">
        <link rel="canonical" href="./#{ERB::Util.h(page[:out_filename])}">
        <title>Moved</title>
        <p>Moved to <a href="./#{ERB::Util.h(page[:out_filename])}">here</a>.</p>
      HTML
      File.write(ali_fullpath, redirect_html, encoding: "UTF-8")
      puts "[alias] #{lang}/#{ver}/#{ali_fname} → #{page[:out_filename]}"
    end
  end

  not_found = <<~HTML
    <!doctype html><meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=/">
    <title>404 Not Found</title>
    <p>Page not found. Redirecting to <a href="/">home</a>…</p>
    <script>location.replace("/");</script>
  HTML
  not_found_path = File.join(out_dir, "404.html")
  EXPECTED_HTML << not_found_path
  File.write(not_found_path, not_found, encoding: "UTF-8")
end

root_index = <<~HTML
<!doctype html>
<html lang="#{DEFAULT_LANG}">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=/#{DEFAULT_LANG}/#{latest_version}/">
<title>Redirecting…</title>
<script>location.replace("/#{DEFAULT_LANG}/#{latest_version}/");</script>
<link rel="canonical" href="/#{DEFAULT_LANG}/#{latest_version}/">
</head>
<body>
<p>Redirecting to <a href="/#{DEFAULT_LANG}/#{latest_version}/">latest docs</a>…</p>
</body>
</html>
HTML
root_index_path = File.join(PUBLIC, "index.html")
EXPECTED_HTML << root_index_path
File.write(root_index_path, root_index, encoding: "UTF-8")

root_404 = <<~HTML
  <!doctype html><meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=/">
  <title>404 Not Found</title>
  <p>Page not found. Redirecting to <a href="/">home</a>…</p>
  <script>location.replace("/");</script>
HTML
root_404_path = File.join(PUBLIC, "404.html")
EXPECTED_HTML << root_404_path
File.write(root_404_path, root_404, encoding: "UTF-8")

prev_manifest.each do |lang, vs|
  vs.each do |ver, ks|
    ks.each do |key, old_fname|
      new_fname = new_manifest.dig(lang, ver, key)
      next if new_fname.nil? || old_fname == new_fname

      dir = File.join(PUBLIC, lang, ver)
      old_full = File.join(dir, old_fname)
      next if EXPECTED_HTML.include?(old_full)

      FileUtils.mkdir_p(dir)
      EXPECTED_HTML << old_full
      File.write(old_full, <<~HTML, encoding: "UTF-8")
        <!doctype html><meta charset="utf-8">
        <meta http-equiv="refresh" content="0; url=./#{ERB::Util.h(new_fname)}">
        <link rel="canonical" href="./#{ERB::Util.h(new_fname)}">
        <title>Moved</title>
        <p>Moved to <a href="./#{ERB::Util.h(new_fname)}">here</a>.</p>
      HTML
      puts "[alias] #{lang}/#{ver}/#{old_fname} → #{new_fname} (manifest)"
    end
  end
end

File.write(File.join(PUBLIC, ".manifest.json"), JSON.pretty_generate(new_manifest), encoding: "UTF-8")

all_html = Dir.glob(File.join(PUBLIC, "**", "*.html"))
all_html.each do |p|
  rel = p.sub(%r{\A#{Regexp.escape(PUBLIC)}[\\/]}, "")
  next if rel.start_with?("assets/") || KEEPS.include?(rel)
  next if EXPECTED_HTML.include?(p)
  File.delete(p) rescue nil
  puts "[prune] removed orphan #{rel}"
end

Dir.glob(File.join(PUBLIC, "**", "*"))
  .select { |d| File.directory?(d) }
  .sort_by { |d| -d.length }
  .each { |d| Dir.rmdir(d) rescue nil }

File.write(File.join(PUBLIC, ".stamp"), Time.now.to_i.to_s) rescue nil

puts "Built #{records.size} pages → #{PUBLIC}"
