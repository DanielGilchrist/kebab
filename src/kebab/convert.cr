require "./convert/enum"
require "./convert/failure"

module Kebab
  # Built-in converters for the standard library types kebab converts out of the
  # box, plus the `failure` factory for writing your own.
  #
  # A converter is anything responding to `convert(input : String) :
  # T | Kebab::Convert::Failure`. Attach one to a field with
  # `@[Kebab::Option(converter: MyConverter)]` or
  # `@[Kebab::Argument(converter: MyConverter)]`.
  #
  # A converter that also defines `collect(values : Array(T)) : F |
  # Kebab::Convert::Failure` makes its option repeatable: every occurrence goes
  # through `convert`, then `collect` builds the field (of type `F`) from all of
  # them. On the last positional argument, `collect` folds the remaining
  # positionals the same way. `collect` is never called with an empty array. An
  # absent field uses its default instead.
  #
  # On an `Array(T)` field, `convert` may return `Array(T)` to yield several
  # elements from one value (like splitting on commas).
  module Convert
    extend self

    # Builds a `Failure` for a converter to return.
    #
    # `reason` is the parenthetical shown after the default message.
    # `name` overrides the rendered noun for the target type (e.g.
    # `"whole number"` instead of `"Int32"`). Both are optional.
    def failure(reason : String? = nil, *, name : String? = nil) : Failure
      Failure.new(reason: reason, name: name)
    end

    def convert(type : String.class, raw : String) : String | Failure
      raw
    end

    # :nodoc:
    # The single source for the convertible-number set. schema_check reads the keys.
    NUMBER_SUFFIXES = {
      Int8 => "i8", Int16 => "i16", Int32 => "i32", Int64 => "i64", Int128 => "i128",
      UInt8 => "u8", UInt16 => "u16", UInt32 => "u32", UInt64 => "u64", UInt128 => "u128",
      Float32 => "f32", Float64 => "f64",
    }

    {% for number_type, suffix in NUMBER_SUFFIXES %}
      def convert(type : {{number_type}}.class, raw : String) : {{number_type}} | Failure
        raw.to_{{suffix.id}}? || failure(name: {{number_type == Float32 || number_type == Float64 ? "decimal number" : "whole number"}})
      end
    {% end %}

    def convert(type : T.class, raw : String) : T | Failure forall T
      {% if T < ::Enum %}
        ::Kebab::Convert::Enum(T).convert(raw)
      {% else %}
        {% raise "kebab has no built-in conversion for #{T}. Add a `converter:` (see Kebab::Convert), or use a built-in type (String, a number, or an enum)." %}
      {% end %}
    end
  end
end
