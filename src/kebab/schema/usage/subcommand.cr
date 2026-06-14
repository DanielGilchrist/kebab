module Kebab
  module Schema
    module Usage
      struct Subcommand
        def initialize(@command_path : Array(String), @has_options : Bool)
        end

        getter command_path : Array(String)
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
