module Kebab
  module Schema
    # A positional argument declared on a command.
    struct Argument
      def initialize(@name : String, @description : String, @variadic : Bool = false, @value_count : Int32 = 1)
      end

      # The argument name (used as the placeholder in `<name>` in usage output).
      getter name : String

      # The description used in help output.
      getter description : String

      # `true` if the argument is variadic (declared as `Array(T)`).
      getter? variadic : Bool

      # How many positionals the argument consumes per unit: 1, or the tuple
      # size for `Tuple` arguments. A variadic consumes the remainder in groups
      # of this size.
      getter value_count : Int32
    end
  end
end
