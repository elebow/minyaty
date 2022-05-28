require "./category"

module Minyaty
  class CategoryAll < Category
    def initialize(name : String)
      super(name: name, patterns: [] of NamedTuple(pattern: String, hints: WindowHints))
    end

    def matching_windows(all_windows)
      all_windows
    end
  end
end
