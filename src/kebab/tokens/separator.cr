module Kebab
  module Internal
    # :nodoc:
    module Tokens
      record Separator do
        def to_s(io : IO) : Nil
          io << "--"
        end
      end
    end
  end
end
