require "./failure"

module Kebab
  module Convert
    module Enum(T)
      def self.parse(input : String) : T | ::Kebab::Convert::Failure
        T.parse?(input) || ::Kebab::Convert.failure("one of: #{T.names.map(&.downcase).join(", ")}")
      end
    end
  end
end
