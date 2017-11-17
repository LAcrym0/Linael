module Linael
  class Socketable
    attr_accessor :server, :port, :name, :on_restart

    def initialize(options)
      @name = options[:name].to_sym || options[:url]
      @port = options[:port]
      @server = options[:url]
      @socket = socket_klass.open(options[:url], options[:port])
      @writing_fifo = Linael::Fifo.new
    end

    def restart
      return if @on_restart
      begin
        on_restart = true
        @socket.close
        @socket = nil
        sleep 300
        @socket = socket_klass.open(server, port)
        on_restart = false
      rescue Exception
        retry
      end
    end

    def type
      raise NotImplementedError
    end

    def socket_klass
      raise NotImplementedError
    end

    def gets
      begin
        unless @on_restart
          message = @socket.gets
          return MessageStruct.new(name, message, type)
        end
      rescue Exception
        restart unless @on_restart
      end
      nil
    end

    def puts(msg)
      @socket.puts "#{msg}\n" unless @on_restart
    rescue Exception
      restart unless @on_restart
    end

    def close
      @socket.close
    end

    def stop_listen
      @thread.kill
      @writting_thread.kill
    end

    def write(msg)
      @writing_fifo.puts msg
    end

    def listen
      fifo = Linael::MessageFifo.instance
      @thread = Thread.new do
        loop do
          listening fifo
        end
      end
      @writting_thread = Thread.new do
        loop do
          writing
        end
      end
    end

    private

    def listening(fifo)
      line = gets unless @on_restart
      sleep(0.001)
      fifo.puts line if line&.element
    end

    def writing
      sleep(0.001)
      @timer ||= Time.now
      if Time.now > @timer
        line_to_write = @writing_fifo.gets unless @on_restart
        if line_to_write != :none
          puts line_to_write
          @timer = Time.now + 0.5
        end
      end
    end
  end
end
