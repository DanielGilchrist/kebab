module Kebab
  module Internal
    # :nodoc:
    module Tokens
      record Positional, value : String do
        def to_s(io : IO) : Nil
          io << value
        end
      end
    end
  end
end
