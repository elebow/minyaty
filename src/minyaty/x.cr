require "x11"

require "./window"

# TODO library bug: It calls `error_database_text` (which doesn't even exist) instead of `get_error_text`
# monkeypatch it for now
module X11
  class Display
    def error_text(code : Int32) : String
      buffer = Array(UInt8).new 1024
      X.get_error_text @dpy, code, buffer.to_unsafe, 1024
      String.new buffer.to_unsafe
    end
  end
end

module Minyaty
  class X
    include X11::C

    DISPLAY = X11::Display.new
    ROOT_WINDOW = DISPLAY.root_window(0)
    SCREEN_WIDTH = DISPLAY.width(DISPLAY.default_screen_number).to_u32
    SCREEN_HEIGHT = DISPLAY.height(DISPLAY.default_screen_number)
    ATOMS = {
      useful_properties: %w[WM_STATE WM_CLASS WM_NAME].map { |a| intern_atom(a) },
      maximized: Slice[intern_atom("_NET_WM_STATE_MAXIMIZED_HORZ"),
                       intern_atom("_NET_WM_STATE_MAXIMIZED_VERT")],
      XA_NET_WM_STATE: intern_atom("_NET_WM_STATE"),
      XA_NET_FRAME_EXTENTS: intern_atom("_NET_FRAME_EXTENTS")
    }

    def self.all_windows
      query_all_windows(ROOT_WINDOW)
    end

    def self.current_window
      DISPLAY.input_focus[:focus]
    end

    def self.find_window(str : String)
      all_windows.select { |win| win.match?(str) }
    end

    def self.find_and_raise(str)
      # TODO if more than one window matches, cycle them in order of window id (which should be a proxy for age?)
      win = find_window(str).first?
      unless win
        Minyaty.debug "Tried to raise a window matching #{str}, but could not find any"
        return
      end
      raise_window(win.id)
    end

    def self.setup_event_monitoring
      DISPLAY.select_input(ROOT_WINDOW, X11::C::SubstructureNotifyMask | X11::C::SubstructureRedirectMask)
    end

    def self.setup_error_handling
      error_handler = ->(display : X11::C::X::PDisplay, error_event : X11::C::X::PErrorEvent) {
        Minyaty.debug "X11 error: #{DISPLAY.error_text(error_event.value.error_code)}"
        return 0
      }
      X11.set_error_handler(error_handler)
    end

    def self.raise_window(win : X11::C::Window, hints = { x: nil, y: nil, width: nil, height: nil })
      configure_window_size_position(win, **hints)
      map_above_and_focus(win)
    end

    def self.hide_current_window
      DISPLAY.unmap_window(current_window)
    end

    def self.circulate_windows_down
      DISPLAY.circulate_subwindows_down(ROOT_WINDOW)
      DISPLAY.flush
    end

    def self.circulate_windows_up
      DISPLAY.circulate_subwindows_up(ROOT_WINDOW)
      DISPLAY.flush
    end

    def self.handle_event(event)
      if event.is_a?(X11::ConfigureRequestEvent)
        Minyaty.debug "handle ConfigureRequestEvent: #{event.detail}"

        # TODO If window should be configured (dialog box, etc). Also mpv. Maybe make this a default allow, with denials in the config, since only vivaldi's non-dialog windows so far are a problem?
        #configure_window_size_position(event.window)
        Minyaty.debug "handle ConfigureRequestEvent: done"
      elsif event.is_a?(X11::MapRequestEvent)
        Minyaty.debug "handle MapRequestEvent: #{event.window}"
        map_above_and_focus(event.window)
        Minyaty::TASKBAR.refresh if Minyaty::TASKBAR
        Minyaty.debug "handle MapRequestEvent: done"
      elsif event.is_a?(X11::DestroyWindowEvent)
        # TODO decide where to put focus. subtract one from index in current viewport?
        Minyaty::TASKBAR.refresh if Minyaty::TASKBAR
      elsif event.is_a?(X11::ButtonEvent) && event.release? && event.window == TASKBAR.taskbar_window.win
        # TODO send events more generically, somehow. This X utility class shouldn't even know that Minyaty::TASKBAR exists.
        Minyaty::TASKBAR.handle_click(x: event.x)
      end
    end

    def self.handle_pending_events
      DISPLAY.pending.times { handle_event(DISPLAY.next_event) }
    end

    private def self.configure_window_size_position(win, x = nil, y = nil, width = nil, height = nil)
      Minyaty.debug "configure_window_size_and_position: win=#{win}"
      x ||= 0
      y ||= CONFIG.taskbar_height
      width ||= SCREEN_WIDTH
      height ||= SCREEN_HEIGHT - CONFIG.taskbar_height
      DISPLAY.configure_window(
        win,
        1_u32 << 0 | 1_u32 << 1 | 1_u32 << 2 | 1_u32 << 3 | 1_u32 << 6,
        X11::WindowChanges.new(X11::C::X::WindowChanges.new(x: x, y: y, width: width, height: height, stack_mode: 0))
      )
      X11::C::X.change_property DISPLAY, win, ATOMS[:XA_NET_WM_STATE], X11::Atom::Atom, 32, PropModeReplace, ATOMS[:maximized].to_unsafe.as(PChar), 2
      X11::C::X.change_property DISPLAY, win, ATOMS[:XA_NET_FRAME_EXTENTS], X11::Atom::Cardinal, 32, PropModeReplace, Slice[0_i64, 0_i64, 0_i64, 0_i64].to_unsafe.as(PChar), 4
      # TODO should be this, but library is missing overload? DISPLAY.change_property(win, XA_NET_FRAME_EXTENTS, X11::Atom::Cardinal, PropModeReplace, Slice[0_u64, 0_u64, 0_u64, 0_u64])
      Minyaty.debug "configure_window_size_and_position: done"
    end

    private def self.map_above_and_focus(win)
      Minyaty.debug "map_above_and_focus: win=#{win}"
      DISPLAY.map_window(win)
      DISPLAY.set_input_focus(win, X11::C::RevertToParent, X11::C::CurrentTime)
      # TODO bug? X11::C::RevertToNone is a UInt64 but set_input_focus wants a Int32
      DISPLAY.flush
      Minyaty.debug "map_above_and_focus: done"
    end

    private def self.query_all_windows(root) : Array(Minyaty::Window)
      Minyaty.debug "query_all_windows:"
      return DISPLAY.query_tree(root)[:children]
                    .map { |child_id| Minyaty::Window.new(child_id) }
                    .reject { |h| h.attributes.map_state == X11::C::IsUnmapped }
                    .reject { |h| h.id == TASKBAR.taskbar_window.win }
                    .tap { Minyaty.debug "query_all_windows: done" }
    end

    private def self.build_hash(win)
      {
        id:         win,
        properties: ATOMS[:useful_properties].to_h do |atom|
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
      Minyaty.debug "get_property: atom=#{atom}, window=#{win}"
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

      Minyaty.debug "get_property: done"
      ret
    end

    def self.get_window_attributes(win)
      X11::C::X.get_window_attributes(DISPLAY, win, out window_attributes)
      window_attributes
    end

    def self.intern_atom(name)
      DISPLAY.intern_atom(name, only_if_exists: false)
    end
  end
end
