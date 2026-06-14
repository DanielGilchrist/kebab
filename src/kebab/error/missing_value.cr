require "../schema/option"
require "./base"

module Kebab
  module Error
    # An option needed a value but didn't get one (e.g. `--at` at the end
    # of the arg list, or `--at --verbose`).
    abstract struct MissingValue < Error::Base
      def initialize(@option : Schema::Option)
        super("option \"--#{@option.long}\" expects a value.")
      end

      # The option that needed a value.
      getter option : Schema::Option

      # Concrete subclass parameterised by the command `C`.
      struct For(C) < MissingValue
        def command : C.class
          C
        end
      end
    end
  end
end
