require "../renderer"
require "../schema/argument"
require "../schema/command"
require "./base"

module Kebab
  module Error
    # A required positional argument wasn't provided.
    abstract struct MissingArgument < Error::Base
      def initialize(@argument : Schema::Argument, @schema : Schema::Command)
        super("argument \"<#{@argument.name}>\" is required.")
      end

      # The argument that was missing.
      getter argument : Schema::Argument

      # The command being parsed when the error fired.
      getter schema : Schema::Command

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @schema.usage)
        io << "\n\n"
        Renderer.section(io, "Arguments:", @schema.arguments)
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
