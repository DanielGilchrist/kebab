require "../renderer"
require "../schema/argument"
require "../schema/usage/arguments"
require "./base"

module Kebab
  module Error
    # The user passed more positionals than the command declared.
    abstract struct UnexpectedArgument < Error::Base
      def initialize(@value : String, @arguments : Array(Schema::Argument), @usage : Schema::Usage::Arguments)
        super("\"#{@value}\" wasn't expected here.")
      end

      # The first unexpected positional value.
      getter value : String

      # The arguments the command accepts.
      getter arguments : Array(Schema::Argument)

      # The Usage line for the command.
      getter usage : Schema::Usage::Arguments

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @usage)
        unless @arguments.empty?
          io << "\n\n"
          Renderer.section(io, "Arguments:", @arguments)
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
