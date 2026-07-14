module Kebab
  module Schema
    # An option flag declared on a command.
    struct Option
      def initialize(*, @long : String, @short : Char?, @description : String, @value_names : Array(String), @min_values : Int32, @max_values : Int32?, @value_choices : Array(String) = [] of String)
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

      # The accepted values for an enum-typed option, in help order. Empty when
      # the values aren't a fixed set kebab knows (any non-enum, or a custom converter).
      getter value_choices : Array(String)

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
