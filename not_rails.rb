require 'net/http'
require 'coderay'
require 'json'
require 'erb'

def serve(port, routes)
  server = TCPServer.new 'localhost', port

  puts "======== Serving on port #{port} ========"

  not_found_handler = lambda do |request_headers, body|
    [404, { 'Content-Type' => 'text/html' }, '<p>Not Found</p>']
  end

  loop do
    socket = server.accept

    Timeout::timeout 1 do
      print "\e[33m/\e[0m "
      request_line = socket.gets
      if !request_line
        puts
        puts "\e[33m\\\e[0m"
        socket.close
        next
      end
      method, path, protocol = request_line.split
      puts "\e[35m#{method}\e[0m request to \e[32m#{path.inspect}\e[0m"

      request_headers = {}
      loop do
        line = socket.gets
        break if !line || line == "\r\n"
        puts "\e[33m|\e[0m #{line.sub(/^[^:]*/, "\e[34m\\&\e[0m")}"
        name, value = line.chomp("\r\n").split(/:\s*/, 2)
        request_headers[name] = value
      end

      body = ''
      if request_headers['Content-Length']
        body = socket.read request_headers['Content-Length'].to_i
        puts
        puts body.gsub(/^/, "\e[33m|\e[0m ")
      end

      puts "\e[33m|----------------------------\e[0m"

      handler = routes[[method, path]]
      if !handler
        puts "\e[33m|\e[0m using 404 handler"
        puts "\e[33m|----------------------------\e[0m"
        handler = not_found_handler
      end

      status, response_headers, body = handler.call request_headers, body
      response_headers['Content-Length'] = body.size.to_s
      response_headers['Connection'] = 'close'
      response_line = "#{protocol} #{status} doesnt-matter"
      puts "\e[33m|\e[0m #{response_line.sub(/ \d+ /, "\e[35m\\&\e[0m")}"
      socket.print "#{response_line}\r\n"
      response_headers.each do |name, value|
        line = "#{name}: #{value}"
        puts "\e[33m|\e[0m #{line.sub(/^[^:]*/, "\e[34m\\&\e[0m")}"
        socket.puts "#{line}\r\n"
      end
      puts "\e[33m|\e[0m"
      socket.puts "\r\n"
      unless body.empty?
        pretty_body =
          case response_headers['Content-Type']
          when /\b(html|xml)\b/ then CodeRay.encode body, :html, :terminal
          when /\bjson\b/       then CodeRay.encode body, :json, :terminal
          else                       body
          end
        puts pretty_body.gsub(/^/, "\e[33m|\e[0m ")
        socket.print body
      end
      puts "\e[33m\\\e[0m"
      socket.close_read
      socket.close_write
      puts
    end
  rescue Timeout::Error
    puts "\e[31mTIMEOUT!\e[0"
    puts "\e[33m|\e[0m closing the socket"
    puts "\e[33m\\\e[0m"
    socket.close_read
    socket.close_write
  end
end
