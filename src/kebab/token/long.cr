module Kebab
  # :nodoc:
  module Token
    record Long, name : String, value : String? = nil do
      def to_s(io : IO) : Nil
        io << "--" << name
      end
    end
  end
end
