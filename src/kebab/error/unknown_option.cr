require "../renderer"
require "../schema/option"
require "../schema/usage"
require "./base"

module Kebab
  module Error
    # The user typed an option flag that doesn't match any declared option.
    abstract struct UnknownOption < Error::Base
      def initialize(@input : String, @options : Array(Schema::Option), @usage : Schema::Usage::Any)
        super("\"#{@input}\" isn't a recognised option.")
      end

      # The token the user typed (e.g. `"--bogus"` or `"-z"`).
      getter input : String

      # The options the command accepts.
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
      struct For(C) < UnknownOption
        def command : C.class
          C
        end
      end
    end
  end
end
