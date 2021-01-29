require 'net/http'
require 'coderay'
require 'json'
require 'erb'

require_relative 'log_http'

def human_status(code)
  return 'OK'                    if code == 200
  return 'Moved Permanently'     if code == 301
  return 'See Other'             if code == 303
  return 'Bad Request'           if code == 400
  return 'Forbidden'             if code == 403
  return 'Not Found'             if code == 404
  return 'Internal Server Error' if code == 500
  '*shrug* this isn\'t a real server'
end

def serve(port, routes, stream: $stdout)
  log = LogHttp.new stream: stream
  server = TCPServer.new 'localhost', port

  log.puts "======== Serving on port #{port} ========"

  not_found_handler = lambda do |request_headers, body|
    [404, { 'Content-Type' => 'text/html' }, '<p>Not Found</p>']
  end

  loop do
    socket = server.accept

    Timeout.timeout 1 do # don't @ me
      log.begin_connection
      request_line = socket.gets
      next unless request_line

      method, path, protocol = request_line.split
      log.request_line method, path, protocol

      request_headers = {}
      loop do
        line = socket.gets
        break if !line || line == "\r\n"
        name, value = line.chomp("\r\n").split(/:\s*/, 2)
        log.header name, value
        request_headers[name] = value
      end

      body = ''
      if request_headers['Content-Length']
        body = socket.read request_headers['Content-Length'].to_i
        log.line
        log.body body, request_headers['Content-Type']
      end

      log.section

      handler = routes[[method, path]]
      if !handler
        log.line "using 404 handler"
        log.section
        handler = not_found_handler
      end

      code, response_headers, body = handler.call request_headers, body
      response_headers['Content-Length'] = body.size.to_s
      response_headers['Connection'] = 'close'
      human_status = human_status code
      socket.print "#{protocol} #{code} #{human_status}\r\n"
      log.response_line protocol, code, human_status

      response_headers.each do |name, value|
        log.header name, value
        socket.puts "#{name}: #{value}\r\n"
      end
      log.line
      socket.puts "\r\n"
      unless body.empty?
        log.body body, response_headers['Content-Type']
        socket.print body
      end
    end
  rescue Timeout::Error
    log.error 'TIMEOUT!'
    log.line 'closing the socket'
    socket.close_read
    socket.close_write
  ensure
    log.end_connection
    socket.close unless socket.closed?
    log.puts
  end
end
