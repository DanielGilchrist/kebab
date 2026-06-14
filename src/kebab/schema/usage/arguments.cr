module Kebab
  module Schema
    module Usage
      # Usage line shape for a command with positional arguments (no subcommand).
      struct Arguments
        def initialize(@command_path : Array(String), @has_options : Bool, @argument_names : Array(String), @has_variadic_tail : Bool = false)
        end

        # Path of command names from the binary down to this command.
        getter command_path : Array(String)

        # `true` if the command declares any options.
        getter? has_options : Bool

        # Argument names in declaration order (used as `<name>` in the usage line).
        getter argument_names : Array(String)

        # `true` if the last argument is variadic (`Array(T)`).
        getter? has_variadic_tail : Bool

        def to_s(io : IO) : Nil
          @command_path.join(io, ' ')
          io << " [options]" if @has_options
          last_index = @argument_names.size - 1
          @argument_names.each_with_index do |name, index|
            io << " <" << name << ">"
            io << "..." if @has_variadic_tail && index == last_index
          end
        end
      end
    end
  end
end
