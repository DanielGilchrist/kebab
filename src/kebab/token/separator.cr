module Kebab
  # :nodoc:
  module Token
    record Separator do
      def to_s(io : IO) : Nil
        io << "--"
      end
    end
  end
end
