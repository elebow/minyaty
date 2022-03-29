require "yaml"

require "./categories"
require "./window"

module CrystalWindows
  class Config
    getter categories, config_file_path

    @cli_settings = {} of Symbol => String | Bool
    @file_settings = {} of YAML::Any => YAML::Any
    @categories : Categories

    def initialize
      @config_file_path = (ENV["XDG_CONFIG_HOME"]? || "#{ENV["HOME"]}/.config").try do |base|
                            "#{base}/crystal_windows/config.yml"
                          end.as(String)

      # We have to parse the CLI args first (even though they have highest precedence) in case the
      # user specifies a nonstandard config file location.
      load_from_command_line
      load_from_config_file

      @categories = load_categories
    end

    private def load_categories
      # Categories can only be defined in the config file, not on the command line
      Categories.new(
        @file_settings["categories"].as_a.map do |category_h|
          {
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
                          STDERR.puts "Category pattern is not a string or a hash: #{pattern}"
                          { pattern: "", hints: { x: nil, y: nil, width: nil, height: nil } }
                        end
                      end
          }
        end
      )
    end

    def control_socket_path
      @control_socket_path ||=
        config_or_default(:control_socket_path, "/tmp/crystal_windows_control.socket").as(String) # TODO include machine name and X display
    end

    def debug_mode?
      @debug_mode ||= config_or_default(:debug_mode, false).as(Bool)
    end

    private def load_from_config_file
      @file_settings = File.open(config_file_path) { |io| YAML.parse(io) }.as_h
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
      @cli_settings[key]? || @file_settings[key]? || default
    end
  end
end
