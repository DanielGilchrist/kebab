require "../renderer"
require "../schema/option"
require "../schema/usage"
require "./base"

module Kebab
  module Error
    # An option needed a value but didn't get one (e.g. `--at` at the end
    # of the arg list, or `--at --verbose`).
    abstract struct MissingValue < Error::Base
      def initialize(@option : Schema::Option, @options : Array(Schema::Option), @usage : Schema::Usage::Any)
        super("option \"--#{@option.long}\" expects a value.")
      end

      # The option that needed a value.
      getter option : Schema::Option

      # All options the command accepts.
      getter options : Array(Schema::Option)

      # The Usage line for the command.
      getter usage : Schema::Usage::Any

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @usage)
        io << "\n\n"
        Renderer.section(io, "Options:", @options)
      end

      # Concrete subclass parameterised by the command `C`.
      struct For(C) < MissingValue
        def command : C.class
          C
        end
      end
    end
  end
end
