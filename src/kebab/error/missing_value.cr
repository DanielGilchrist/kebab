require "../renderer"
require "../schema/command"
require "../schema/option"
require "./base"

module Kebab
  module Error
    # An option needed a value but didn't get one (e.g. `--at` at the end
    # of the arg list, or `--at --verbose`).
    abstract struct MissingValue < Error::Base
      def initialize(@option : Schema::Option, @schema : Schema::Command)
        super("option \"--#{@option.long}\" expects a value.")
      end

      # The option that needed a value.
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
      struct For(C) < MissingValue
        def command : C.class
          C
        end
      end
    end
  end
end
