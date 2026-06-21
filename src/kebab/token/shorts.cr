module Kebab
  # :nodoc:
  module Token
    record Shorts, chars : String, value : String? = nil do
      def to_s(io : IO) : Nil
        io << '-' << chars
      end
    end
  end
end
