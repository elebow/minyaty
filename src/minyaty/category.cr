require "./window"

module Minyaty
  class Category
    property name, patterns, windows, pointer

    def initialize(name : String, patterns : Array(NamedTuple(pattern: String, hints: WindowHints)))
      @name = name
      @patterns = patterns
      @windows = [] of Window
      @pointer = 0
    end

    # takes a list of windows and stores the ones that match a pattern
    def refresh(all_windows)
      last_id = windows.size > 0 ? windows[pointer].id : 0

      # We want the windows to be sorted by pattern order (as defined in config), then by window_id
      # for windows with the same pattern. X11 assigns window IDs unpredictably, but it's good enough.
      self.windows = patterns.map do |pattern|
                                    all_windows.select do |win|
                                      match = win.match?(pattern[:pattern])
                                      # Augment Window obj with hints. Window#raise will use them if
                                      # present. We have to do this here because a given window may
                                      # have different hints each place it appears.
                                      win.hints = pattern[:hints] if match
                                      match
                                    end.sort_by { |win| win.id }
                             end
                             .reduce { |a, b| a + b } # TODO crystal's Array#reduce should be able to take just a symbol like Ruby's

      #advance to where we left off, or start from the beginning again
      self.pointer = windows.index { |win| win.id == last_id } || 0
    end

    def window_at_pointer
      windows.fetch(pointer, nil)
    end

    def resume
      window_at_pointer
    end

    def next
      self.pointer += 1
      self.pointer = 0 if pointer >= windows.size
      window_at_pointer
    end

    def restart
      self.pointer = 0
      window_at_pointer
    end
  end
end