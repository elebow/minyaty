require "./category"
require "./category_all"
require "./category_uncategorized"

module Minyaty
  class Categories
    getter categories
    property last_category

    @categories : Array(Category)
    @last_category : String?

    forward_missing_to @categories

    def initialize(categories)
      @categories = categories.map do |cat_h|
        case cat_h["name"]
        when "all"
          CategoryAll.new("all")
        when "uncategorized"
          CategoryUncategorized.new("uncategorized")
        else
          Category.new(cat_h["name"], patterns: cat_h["patterns"])
        end
      end
      @last_category = nil
    end

    def [](name)
      cats = categories.select { |cat| cat.name == name }
      return cats.first if cats.is_a?(Array) && cats.size == 1

      puts "Expected to find exactly one category named #{name} but instead found: #{cats}"
      categories.first # TODO return something more appropriate?
    end

    def cycle(name)
      refresh

      win = if name == last_category
              self[name].next
            else
              self[name].restart # TODO or resume, depending on config setting
            end
      win.raise if win

      # flush now because the event loop fiber might be blocked for a while
      Minyaty::X::DISPLAY.flush

      @last_category = name
    end

    def refresh
      Minyaty.debug "Categories#refresh:"
      # get list of all windows from X11
      all_windows = Minyaty::X.all_windows

      # pass the list to each category, which will save any matching window
      categories.each { |cat| cat.refresh(all_windows) }

      # TODO command to do the following, to help debugging configs:
      #puts categories.to_h { |cat| {cat.name, cat.windows.map(&.properties)} }
      Minyaty.debug "Categories#refresh: done"
    end
  end
end
