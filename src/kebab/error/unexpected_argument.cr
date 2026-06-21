require "../renderer"
require "../schema/command"
require "./base"

module Kebab
  module Error
    # The user passed more positionals than the command declared.
    abstract struct UnexpectedArgument < Error::Base
      def initialize(@value : String, @schema : Schema::Command)
        super("\"#{@value}\" wasn't expected here.")
      end

      # The first unexpected positional value.
      getter value : String

      # The command being parsed when the error fired.
      getter schema : Schema::Command

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @schema.usage)
        unless @schema.arguments.empty?
          io << "\n\n"
          Renderer.section(io, "Arguments:", @schema.arguments)
        end
      end

      # Concrete subclass parameterised by the command `C`.
      struct For(C) < UnexpectedArgument
        def command : C.class
          C
        end
      end
    end
  end
end
