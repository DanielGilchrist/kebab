require "colorize"

module Kebab
  module Error
    # Common base for every kebab parse error. Carries a one-line message
    # and an abstract `command` which returns the class of the command being
    # parsed when the error fired.
    abstract struct Base
      def initialize(@message : String)
      end

      # One-line description of what went wrong.
      getter message : String

      # The class of the command being parsed when this error fired.
      abstract def command

      def to_s(io : IO) : Nil
        io << "Error:".colorize.red.bold << ' ' << @message
      end
    end
  end
end
