require "./base"

module Kebab
  module Error
    class MissingValue < Error::Base
      def initialize(@option : String)
        super("option \"#{@option}\" expects a value.")
      end

      getter option : String
    end
  end
end
