require "./failure"

module Kebab
  module Convert
    # Generic converter for Crystal enums. Use as
    # `@[Kebab::Option(converter: Kebab::Convert::Enum(MyEnum))]`.
    # Accepts values by their downcased member name (e.g. `"json"` for
    # `MyEnum::Json`).
    module Enum(T)
      def self.parse(input : String) : T | ::Kebab::Convert::Failure
        T.parse?(input) || ::Kebab::Convert.failure(
          "one of: #{T.names.map(&.downcase).join(", ")}",
          name: T.name.split("::").last.underscore.tr("_", " "),
        )
      end
    end
  end
end
