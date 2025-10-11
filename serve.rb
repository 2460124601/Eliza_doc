require "webrick"
root = File.expand_path("public")
server = WEBrick::HTTPServer.new(Port: 8080, DocumentRoot: root)
trap("INT") { server.shutdown }
puts "Serving #{root} at http://0.0.0.0:8080"
server.start
