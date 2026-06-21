module Kebab
  module Schema
    # A positional argument declared on a command.
    struct Argument
      def initialize(@name : String, @description : String, @variadic : Bool = false)
      end

      # The argument name (used as the placeholder in `<name>` in usage output).
      getter name : String

      # The description used in help output.
      getter description : String

      # `true` if the argument is variadic (declared as `Array(T)`).
      getter? variadic : Bool
    end
  end
end
