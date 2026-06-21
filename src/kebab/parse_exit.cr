module Kebab
  # :nodoc:
  class ParseExit < ::Exception
    def initialize(@result : ::Kebab::Help | ::Kebab::Errors)
      super("internal control-flow exception, should be caught by Parseable.parse")
    end

    getter result : ::Kebab::Help | ::Kebab::Errors
  end
end
