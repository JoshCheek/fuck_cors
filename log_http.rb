class LogHttp
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
    line "\e[36;4;1m#{method}\e[0m \e[35m#{path}\e[0m #{protocol}"
  end

  def response_line(protocol, code, human_status)
    line "#{protocol} \e[35;4;m#{code}\e[0m #{human_status}"
  end

  def header(name, value)
    line "\e[34m#{name}:\e[0m #{value}" # keys are blue
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
end
