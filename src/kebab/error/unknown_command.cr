require "../renderer"
require "../schema/command"
require "../schema/usage/subcommand"
require "./base"

module Kebab
  module Error
    # The user typed a subcommand kebab doesn't know about.
    abstract struct UnknownCommand < Error::Base
      def initialize(@input : String, @commands : Array(Schema::Command), @usage : Schema::Usage::Subcommand)
        super("\"#{@input}\" isn't a known command.")
      end

      # The token the user typed.
      getter input : String

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
      struct For(C) < UnknownCommand
        def command : C.class
          C
        end
      end
    end
  end
end
