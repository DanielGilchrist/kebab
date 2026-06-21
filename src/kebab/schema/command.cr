require "./argument"
require "./option"
require "./usage"

module Kebab
  module Schema
    # The structure of one command, built from the command struct at compile
    # time. `subcommands` holds the same type for each child.
    #
    # `options` includes the synthetic `--help`, so it is what help and
    # completion list. `has_options?` counts only declared options, so it is
    # what drives `[options]` in the usage line.
    struct Command
      def initialize(
        @path : Array(String),
        @summary : String,
        @options : Array(Option) = [] of Option,
        @arguments : Array(Argument) = [] of Argument,
        @subcommands : Array(Command) = [] of Command,
        @has_options : Bool = false,
        @requires_subcommand : Bool = false,
      )
      end

      # Path of command names from the binary down to this command
      # (e.g. `["tasks", "add"]`).
      getter path : Array(String)

      # The summary shown in help.
      getter summary : String

      # Every option the command accepts, including the synthetic `--help`.
      getter options : Array(Option)

      # The command's positional arguments in declaration order.
      getter arguments : Array(Argument)

      # Child commands, recursively. Empty for a leaf command.
      getter subcommands : Array(Command)

      # `true` if the command declares any options of its own (the synthetic
      # `--help` does not count). Drives `[options]` in the usage line.
      getter? has_options : Bool

      # `true` if a subcommand must be supplied (a bare invocation errors
      # rather than printing help).
      getter? requires_subcommand : Bool

      # The command's own name, the last segment of `path`.
      def name : String
        @path.last
      end

      # The usage line for the command, derived from its shape.
      def usage : Usage::Any
        if @subcommands.empty?
          Usage::Arguments.new(
            @path,
            has_options: @has_options,
            argument_names: @arguments.map(&.name),
            has_variadic_tail: !@arguments.empty? && @arguments.last.variadic?,
          )
        else
          Usage::Subcommand.new(@path, has_options: @has_options)
        end
      end
    end
  end
end
