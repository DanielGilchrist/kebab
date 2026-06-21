module Kebab
  module Internal
    # :nodoc:
    module Tokens
      record Long, name : String, value : String? = nil do
        def to_s(io : IO) : Nil
          io << "--" << name
        end
      end
    end
  end
end
