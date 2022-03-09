require "option_parser"
require "socket"

require "./crystal_windows/command"
require "./crystal_windows/config"
require "./crystal_windows/x"

module CrystalWindows
  VERSION = "0.1.0"

  @@config = Config.new

  def self.debug(str)
    puts str if @@config.debug_mode
  end

  def self.channel_send(x)
    @@channel.send(x)
  end

  socket = UNIXServer.new(@@config.control_socket_path)
  @@channel = Channel(Symbol).new

  # It's important to exit nicely so we don't leave a lingering socket
  Signal::INT.trap { channel_send(:exit) }
  Signal::KILL.trap { channel_send(:exit) }

  # Control fiber---monitors the control socket for commands from the user
  # Send commands with:
  #   echo GET | socat UNIX-CONNECT:/tmp/crystal_windows_control.socket -
  # TODO convenience tool (in this binary?) to do this
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
    CrystalWindows::X.setup_event_monitoring
    loop do
      # TODO use a blocking event loop with display.connection_number, IO::FileDescriptor
      pending_event_count = CrystalWindows::X.pending_events
      unless pending_event_count > 0
        sleep 0.1
        next
      end

      # Xlib's XNextEvent will block, which causes this Fiber to yield. TODO wait, does it?
      CrystalWindows::X.handle_event(CrystalWindows::X.next_event)
    end
  end

  # block the main fiber until we get an exit message (from the control fiber or a signal trap)
  until @@channel.receive == :exit; end

  socket.close
end
