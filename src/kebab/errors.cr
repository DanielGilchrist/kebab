require "./error/invalid_value"
require "./error/missing_argument"
require "./error/missing_command"
require "./error/missing_option"
require "./error/missing_value"
require "./error/repeated_option"
require "./error/unexpected_argument"
require "./error/unknown_command"
require "./error/unknown_option"

module Kebab
  alias Errors = Error::InvalidValue |
                 Error::MissingArgument |
                 Error::MissingCommand |
                 Error::MissingOption |
                 Error::MissingValue |
                 Error::RepeatedOption |
                 Error::UnexpectedArgument |
                 Error::UnknownCommand |
                 Error::UnknownOption
end
