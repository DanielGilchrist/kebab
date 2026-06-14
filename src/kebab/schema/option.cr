module Kebab
  module Schema
    # An option flag declared on a command.
    struct Option
      def initialize(@long : String, @short : Char?, @description : String, @takes_value : Bool)
      end

      # The long flag name without the leading `--`.
      getter long : String

      # The short flag character (if any).
      getter short : Char?

      # The description used in help output.
      getter description : String

      # `true` if the option expects a value, `false` for boolean flags.
      getter? takes_value : Bool
    end
  end
end
