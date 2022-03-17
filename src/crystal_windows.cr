require "option_parser"
require "socket"

require "./crystal_windows/command"
require "./crystal_windows/config"
require "./crystal_windows/x"

module CrystalWindows
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
  #   echo list-windows | socat UNIX-CONNECT:/tmp/crystal_windows_control.socket -
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
      # Xlib's XNextEvent blocks, but Crystal doesn't seem to know that, so this Fiber does yield
      # automatically. TODO: a way to declare a C function binding as blocking?
      # In the meantime, use a dumb polling loop. It's fine for this application.

      unless CrystalWindows::X.pending_events > 0
        sleep 0.1
        next
      end

      CrystalWindows::X.handle_event(CrystalWindows::X.next_event)
    end
  end

  # block the main fiber until we get an exit message (from the control fiber or a signal trap)
  until CHANNEL.receive == :exit; end

  socket.close
end
