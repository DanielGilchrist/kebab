module Kebab
  # :nodoc:
  module Internal
    # :nodoc:
    class ParseExit < ::Exception
      def initialize(@result : ::Kebab::Help | ::Kebab::Errors)
        super("internal — caught by Parseable.parse")
      end

      getter result : ::Kebab::Help | ::Kebab::Errors
    end
  end
end
