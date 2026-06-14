require "colorize"

module Kebab
  module Error
    abstract class Base
      def initialize(@message : String)
      end

      getter message : String

      def to_s(io : IO) : Nil
        io << "Error:".colorize.red.bold << ' ' << @message
      end
    end
  end
end
