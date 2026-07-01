require "./kebab/**"

module Kebab
  VERSION = "0.1.0"

  # Attached to a `Kebab::Parseable` struct to set the command's display
  # name and summary. Accepts `name : String` (defaults to the underscored struct name) and `summary : String`.
  annotation Command; end

  # Marks a field as an option. A `Bool` field is a flag. Any other type takes a
  # value. Accepts `long : String`, `short : Char`, `description : String`,
  # `converter : Type`, and `global : Bool` (recognised throughout the command's
  # subtree, including after subcommands).
  annotation Option; end

  # Marks a field as a positional argument. Accepts `name : String`,
  # `description : String`, and `converter : Type`.
  annotation Argument; end

  # Marks a field as the subcommand union for a parent command. Accepts
  # `required : Bool` (defaults to `false`, so a bare invocation prints help).
  annotation Subcommand; end
end
