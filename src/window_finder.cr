require "x11"

class WindowFinder
  include X11::C

  getter display, property_atoms : Array(X11::C::Atom)

  def initialize
    @display = X11::Display.new
    @property_atoms = %w[WM_STATE WM_CLASS WM_NAME].map { |a| @display.intern_atom(a, only_if_exists: true) }
  end

  def all_windows
    find_windows(display.root_window(0))
  end

  private def find_windows(root) : Array(NamedTuple(id: UInt64, properties: Hash(String, Array(String) | Array(UInt16) | Array(UInt32) | Nil)))
    # TODO rewrite this more nicely
    display.query_tree(root)[:children]
      .map do |child_id|
        [build_hash(child_id), find_windows(child_id)]
      end.flatten.reject { |win| win[:properties]["WM_STATE"].nil? } # TODO 1 is normal, 3 is iconic
  end

  private def build_hash(win)
    {
      id:         win,
      properties: property_atoms.to_h do |atom|
        {
          display.atom_name(atom),
          get_property(atom, win),
        }
      end,
    }
  end

  private def get_property(atom, win)
    # We have to use `X` directly because the higher-level method converts the result to a String.
    # Sometimes, the result contains \0 characters. TODO explain better.
    # TODO bug? AnyPropertyType is i64, but #get_window_property wants u64)
    X.get_window_property display, win, atom.to_u64, 0_i64, 1024_i64, X::False, 0_u64, out actual_type_return, out actual_format_return, out nitems_return, out bytes_after_return, out prop_return
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

    X.free prop[:prop]

    ret
  end
end
