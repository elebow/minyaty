require "x11"

require "./window"

module CrystalWindows
  class X
    include X11::C

    DISPLAY = X11::Display.new
    ROOT_WINDOW = DISPLAY.root_window(0)
    PROPERTY_ATOMS = %w[WM_STATE WM_CLASS WM_NAME].map { |a| DISPLAY.intern_atom(a, only_if_exists: true) }

    def self.all_windows
      query_all_windows(ROOT_WINDOW)
    end

    def self.find_window(str : String)
      all_windows.select { |win| win.match?(str) }
    end

    def self.find_and_raise(str)
      # TODO if more than one window matches, cycle them in order of window id (which should be a proxy for age?)
      win = find_window(str).first?
      unless win
        CrystalWindows.debug "Tried to raise a window matching #{str}, but could not find any"
        return
      end
      raise_window(win.id)
    end

    def self.setup_event_monitoring
      DISPLAY.select_input(ROOT_WINDOW, X11::C::SubstructureNotifyMask | X11::C::SubstructureRedirectMask)
    end

    def self.raise_window(win : X11::C::Window, hints = { x: nil, y: nil, width: nil, height: nil })
      configure_window_size_position(win, **hints)
      map_above_and_focus(win)
    end

    def self.hide_current_window
      win = DISPLAY.input_focus[:focus]
      DISPLAY.unmap_window(win)
    end

    def self.handle_event(event)
      if event.is_a?(X11::ConfigureRequestEvent)
        # TODO If window should be configured (dialog box, etc). Also mpv. Maybe make this a default allow, with denials in the config, since only vivaldi's non-dialog windows so far are a problem?
        #configure_window_size_position(event.window)
      elsif event.is_a?(X11::MapRequestEvent)
        map_above_and_focus(event.window)
      elsif event.is_a?(X11::DestroyWindowEvent)
        # TODO decide where to put focus. subtract one from index in current viewport?
      end
    end

    def self.pending_events
      DISPLAY.pending
    end

    def self.next_event
      DISPLAY.next_event
    end

    private def self.configure_window_size_position(win, x = nil, y = nil, width = nil, height = nil)
      # TODO actual screen dimensions, in config object
      x ||= 0
      y ||= 0
      width ||= 1920
      height ||= 1080
      DISPLAY.configure_window(
        win,
        1_u32 << 0 | 1_u32 << 1 | 1_u32 << 2 | 1_u32 << 3 | 1_u32 << 6,
        X11::WindowChanges.new(X11::C::X::WindowChanges.new(x: x, y: y, width: width, height: height, stack_mode: 0))
      )
    end

    private def self.map_above_and_focus(win)
      DISPLAY.map_window(win)
      DISPLAY.set_input_focus(win, X11::C::RevertToParent, X11::C::CurrentTime)
      # TODO bug? X11::C::RevertToNone is a UInt64 but set_input_focus wants a Int32
    end

    private def self.query_all_windows(root) : Array(CrystalWindows::Window)
      return DISPLAY.query_tree(root)[:children]
                    .map { |child_id| CrystalWindows::Window.new(child_id) }
                    .reject { |h| h.attributes.map_state == X11::C::IsUnmapped }
    end

    private def self.build_hash(win)
      {
        id:         win,
        properties: @@property_atoms.to_h do |atom|
          {
            DISPLAY.atom_name(atom),
            get_property(atom, win),
          }
        end,
        attributes: get_window_attributes(win)
        # TODO bug in library: Display#window_attributes calls #get_window_property ?
      }
    end

    def self.get_property(atom, win)
      # We have to use `X` directly because the higher-level method converts the result to a String.
      # Sometimes, the result contains \0 characters. TODO explain better.
      # TODO bug? AnyPropertyType is i64, but #get_window_property wants u64)
      X11::C::X.get_window_property DISPLAY, win, atom.to_u64, 0_i64, 1024_i64, X11::C::X::False, 0_u64, out actual_type_return, out actual_format_return, out nitems_return, out bytes_after_return, out prop_return
      prop = {actual_type: actual_type_return, actual_format: actual_format_return, nitems: nitems_return, bytes_after: bytes_after_return, prop: prop_return}
      puts "incomplete get_window_property. #{prop}" if prop[:bytes_after] > 0

      ret = if prop[:actual_format] == 0
              nil
            elsif prop[:actual_format] == 8
              Slice.new(prop[:prop].as(UInt8*), prop[:nitems]).map(&.chr).join.chomp("\0").split("\0")
            elsif prop[:actual_format] == 16
              Slice.new(prop[:prop].as(UInt16*), prop[:nitems]).to_a
            elsif prop[:actual_format] == 32
              Slice.new(prop[:prop].as(UInt32*), prop[:nitems]).to_a
            else
              raise "unknown actual_format #{prop[:actual_format]}"
            end

      X11::C::X.free prop[:prop]

      ret
    end

    def self.get_window_attributes(win)
      X11::C::X.get_window_attributes(DISPLAY, win, out window_attributes)
      window_attributes
    end
  end
end
