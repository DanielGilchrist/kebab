require "../renderer"
require "../schema/command"
require "../schema/option"
require "./base"

module Kebab
  module Error
    # An option needed a value but didn't get one (e.g. `--at` at the end
    # of the arg list, or `--at --verbose`).
    abstract struct MissingValue < Error::Base
      def initialize(@option : Schema::Option, @schema : Schema::Command, @got : Int32 = 0, @invoked : String? = nil)
        super(build_message)
      end

      # The option that needed a value.
      getter option : Schema::Option

      # The command being parsed when the error fired.
      getter schema : Schema::Command

      # How many values the occurrence actually supplied.
      getter got : Int32

      private def build_message : String
        label = @invoked || "--#{@option.long}"
        min = @option.min_values
        return "option \"#{label}\" expects a value." if min == 1 && !@option.variable? && @got.zero?

        counted =
          if !@option.variable?
            "#{min} value#{"s" if min > 1}"
          elsif max = @option.max_values
            "#{min} to #{max} values"
          else
            "at least #{min} value#{"s" if min > 1}"
          end
        "option \"#{label}\" expects #{counted}, got #{@got}."
      end

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
