module Minyaty
  class Config
    class ConfigCLI
      getter config_file_path, control_socket_path
      getter? debug_mode

      @config_file_path : String? = nil
      @control_socket_path : String? = nil
      @debug_mode = false

      def initialize
        OptionParser.parse do |parser|
          parser.banner = "Usage: minyaty [arguments]"
          parser.on("-c PATH", "--config=PATH", "Path to the config file") { |p| @config_file_path = p }
          parser.on("-s PATH", "--socket=PATH", "Path to the control socket") { |p| @control_socket_path = p }
          parser.on("-d", "--debug", "Enable debug output") { @debug_mode = true }
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

      def categories
        # Categories can only be defined in the config file, not on the command line # TODO support CLI categories, eventually
        nil
      end

      def taskbar_enabled?
        # TODO
        false
      end

      def taskbar_height
        # TODO
        nil
      end
    end
  end
end
