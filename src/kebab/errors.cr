require "./error/invalid_collection"
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
  # The union of the failures `parse` returns when the input is invalid. Every
  # variant is a `Kebab::Error::Base`, so it renders itself with `to_s` and
  # reports which command was being parsed. Match on a specific variant to react
  # to a particular failure.
  alias Errors = Error::InvalidCollection |
                 Error::InvalidValue |
                 Error::MissingArgument |
                 Error::MissingCommand |
                 Error::MissingOption |
                 Error::MissingValue |
                 Error::RepeatedOption |
                 Error::UnexpectedArgument |
                 Error::UnknownCommand |
                 Error::UnknownOption
end
