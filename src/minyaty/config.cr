require "./config/config_cli"
require "./config/config_file"
require "./categories"
require "./window"

module Minyaty
  class Config
    property last_circulation_direction = :up

    def initialize
      # We have to parse the CLI args first (even though they have highest precedence) in case the
      # user specifies a nonstandard config file location.
      @config_cli = ConfigCLI.new

      config_file_path = @config_cli.config_file_path \
                         || (ENV["XDG_CONFIG_HOME"]? || "#{ENV["HOME"]}/.config").try do |base|
                              "#{base}/minyaty/config.yml"
                            end.as(String)

      @config_file = ConfigFile.new(config_file_path)
    end

    def categories
      @categories ||= Categories.new(@config_file.categories)
    end

    def control_socket_path
      @control_socket_path ||=
        config_or_default(:control_socket_path, "/tmp/minyaty_control.socket").as(String) # TODO include machine name and X display
    end

    def debug_mode?
      @debug_mode ||= config_or_default(:debug_mode?, false).as(Bool)
    end

    private macro config_or_default(key, default)
      @config_cli.{{key.id}} || @config_file.{{key.id}} || {{default}}
    end
  end
end
