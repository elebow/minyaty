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
      CrystalWindows.debug "got nil command from socket"
    elsif string == "list-windows"
      CrystalWindows::X.all_windows.each { |win| puts win }
    elsif string.starts_with?("raise-window")
      pattern = string.lchop("raise-window").strip
      win = CrystalWindows::X.find_window(pattern).first
      CrystalWindows::X.raise_window(win[:id])
    elsif string.starts_with?("hide-current-window")
      CrystalWindows::X.hide_current_window
    elsif string == "exit"
      CrystalWindows.channel_send(:exit)
    else
      puts "unknown command: #{string}"
    end
  end
end
