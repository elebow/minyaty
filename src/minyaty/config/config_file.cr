require "yaml"

module Minyaty
  class Config
    class ConfigFile
      @file_config = {} of YAML::Any => YAML::Any

      def initialize(path)
        @file_config = File.open(path) { |io| YAML.parse(io) }.as_h
      rescue File::NotFoundError
        puts "warning: could not open config file `#{path}`"
        @file_config = YAML.parse(<<-YAML).as_h
          categories:
            - name: uncategorized
              patterns: [""] # TODO patterns should not be specified for the magic "uncategorized" category
        YAML
      end

      def categories
        unless @file_config.has_key? "categories"
          puts "error: config file missing requried key `categories`"
          exit
        end

        @file_config["categories"].as_a.map do |category_h|
          {
            name: category_h["name"].as_s,
            patterns: category_h["patterns"].as_a.map do |pattern|
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
      end

      def config_file_path
        nil
      end

      def control_socket_path
        @file_config["socket"]?.try(&.as_s?)
      end

      def debug_mode?
        @file_config.has_key?("debug") && @file_config["debug"] == true
      end

      def taskbar_enabled?
        @file_config.has_key? "taskbar"
      end

      def taskbar_height
        return 0 unless taskbar_enabled?

        @file_config["taskbar"]["height"].as_i?
      end
    end
  end
end
