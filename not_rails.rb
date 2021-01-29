require 'net/http'
require 'coderay'
require 'json'
require 'erb'

# Request  = Struct.new :method, :path, :protocol, :headers, :body
# Response = Struct.new :protocol, :status, :human_status, :headers, :body

class Log
  def initialize(stream:)
    self.stream = stream
  end

  def puts(str='')
    stream.puts str
  end

  def begin_connection
    section '.'
  end

  def line(str='')
    puts str.gsub(/^/, "#{frame '|'} ")
  end

  def section(lhs='|')
    puts frame "#{lhs}#{'-'*30}"
  end

  def end_connection
    section '`'
  end

  def request_line(method, path, protocol)
    method = hilight method if method == 'OPTIONS'
    line "\e[36;4;1m#{method}\e[0m \e[35m#{path}\e[0m #{protocol}"
  end

  def response_line(protocol, code, human_status)
    line "#{protocol} \e[35;4;m#{code}\e[0m #{human_status}"
  end

  def header(name, value)
    name = hilight name if name.start_with?('Access-Control') || name == 'Vary' || name == 'Origin'
    line "\e[34m#{name}\e[0m: #{value}" # keys are blue
  end

  def body(body, content_type)
    return if !body || body.empty?
    case content_type
    when /\b(html|xml)\b/
      body = CodeRay.encode body, :html, :terminal
    when /\bjson\b/
      body = CodeRay.encode body, :json, :terminal
    end
    line body
  end

  def error(message)
    line "\e[31m#{message}\e[0m" # red
  end

  private

  attr_accessor :stream, :pending_newline

  def frame(str)
    "\e[33m#{str}\e[0m" # orange
  end

  def print(str)
    stream.print str
  end

  def hilight(str)
    "\e[38;2;255;255;0m#{str}\e[0m" # bright yellow
  end
end

def human_status(code)
  return 'OK'                    if code == 200
  return 'No Content'            if code == 204
  return 'Moved Permanently'     if code == 301
  return 'See Other'             if code == 303
  return 'Bad Request'           if code == 400
  return 'Forbidden'             if code == 403
  return 'Not Found'             if code == 404
  return 'Internal Server Error' if code == 500
  '*shrug* this isn\'t a real server'
end

def serve(port, routes, stream: $stdout)
  log = Log.new stream: $stdout
  server = TCPServer.new 'localhost', port

  log.puts "======== Serving on port #{port} ========"

  not_found_handler = lambda do |request_headers, body|
    [404, { 'Content-Type' => 'text/html' }, '<p>Not Found</p>']
  end

  loop do
    socket = server.accept

    Timeout::timeout 1 do
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
