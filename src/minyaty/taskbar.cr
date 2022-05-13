require "./taskbar_window"

module Minyaty
  class Taskbar
    getter taskbar_window

    def initialize
      @taskbar_window = TaskbarWindow.new
    end

    def refresh
      CONFIG.categories.refresh

      category_regions = CONFIG.categories.map do |category|
        {
          name: category.name,
          windows: category.windows.map do |w|
                     { text: w.properties["WM_CLASS"].try(&.last).to_s,
                       win: w }
                   end
        }
      end

      taskbar_window.refresh(category_regions)
    end

    def handle_click(x)
      win_item = taskbar_window.find_window_at_location(x)
      return unless win_item

      Minyaty.debug "taskbar handling click at #{x} - #{win_item[:win].properties["WM_CLASS"]}"
      win_item[:win].raise
    end
  end
end
