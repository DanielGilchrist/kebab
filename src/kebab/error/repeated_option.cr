require "../schema/option"
require "./base"

module Kebab
  module Error
    # The same option was supplied more than once.
    abstract struct RepeatedOption < Error::Base
      def initialize(@option : Schema::Option)
        super("option \"--#{@option.long}\" was given more than once.")
      end

      # The option that was repeated.
      getter option : Schema::Option

      # Concrete subclass parameterised by the command `C`.
      struct For(C) < RepeatedOption
        def command : C.class
          C
        end
      end
    end
  end
end
