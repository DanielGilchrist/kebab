require "../renderer"
require "../schema/command"
require "./base"

module Kebab
  module Error
    # The user typed a subcommand kebab doesn't know about.
    abstract struct UnknownCommand < Error::Base
      def initialize(@input : String, @schema : Schema::Command)
        super("\"#{@input}\" isn't a known command.")
      end

      # The token the user typed.
      getter input : String

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
      struct For(C) < UnknownCommand
        def command : C.class
          C
        end
      end
    end
  end
end
