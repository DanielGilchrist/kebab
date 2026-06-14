require "../renderer"
require "../schema/argument"
require "../schema/usage/arguments"
require "./base"

module Kebab
  module Error
    class UnexpectedArgument < Error::Base
      def initialize(@value : String, @arguments : Array(Schema::Argument), @usage : Schema::Usage::Arguments)
        super("\"#{@value}\" wasn't expected here.")
      end

      getter value : String
      getter arguments : Array(Schema::Argument)
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
    end
  end
end
