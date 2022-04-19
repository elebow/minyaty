module Minyaty
  class Command
    getter string

    def self.run(string)
      new(string).run
    end

    def initialize(string : String?)
      @string = string.as(String)
    end

    def run
      if string.nil? || string.matches?(/\A\s*\Z/)
        Minyaty.debug "got nil command from socket"
      elsif string == "list-windows"
        X.all_windows.each { |win| puts win }
      elsif string.starts_with?("raise-window")
        CONFIG.categories.last_category = nil
        X.find_and_raise(string.lchop("raise-window").strip)
      elsif string.starts_with?("cycle-category")
        category_name = string.lchop("cycle-category").strip
        CONFIG.categories.cycle(category_name)
      elsif string.starts_with?("hide-current-window")
        X.hide_current_window
      elsif string.starts_with?("circulate-windows-down")
        CONFIG.last_circulation_direction = :down
        X.circulate_windows_down
      elsif string.starts_with?("circulate-windows-up")
        CONFIG.last_circulation_direction = :up
        X.circulate_windows_up
      elsif string.starts_with?("circulate-windows-alt")
        if CONFIG.last_circulation_direction == :down
          CONFIG.last_circulation_direction = :up
          X.circulate_windows_up
        else
          CONFIG.last_circulation_direction = :down
          X.circulate_windows_down
        end
      elsif string == "exit"
        CHANNEL.send(:exit)
      else
        puts "unknown command: #{string}"
      end
    end
  end
end
