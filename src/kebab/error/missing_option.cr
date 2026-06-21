require "../renderer"
require "../schema/command"
require "../schema/option"
require "./base"

module Kebab
  module Error
    # A required option wasn't provided.
    abstract struct MissingOption < Error::Base
      def initialize(@option : Schema::Option, @schema : Schema::Command)
        super("option \"--#{@option.long}\" is required.")
      end

      # The option that was missing.
      getter option : Schema::Option

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
      struct For(C) < MissingOption
        def command : C.class
          C
        end
      end
    end
  end
end
