require "option_parser"
require "socket"

require "./minyaty/command"
require "./minyaty/config"
require "./minyaty/x"

module Minyaty
  VERSION = "0.1.0"

  CONFIG = Config.new
  CHANNEL = Channel(Symbol).new

  def self.debug(str)
    puts str if CONFIG.debug_mode?
  end

  socket = UNIXServer.new(CONFIG.control_socket_path)

  # It's important to exit nicely so we don't leave a lingering socket
  Signal::INT.trap { CHANNEL.send(:exit) }

  # Control fiber---monitors the control socket for commands from the user
  # Send commands with:
  #   echo list-windows | socat UNIX-CONNECT:/tmp/minyaty_control.socket -
  spawn do
    loop do
      connection = socket.accept?
      next unless connection
      Command.run(connection.gets)
      connection.close
    end
  end

  # Event fiber---monitors X11 events and reacts to them
  spawn do
    Minyaty::X.setup_event_monitoring
    loop do
      Minyaty::X.wait_for_event
      Minyaty::X.handle_event(Minyaty::X.next_event)
    end
  end

  # block the main fiber until we get an exit message (from the control fiber or a signal trap)
  until CHANNEL.receive == :exit; end

  socket.close
end
