require "./failure"

module Kebab
  module Convert
    # Converter for Crystal enums. Enum-typed fields use it automatically.
    # Naming it as a `converter:` is equivalent.
    # Member names are matched with `Enum.parse?` (case-insensitive, `-`/`_` equivalent),
    # so `MyEnum::ApprovalRequested` accepts `"approval_requested"`:
    # https://crystal-lang.org/api/Enum.html#parse%28string%3AString%29%3Aself-class-method
    module Enum(T)
      def self.convert(input : String) : T | ::Kebab::Convert::Failure
        {% raise "Kebab::Convert::Enum(T) requires an enum type, got #{T}." unless T < ::Enum %}
        T.parse?(input) || ::Kebab::Convert.failure(
          "one of: #{to_sentence(T.names.map(&.underscore).sort!)}",
          name: T.name.split("::").last.underscore.tr("_", " "),
        )
      end

      private def self.to_sentence(values : Array(String)) : String
        *rest, last = values
        return last if rest.empty?

        "#{rest.join(", ")} or #{last}"
      end
    end
  end
end
