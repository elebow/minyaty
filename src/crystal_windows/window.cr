require "./x"

module CrystalWindows
  alias WindowHints = NamedTuple(x: Int32?, y: Int32?, width: Int32?, height: Int32?)

  class Window
    getter id, properties, attributes
    property hints

    @properties : Hash(String, Array(String) | Array(UInt16) | Array(UInt32) | Nil)
    @attributes : X11::C::X::WindowAttributes
    @hints : WindowHints

    def initialize(id : UInt64)
      @id = id
      @properties = X::PROPERTY_ATOMS.to_h do |atom|
                      {
                        X::DISPLAY.atom_name(atom),
                        X.get_property(atom, id),
                      }
                    end
      @attributes =  X.get_window_attributes(id)
          # TODO bug in library: Display#window_attributes calls #get_window_property ?
      @hints = { x: nil, y: nil, width: nil, height: nil }
    end

    def match?(pattern)
      ["WM_CLASS", "WM_NAME"].any? do |key|
        values = properties[key]
        values.is_a?(Array(String)) && values.any?(&.includes?(pattern))
      end
    end

    def raise
      X.raise_window(id, hints)
    end

    def to_s(io)
      io.puts "<#{self.class} id=#{id} properties=#{properties} attributes=#{attributes} hints=#{hints}>"
    end
  end
end
