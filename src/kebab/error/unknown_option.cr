require "../renderer"
require "../schema/option"
require "../schema/usage"
require "./base"

module Kebab
  module Error
    class UnknownOption < Error::Base
      def initialize(@option : String, @options : Array(Schema::Option), @usage : Schema::Usage::Any)
        super("\"#{@option}\" isn't a recognised option.")
      end

      getter option : String
      getter options : Array(Schema::Option)
      getter usage : Schema::Usage::Any

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @usage)
        io << "\n\n"
        Renderer.section(io, "Options:", @options)
      end
    end
  end
end
