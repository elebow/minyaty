require "option_parser"
require "socket"

require "./minyaty/command"
require "./minyaty/config"
require "./minyaty/taskbar"
require "./minyaty/x"

module Minyaty
  VERSION = "0.1.0"

  CONFIG = Config.new
  CHANNEL = Channel(Symbol).new
  TASKBAR = Taskbar.new

  def self.debug(str)
    puts str if CONFIG.debug_mode?
  end

  File.delete?(CONFIG.control_socket_path) # delete the control socket, and don't raise an exception if it doesn't exist
  socket = UNIXServer.new(CONFIG.control_socket_path)

  # It's important to exit nicely so we don't leave a lingering socket
  Signal::INT.trap { CHANNEL.send(:exit) }

  # Command fiber. Monitors the control socket for commands from the user.
  # Send commands with command.sh
  spawn do
    loop do
      connection = socket.accept?
      next unless connection
      Command.run(connection.gets)
      connection.close
    end
  end

  Minyaty::X.setup_error_handling
  Minyaty::X.setup_event_monitoring
  CONFIG.categories.refresh
  Minyaty::X.all_windows.each(&.raise) # Window#raise takes care of sizing and positioning
  # Event fiber. Monitors X11 events and reacts to them.
  spawn do
    loop do
      Minyaty::X.handle_pending_events

      sleep 0.05
    end
  end

  # Taskbar fiber. Periodically refreshes the items and clock.
  if CONFIG.taskbar_enabled?
    spawn do
      loop do
        TASKBAR.refresh
        sleep 1
      end
    end
  end

  # block the main fiber until we get an exit message (from the control fiber or a signal trap)
  until CHANNEL.receive == :exit; end

  socket.close
end
