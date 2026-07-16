require "./kebab/**"

module Kebab
  VERSION = "0.1.0"

  # Configures a `Kebab::Parseable` struct as a command.
  #
  # ```
  # @[Kebab::Command(name: "clock-in", summary: "Start the timer")]
  # struct ClockIn
  #   include Kebab::Parseable
  # end
  # ```
  #
  # Available fields:
  # * **name** (`String`): the command's name in usage and help. Defaults to the struct's name in snake_case.
  # * **summary** (`String`): the one-line description shown in help and in a parent's command list.
  annotation Command; end

  # Marks a field as an option, parsed from a `--long` or `-s` flag.
  #
  # A `Bool` field is a flag that takes no value. Any other type takes one value
  # per occurrence, converted to the field's type. `String`, the integer and
  # float types, and enums are built in. Other types need a `converter`.
  #
  # ```
  # @[Kebab::Option(short: 'a', description: "Clock in at a past time")]
  # getter at : String?
  #
  # @[Kebab::Option(short: 'v', count: true, description: "Increase verbosity")]
  # getter verbosity : Int32 = 0
  # ```
  #
  # Available fields:
  # * **long** (`String`): the `--name`. Defaults to the field name with underscores as dashes.
  # * **short** (`Char`): a single-letter `-x` alias.
  # * **description** (`String`): the help text for the option.
  # * **converter** (`Type`): a type or module with `self.convert(input : String) : T | Kebab::Convert::Failure`, for types kebab does not convert on its own. See `Kebab::Convert`.
  # * **global** (`Bool`): if `true`, the option is recognised anywhere in the command's subtree, including after subcommands (by default `false`).
  # * **arity** (`Int | Range`): how many values one occurrence consumes, on an `Array(T)` field. `2` takes a fixed pair, `1..` takes one or more (by default one, or the size of a `Tuple`).
  # * **value_names** (`Tuple(String, ...)`): the `<name>` placeholders shown for the values in help.
  # * **count** (`Bool`): if `true`, an integer field counts its occurrences like `-vvv`, saturating at the type's maximum (by default `false`).
  annotation Option; end

  # Marks a field as a positional argument, filled by position rather than a flag.
  #
  # As with `Kebab::Option`, the field's type sets how the value converts. An
  # `Array(T)` field as the last argument consumes the remaining positionals.
  #
  # ```
  # @[Kebab::Argument(description: "File to trim")]
  # getter path : String
  # ```
  #
  # Available fields:
  # * **name** (`String`): the `<name>` placeholder in usage and help. Defaults to the field name with underscores as dashes.
  # * **description** (`String`): the help text for the argument.
  # * **converter** (`Type`): a converter for types kebab does not convert on its own, as with `Kebab::Option`. See `Kebab::Convert`.
  annotation Argument; end

  # Marks a field as the subcommand of a parent command. Its type is a union of
  # the child command structs, and the parser dispatches to the one named on the
  # command line.
  #
  # ```
  # @[Kebab::Subcommand]
  # getter command : Start | Finish
  # ```
  #
  # Available fields:
  # * **required** (`Bool`): if `true`, a bare invocation with no subcommand is an error. By default it prints help instead.
  annotation Subcommand; end
end
