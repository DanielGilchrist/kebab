module Kebab
  module Schema
    struct Argument
      def initialize(@name : String, @description : String, @variadic : Bool = false)
      end

      getter name : String
      getter description : String
      getter? variadic : Bool
    end
  end
end
