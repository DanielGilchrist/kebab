require "../renderer"
require "../schema/argument"
require "../schema/usage/arguments"
require "./base"

module Kebab
  module Error
    # A required positional argument wasn't provided.
    abstract struct MissingArgument < Error::Base
      def initialize(@argument : Schema::Argument, @arguments : Array(Schema::Argument), @usage : Schema::Usage::Arguments)
        super("argument \"<#{@argument.name}>\" is required.")
      end

      # The argument that was missing.
      getter argument : Schema::Argument

      # All arguments the command accepts.
      getter arguments : Array(Schema::Argument)

      # The Usage line for the command.
      getter usage : Schema::Usage::Arguments

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @usage)
        io << "\n\n"
        Renderer.section(io, "Arguments:", @arguments)
      end

      # Concrete subclass parameterised by the command `C`.
      struct For(C) < MissingArgument
        def command : C.class
          C
        end
      end
    end
  end
end
