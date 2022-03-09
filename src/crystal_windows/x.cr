require "x11"

module CrystalWindows
  class X
    include X11::C

    # getter display, property_atoms : Array(X11::C::Atom)

    @@display = X11::Display.new
    @@root_window : X11::C::Window = @@display.root_window(0)
    @@property_atoms : Array(UInt64) = %w[WM_STATE WM_CLASS WM_NAME].map { |a| @@display.intern_atom(a, only_if_exists: true) }

    def self.all_windows
      query_all_windows(@@root_window)
    end

    def self.find_window(str : String)
      all_windows.select do |win|
        ["WM_CLASS", "WM_NAME"].any? do |key|
          values = win[:properties][key]
          values.is_a?(Array(String)) && values.any?(&.includes?(str))
        end
      end
    end

    def self.setup_event_monitoring
      @@display.select_input(@@root_window, X11::C::SubstructureNotifyMask | X11::C::SubstructureRedirectMask)
    end

    def self.raise_window(win : X11::C::Window)
      configure_window_fullscreen(win)
      map_above_and_focus(win)
    end

    def self.hide_current_window
      win = @@display.input_focus[:focus]
      @@display.unmap_window(win)
    end

    def self.handle_event(event)
      if event.is_a?(X11::ConfigureRequestEvent)
        configure_window_fullscreen(event.window)
      elsif event.is_a?(X11::MapRequestEvent)
        map_above_and_focus(event.window)
      elsif event.is_a?(X11::DestroyWindowEvent)
        # TODO decide where to put focus. subtract one from index in current viewport?
        # for now, just find and raise kitty
        raise_window(find_window("kitty").first[:id])
      else
        CrystalWindows.debug "Got event #{event}. Doing nothing."
      end
    end

    def self.pending_events
      @@display.pending
    end

    def self.next_event
      @@display.next_event
    end

    private def self.configure_window_fullscreen(win)
      @@display.configure_window(
        win,
        1_u32 << 0 | 1_u32 << 1 | 1_u32 << 2 | 1_u32 << 3 | 1_u32 << 6,
        X11::WindowChanges.new(X11::C::X::WindowChanges.new(x: 0, y:0, width: 1920, height: 1080, stack_mode: 0))
      )
    end

    private def self.map_above_and_focus(win)
      @@display.map_window(win)
      @@display.set_input_focus(win, X11::C::RevertToParent, X11::C::CurrentTime)
      # TODO bug? X11::C::RevertToNone is a UInt64 but set_input_focus wants a Int32
    end

    private def self.query_all_windows(root) : Array(NamedTuple(id: UInt64, properties: Hash(String, Array(String) | Array(UInt16) | Array(UInt32) | Nil), attributes: X11::C::X::WindowAttributes))
      # TODO rewrite this more nicely
      return @@display.query_tree(root)[:children]
                      .map { |child_id| build_hash(child_id) }
                      .reject { |h| h[:attributes].map_state == X11::C::IsUnmapped }
      # @@display.query_tree(root)[:children]
      #  .map do |child_id|
      #    [build_hash(child_id), query_all_windows(child_id)]
      #  #end.flatten.reject { |win| win[:properties]["WM_STATE"].nil? } # TODO 1 is normal, 3 is iconic. Use this information somehow.
      #  end.flatten

      ## How openbox removes insignificant windows:
      # reject any children with IconWindowHint and icon_window != the window itself
      # reject any of the WM's own windows
      # reject any unmapped children
    end

    private def self.build_hash(win)
      {
        id:         win,
        properties: @@property_atoms.to_h do |atom|
          {
            @@display.atom_name(atom),
            get_property(atom, win),
          }
        end,
        attributes: get_window_attributes(win)
        # TODO bug in library: Display#window_attributes calls #get_window_property ?
      }
    end

    private def self.get_property(atom, win)
      # We have to use `X` directly because the higher-level method converts the result to a String.
      # Sometimes, the result contains \0 characters. TODO explain better.
      # TODO bug? AnyPropertyType is i64, but #get_window_property wants u64)
      X11::C::X.get_window_property @@display, win, atom.to_u64, 0_i64, 1024_i64, X11::C::X::False, 0_u64, out actual_type_return, out actual_format_return, out nitems_return, out bytes_after_return, out prop_return
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

    private def self.get_window_attributes(win)
      X11::C::X.get_window_attributes(@@display, win, out window_attributes)
      window_attributes
    end
  end
end
