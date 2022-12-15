require "./x"

# TODO library bug: It expects a X11::C::X::PGCValues instead of the non-pointer version.
# monkeypatch it for now
module X11
  class GCValues
    getter values : X11::C::X::GCValues

    def initialize(@values : X11::C::X::GCValues)
    end

    def to_unsafe : X11::C::X::PGCValues
      pointerof(@values)
    end
  end
end

# TODO library bug, typos: https://github.com/TamasSzekeres/x11-cr/blob/0e3b3bb7ff521867275571a5951bed4df2ab3b31/src/x11/set_window_attributes.cr#L38
# monkeypatch it for now
module X11
  class SetWindowAttributes
    def border_pixmap : X11::C::Pixmap
      @attributes.border_pixmap
    end

    def border_pixmap=(pixmap : X11::C::Pixmap)
      @attributes.border_pixmap = pixmap
    end
  end
end

# TODO library bug, missing drawable arg at https://github.com/TamasSzekeres/x11-cr/blob/master/src/x11/display.cr#L4081
module X11
  class Display
    def fill_rectangle(d : X11::C::Drawable, gc : X11::C::X::GC, x : Int32, y : Int32, width : UInt32, height : UInt32) : Int32
      X.fill_rectangle @dpy, d, gc, x, y, width, height
    end
  end
end

module Minyaty
  class TaskbarWindow
    getter win

    @win : X11::C::Window
    @gc : X11::C::X::GC
    @base_font : X11::FontStruct
    @bold_font : X11::FontStruct

    def initialize
      win_attrs = X11::SetWindowAttributes.new
      win_attrs.background_pixel = Minyaty::X::DISPLAY.default_screen.white_pixel # TODO should be able to pass this into the constructor
      win_attrs.border_pixmap = Minyaty::X::DISPLAY.default_screen.white_pixel
      win_attrs.event_mask = X11::C::ButtonReleaseMask
      @win = Minyaty::X::DISPLAY.create_window(
        parent: Minyaty::X::ROOT_WINDOW,
        x: 0,
        y: 0,
        width: Minyaty::X::SCREEN_WIDTH,
        height: CONFIG.taskbar_height.to_u,
        border_width: 0_u32,
        depth: 0,
        c_class: 0_u32,
        visual: Minyaty::X::DISPLAY.default_visual(Minyaty::X::DISPLAY.default_screen_number),
        valuemask: (1_u64 << 1) | (1_u64 << 11), # TODO library bug? attribute mask items like X11::C::CWBackPixel are i64, but valuemask arg must be u64
        attributes: win_attrs
      )
      Minyaty::X::DISPLAY.map_window(@win)

      gc_values = X11::GCValues.new(X11::C::X::GCValues.new)
      @gc = Minyaty::X::DISPLAY.create_gc(@win, 0, gc_values)
      # TODO use Xft instead of this legacy X11 font mechanism. There do not currently exist Crystal bindings for libxft.
      @base_font = Minyaty::X::DISPLAY.load_query_font("-*-clean-medium-r-*-*-16-*-*-*-*-*-*-*")
      @bold_font = Minyaty::X::DISPLAY.load_query_font("-*-clean-bold-r-*-*-16-*-*-*-*-*-*-*")

      @window_item_locations = [] of NamedTuple(left: Int32, right: Int32, win: Window) # This is redundant, but the compiler doesn't know that this variable will always be set before access
    end

    def refresh(category_regions)
      #TODO break up this method
      @window_item_locations = [] of NamedTuple(left: Int32, right: Int32, win: Window)

      Minyaty::X::DISPLAY.clear_window(@win)

      category_width = (Minyaty::X::SCREEN_WIDTH / category_regions.size).to_i # TODO weight by number of items? TODO leave space for clock, if configured
      category_regions.each_with_index do |category, i|
        Minyaty::X::DISPLAY.set_font(@gc, @base_font.to_x.fid)
        cursor = category_width * i
        Minyaty::X::DISPLAY.draw_line(@win, @gc, cursor, 0, cursor, 15)
        cursor += 4

        cat_label = "#{category[:name]}:"
        Minyaty::X::DISPLAY.draw_string(@win, @gc, cursor, 11, cat_label)
        cursor += @base_font.text_width(cat_label) + 10

        category[:windows].each do |w|
          w_left = cursor
          if Minyaty::X.current_window_id == w[:win].id
            Minyaty::X::DISPLAY.set_font(@gc, @bold_font.to_x.fid)
          else
            Minyaty::X::DISPLAY.set_font(@gc, @base_font.to_x.fid)
          end
          Minyaty::X::DISPLAY.draw_string(@win, @gc, cursor, 11, w[:text])
          cursor += @base_font.text_width(w[:text])

          @window_item_locations.push({ left: w_left, right: cursor, win: w[:win]})

          cursor += 10 # TODO configurable space between items
        end
      end

      cursor = (Minyaty::X::SCREEN_WIDTH - 120).to_i32
      Minyaty::X::DISPLAY.draw_string(@win, @gc, cursor, 11, Time.local.to_s("%Y-%m-%d %H:%M:%S"))

      Minyaty::X::DISPLAY.flush
    end

    def find_window_at_location(x)
      @window_item_locations.find { |w| w[:left] < x && w[:right] > x }
    end
  end
end
