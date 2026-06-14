module Kebab
  module Schema
    module Usage
      struct Arguments
        def initialize(@command_path : Array(String), @has_options : Bool, @argument_names : Array(String), @has_variadic_tail : Bool = false)
        end

        getter command_path : Array(String)
        getter? has_options : Bool
        getter argument_names : Array(String)
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
