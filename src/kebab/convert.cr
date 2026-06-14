require "./convert/failure"

module Kebab
  module Convert
    extend self

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
      type.parse(raw)
    end
  end
end
