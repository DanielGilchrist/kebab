module Kebab
  module Schema
    struct Option
      def initialize(@long : String, @short : Char?, @description : String, @takes_value : Bool)
      end

      getter long : String
      getter short : Char?
      getter description : String
      getter? takes_value : Bool
    end
  end
end
