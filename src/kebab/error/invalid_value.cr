require "../convert/failure"
require "../schema/argument"
require "../schema/option"
require "./base"

module Kebab
  module Error
    # A value couldn't be converted to its target type. Dispatchable on
    # value type via `Of(T)`, on command via `For(C)`, or on both via
    # `Typed(T, C)`.
    abstract struct InvalidValue < Error::Base
      # Marker module included on the concrete error when the command is `C`.
      module For(C); end

      # Marker module included on the concrete error when the target type is `T`.
      module Of(T); end

      def initialize(@value : String, @source : Schema::Option | Schema::Argument, @target_name : String? = nil, @reason : String? = nil)
        super(build_message)
      end

      # The raw input that couldn't be converted.
      getter value : String

      # The option or argument the value was being parsed for.
      getter source : Schema::Option | Schema::Argument

      # Human-readable noun for the target type, supplied by the converter
      # (e.g. `"whole number"`). Nil falls back to the type's class name.
      getter target_name : String?

      # Optional explanation provided by the converter (rendered in parens).
      getter reason : String?

      # The target type's class.
      abstract def target_type

      # The target type's class name.
      abstract def target_type_name : String

      private def build_message : String
        message = "\"#{@value}\" isn't a valid #{noun} for #{source_label}"
        message += " (#{@reason})" if @reason
        message
      end

      private def noun : String
        @target_name || target_type_name
      end

      private def source_label : String
        case source = @source
        in Schema::Option   then %("--#{source.long}")
        in Schema::Argument then %("<#{source.name}>")
        end
      end

      # Concrete subclass parameterised by the target type `T` and the command `C`.
      struct Typed(T, C) < InvalidValue
        include InvalidValue::For(C)
        include InvalidValue::Of(T)

        def self.from(failure : ::Kebab::Convert::Failure, *, value : String, source : Schema::Option | Schema::Argument) : self
          new(
            value: value,
            source: source,
            target_name: failure.name,
            reason: failure.reason,
          )
        end

        def target_type : T.class
          T
        end

        def target_type_name : String
          T.name
        end

        def command : C.class
          C
        end
      end
    end
  end
end
