require "../renderer"
require "../schema/command"
require "../schema/usage/subcommand"
require "./base"

module Kebab
  module Error
    # A required subcommand wasn't provided.
    abstract struct MissingCommand < Error::Base
      def initialize(@commands : Array(Schema::Command), @usage : Schema::Usage::Subcommand)
        super("a command is required.")
      end

      # The subcommands the parent accepts.
      getter commands : Array(Schema::Command)

      # The Usage line for the parent command.
      getter usage : Schema::Usage::Subcommand

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @usage)
        io << "\n\n"
        Renderer.section(io, "Commands:", @commands)
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
