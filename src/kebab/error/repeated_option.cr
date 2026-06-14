require "./base"

module Kebab
  module Error
    class RepeatedOption < Error::Base
      def initialize(@option : String)
        super("option \"#{@option}\" was given more than once.")
      end

      getter option : String
    end
  end
end
