require "yaml"

require "./categories"
require "./window"

module CrystalWindows
  class Config
    property categories, control_socket_path, config_file_path, debug_mode

    @file_settings = YAML::Any #{} of Symbol => String | Bool
    @cli_settings = {} of Symbol => String | Bool
    @config_file_contents = {} of YAML::Any => YAML::Any

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
      @categories = Categories.new(
        @config_file_contents["categories"].as_a.map do |category_h|
          Category.new(
            name: category_h["name"].as_s,
            patterns: category_h["patterns"].as_a.map do |pattern| # TODO better name than "pattern"
                        if pattern.raw.is_a?(String)
                          { pattern: pattern.as_s, hints: { x: nil, y: nil, width: nil, height: nil } }
                        elsif pattern.raw.is_a?(Hash)
                          h = pattern.as_h
                          # Hashes in this situation must have exactly one element, hence #first
                          {
                            pattern: h.keys.first.as_s,
                            hints: h.values.first["hints"].as_h.try { |hints_h|
                                     {
                                       x: hints_h["x"].as_i?,
                                       y: hints_h["y"].as_i?,
                                       width: hints_h["width"].as_i?,
                                       height: hints_h["height"].as_i?
                                     }
                                   }
                          }
                        else
                          raise ConfigError.new("bad config") # TODO more detailed message
                        end
                      end
          )
        end
      )
    end

    private def load_from_config_file
      @config_file_contents = File.open(config_file_path) { |io| YAML.parse(io) }.as_h
      # TODO store these in @file_config so config_or_default can read them
    end

    private def load_from_command_line
      OptionParser.parse do |parser|
        parser.banner = "Usage: crystal_windows [arguments]"
        parser.on("-c PATH", "--config=PATH", "Path to the config file") { |p| config_file_path = p }
        parser.on("-s PATH", "--socket=PATH", "Path to the control socket") { |p| @cli_settings[:control_socket_path] = p }
        parser.on("-d", "--debug", "Enable debug output") { @cli_settings[:debug_mode] = true }
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
      #@cli_settings[key]? || @file_settings[key]? || default
      @cli_settings[key]? || default
    end
  end

  class ConfigError < Exception; end
end
