module Kebab
  module Schema
    # An option flag declared on a command.
    struct Option
      def initialize(*, @long : String, @short : Char?, @description : String, @value_names : Array(String), @min_values : Int32, @max_values : Int32?)
      end

      # The long flag name without the leading `--`.
      getter long : String

      # The short flag character (if any).
      getter short : Char?

      # The description used in help output.
      getter description : String

      # Placeholder names for the option's values, rendered as `<name>` in help.
      # Empty for flags.
      getter value_names : Array(String)

      # The fewest values the option accepts per occurrence. `0` for flags.
      getter min_values : Int32

      # The most values the option accepts per occurrence. Nil means unbounded.
      getter max_values : Int32?

      # `true` if the option expects at least one value, `false` for flags.
      def takes_value? : Bool
        min_values > 0
      end

      # `true` if the number of values can vary per occurrence.
      def variable? : Bool
        max_values != min_values
      end
    end
  end
end
