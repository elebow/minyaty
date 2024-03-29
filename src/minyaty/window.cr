require "./x"

module Minyaty
  alias WindowHints = NamedTuple(x: Int32?, y: Int32?, width: Int32?, height: Int32?)

  class Window
    getter id, properties, attributes
    property hints

    @properties : Hash(String, Array(String) | Array(UInt16) | Array(UInt32) | Nil)
    @attributes : X11::C::X::WindowAttributes
    @hints : WindowHints

    def initialize(id : UInt64)
      Minyaty.debug "Window#initialize: id=#{id}"
      @id = id
      @properties = X::ATOMS[:useful_properties].to_h do |atom|
                      {
                        X::DISPLAY.atom_name(atom), # TODO we can store the atom name when we intern them to save some X11 requests here
                        X.get_property(atom, id),
                      }
                    end
      @attributes =  X.get_window_attributes(id)
          # TODO bug in library: Display#window_attributes calls #get_window_property ?
      @hints = { x: nil, y: nil, width: nil, height: nil }
      @categorized = false
      Minyaty.debug "Window#initialize: done (#{@properties["WM_CLASS"]}, #{@properties["WM_NAME"]})"
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

    def dialog?
      properties["_NET_WM_WINDOW_TYPE"].try(&.first) == X::ATOMS[:_NET_WM_WINDOW_TYPE_DIALOG]
    end

    def mark_categorized
      @categorized = true
    end

    def uncategorized?
      !@categorized
    end

    def to_s(io)
      io.puts "<#{self.class} #{id} #{properties["WM_CLASS"].try(&.join(","))}>"
    end

    def inspect(io)
      io.puts "<#{self.class} id=#{id} properties=#{properties} attributes=#{attributes} hints=#{hints}>"
    end
  end
end
