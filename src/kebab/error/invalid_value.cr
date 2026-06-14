require "../convert/failure"
require "./base"

module Kebab
  module Error
    abstract class InvalidValue < Error::Base
      def initialize(@value : String, @option : String, @target_name : String? = nil, @reason : String? = nil)
        super(build_message)
      end

      getter value : String
      getter option : String
      getter target_name : String?
      getter reason : String?

      abstract def target_type : Class
      abstract def target_type_name : String

      private def build_message : String
        message = "\"#{@value}\" isn't a valid #{noun} for \"#{@option}\""
        message += " (#{@reason})" if @reason
        message
      end

      private def noun : String
        @target_name || target_type_name
      end
    end

    class InvalidValueOf(T) < InvalidValue
      def self.from(failure : ::Kebab::Convert::Failure, *, value : String, option : String) : self
        new(value: value, option: option, target_name: failure.name, reason: failure.reason)
      end

      def target_type : T.class
        T
      end

      def target_type_name : String
        T.name
      end
    end
  end
end
