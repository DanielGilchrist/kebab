require "../renderer"
require "../schema/command"
require "./base"

module Kebab
  module Error
    # The user typed an option flag that doesn't match any declared option.
    abstract struct UnknownOption < Error::Base
      def initialize(@input : String, @schema : Schema::Command)
        super("\"#{@input}\" isn't a recognised option.")
      end

      # The token the user typed (e.g. `"--bogus"` or `"-z"`).
      getter input : String

      # The command being parsed when the error fired.
      getter schema : Schema::Command

      def to_s(io : IO) : Nil
        super(io)
        io << "\n\n"
        Renderer.usage(io, @schema.usage)
        io << "\n\n"
        Renderer.section(io, "Options:", @schema.options)
      end

      # Concrete subclass parameterised by the command `C`.
      struct For(C) < UnknownOption
        def command : C.class
          C
        end
      end
    end
  end
end
