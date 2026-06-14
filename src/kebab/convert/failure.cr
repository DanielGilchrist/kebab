module Kebab
  module Convert
    struct Failure
      def initialize(@reason : String? = nil, @name : String? = nil)
      end

      getter reason : String?
      getter name : String?
    end
  end
end
