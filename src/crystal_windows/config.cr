module CrystalWindows
  class Config
    property control_socket_path, config_file_path, debug_mode

    @file_settings = {} of Symbol => String | Bool
    @cli_settings = {} of Symbol => String | Bool

    def initialize
      @config_file_path = (ENV["XDG_CONFIG_HOME"]? || "#{ENV["HOME"]}/.config").try do |base|
                            "#{base}/crystal_windows/config.yml"
                          end.as(String)

      # We have to parse the CLI args first (even though they have highest precedence) in case the
      # user specifies a nonstandard config file location.
      load_from_command_line
      load_from_config_file

      @control_socket_path = config_or_default(:control_socket_path, "/tmp/crystal_windows_control.socket").as(String) # TODO include machine name and X display
      @debug_mode = config_or_default(:debug_mode, false).as(Bool)
    end

    private def load_from_config_file
    end

    private def load_from_command_line
      OptionParser.parse do |parser|
        parser.banner = "Usage: crystal_windows [arguments]"
        parser.on("-c PATH", "--config=PATH", "Path to the config file") { |p| config_file_path = p }
        parser.on("-s PATH", "--socket=PATH", "Path to the control socket") { |p| @file_settings[:control_socket_path] = p }
        parser.on("-d", "--debug", "Enable debug output") { @file_settings[:debug_mode] = true }
        parser.on("-h", "--help", "Show this help") do
          puts parser
          exit
        end
        parser.invalid_option do |option|
          STDERR.puts "ERROR: #{option} is not a valid option."
          STDERR.puts parser
          exit 1
        end
      end
    end

    private def config_or_default(key, default)
      @cli_settings[key]? || @file_settings[key]? || default
    end
  end
end
