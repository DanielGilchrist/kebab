module Kebab
  module Schema
    module Usage
      # Usage line shape for a command that dispatches to a subcommand.
      struct Subcommand
        def initialize(@command_path : Array(String), @has_options : Bool)
        end

        # Path of command names from the binary down to this command
        # (e.g. `["tanda_cli", "clockin"]`).
        getter command_path : Array(String)

        # `true` if the command declares any options.
        getter? has_options : Bool

        def to_s(io : IO) : Nil
          @command_path.join(io, ' ')
          io << " [options]" if @has_options
          io << " <command>"
        end
      end
    end
  end
end
