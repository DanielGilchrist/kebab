module Kebab
  module Tokens
    record Separator do
      def to_s(io : IO) : Nil
        io << "--"
      end
    end
  end
end
