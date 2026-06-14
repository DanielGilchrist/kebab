module Kebab
  module Convert
    # Returned by a converter when it can't produce a value. Kebab wraps
    # this into an `Error::InvalidValue` and threads in the option/argument,
    # raw input, target type, and responsible command.
    struct Failure
      def initialize(@reason : String? = nil, @name : String? = nil)
      end

      # Optional explanation rendered in parentheses (e.g. `"expected one of: a, b"`).
      getter reason : String?

      # Optional human-readable noun for the target type (e.g. `"whole number"` instead of `"Int32"`).
      getter name : String?
    end
  end
end
