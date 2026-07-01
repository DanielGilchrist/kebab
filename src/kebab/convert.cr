require "./convert/enum"
require "./convert/failure"

module Kebab
  # Built-in converters for the standard library types kebab knows how to
  # parse out of the box, plus the `failure` factory for writing your own.
  #
  # A converter is anything responding to `parse(input : String) :
  # T | Kebab::Convert::Failure`. Attach one to a field with
  # `@[Kebab::Option(converter: MyConverter)]` or
  # `@[Kebab::Argument(converter: MyConverter)]`.
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

    def parse(type : String.class, raw : String) : String | Failure
      raw
    end

    {% for number_type, suffix in {
                                    Int8 => "i8", Int16 => "i16", Int32 => "i32", Int64 => "i64",
                                    UInt8 => "u8", UInt16 => "u16", UInt32 => "u32", UInt64 => "u64",
                                    Float32 => "f32", Float64 => "f64",
                                  } %}
      def parse(type : {{number_type}}.class, raw : String) : {{number_type}} | Failure
        raw.to_{{suffix.id}}? || failure(name: {{number_type == Float32 || number_type == Float64 ? "decimal number" : "whole number"}})
      end
    {% end %}

    def parse(type : T.class, raw : String) : T | Failure forall T
      {% if T < ::Enum %}
        ::Kebab::Convert::Enum(T).parse(raw)
      {% else %}
        {% raise "kebab has no built-in conversion for #{T}. Give the field a `converter:` (see Kebab::Convert), or use a built-in type (String, a number, or an enum)." %}
      {% end %}
    end
  end
end
