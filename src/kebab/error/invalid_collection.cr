require "../convert/failure"
require "../schema/argument"
require "../schema/command"
require "../schema/option"
require "./base"

module Kebab
  module Error
    # A converter's `collect` rejected the collected values as a whole.
    # Dispatchable on target type via `Of(T)`, on command via `For(C)`, or on
    # both via `Exact(T, C)`.
    abstract struct InvalidCollection < Error::Base
      # Marker module included on the concrete error when the command is `C`.
      module For(C); end

      # Marker module included on the concrete error when the target type is `T`.
      module Of(T); end

      def initialize(@values : Array(String), @source : Schema::Option | Schema::Argument, @schema : Schema::Command, @target_name : String? = nil, @reason : String? = nil)
        super(build_message)
      end

      # The raw inputs of every occurrence, in the order they were given.
      getter values : Array(String)

      # The option or argument the values were being parsed for.
      getter source : Schema::Option | Schema::Argument

      # The command being parsed when the error fired.
      getter schema : Schema::Command

      # Human-readable noun for the target type, supplied by the converter
      # (e.g. `"tags"`). Nil falls back to "value"/"values".
      getter target_name : String?

      # Optional explanation provided by the converter (rendered in parens).
      getter reason : String?

      # The target type's class.
      abstract def target_type

      # The target type's class name.
      abstract def target_type_name : String

      private def build_message : String
        message =
          if @values.size == 1
            %("#{@values.first}" isn't a valid #{noun} for #{source_label})
          else
            rendered = @values.join(", ") { |value| %("#{value}") }
            "#{rendered} aren't valid #{noun} for #{source_label}"
          end
        message += " (#{@reason})" if @reason
        message
      end

      private def source_label : String
        case source = @source
        in Schema::Option   then %("--#{source.long}")
        in Schema::Argument then %("<#{source.name}>")
        end
      end

      private def noun : String
        @target_name || (@values.size == 1 ? "value" : "values")
      end

      # Concrete subclass parameterised by the target type `T` and the command `C`.
      struct Exact(T, C) < InvalidCollection
        include InvalidCollection::For(C)
        include InvalidCollection::Of(T)

        def self.from(failure : ::Kebab::Convert::Failure, *, values : Array(String), source : Schema::Option | Schema::Argument, schema : ::Kebab::Schema::Command) : self
          new(
            values: values,
            source: source,
            schema: schema,
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
