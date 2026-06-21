require "../renderer"
require "../schema/command"
require "./base"

module Kebab
  module Error
    # A required subcommand wasn't provided.
    abstract struct MissingCommand < Error::Base
      def initialize(@schema : Schema::Command)
        super("a command is required.")
      end

      # The parent command being parsed when the error fired.
      getter schema : Schema::Command

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @schema.usage)
        io << "\n\n"
        Renderer.section(io, "Commands:", @schema.subcommands)
      end

      # Concrete subclass parameterised by the parent command `C`.
      struct For(C) < MissingCommand
        def command : C.class
          C
        end
      end
    end
  end
end
