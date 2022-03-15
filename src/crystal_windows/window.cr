require "./x"

module CrystalWindows
  class Window
    getter id, properties, attributes
    property hints

    @properties : Hash(String, Array(String) | Array(UInt16) | Array(UInt32) | Nil)
    @attributes : X11::C::X::WindowAttributes
    @hints = {} of String => String

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
    end

    def match?(pattern)
      ["WM_CLASS", "WM_NAME"].any? do |key|
        values = properties[key]
        values.is_a?(Array(String)) && values.any?(&.includes?(pattern))
      end
    end

    def raise
      puts "about to raise #{id}. hints: #{hints}"
      X.raise_window(id)
    end

    def to_s(io)
      io.puts "<#{self.class} id=#{id} properties=#{properties} attributes=#{attributes} hints=#{hints}>"
    end
  end
end
