require "./category"

module CrystalWindows
  class Categories
    getter categories, last_category

    @categories : Array(CrystalWindows::Category)
    @last_category : String?

    def initialize(categories_config : Array(NamedTuple))
      @categories = categories_config.map do |category_config|
        Category.new(**category_config)
      end
      @last_category = nil
    end

    def [](name)
      # TODO magic names "all" "uncategorized"
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

      @last_category = name
    end

    def refresh
      # get list of all windows from X11
      all_windows = CrystalWindows::X.all_windows

      # pass the list to each category, which will save any matching window
      categories.each { |cat| cat.refresh(all_windows) }

      # TODO command to do the following, to help debugging configs:
      #puts categories.to_h { |cat| {cat.name, cat.windows.map(&.properties)} }
    end
  end
end
