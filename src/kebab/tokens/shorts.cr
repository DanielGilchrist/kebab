module Kebab
  module Tokens
    record Shorts, chars : String, value : String? = nil do
      def to_s(io : IO) : Nil
        io << '-' << chars
      end
    end
  end
end
