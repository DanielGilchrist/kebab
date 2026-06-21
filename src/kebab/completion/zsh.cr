require "../schema/command"

module Kebab
  module Completion
    # Generates a zsh completion script. Same path-key dispatch as bash, adding
    # candidates with `compadd`. The trailer registers the function whether the
    # file is autoloaded from `$fpath` or sourced directly.
    module Zsh
      extend self

      def generate(command : ::Kebab::Schema::Command, binary : String? = nil) : String
        name = binary || command.name
        ::String.build do |io|
          io << "#compdef " << name << '\n'
          io << '_' << name << "() {\n"
          io << "  local cmd i\n"
          io << "  cmd=\"" << name << "\"\n"
          io << "  for ((i = 2; i < CURRENT; i++)); do\n"
          io << "    case \"${words[i]}\" in\n"
          io << "      -*) ;;\n"
          io << "      *) cmd=\"${cmd}__${words[i]}\" ;;\n"
          io << "    esac\n"
          io << "  done\n"
          io << "  case \"$cmd\" in\n"
          arms(io, command, [name])
          io << "  esac\n"
          io << "}\n"
          io << "if [ \"$funcstack[1]\" = \"_" << name << "\" ]; then\n"
          io << "  _" << name << " \"$@\"\n"
          io << "else\n"
          io << "  compdef _" << name << ' ' << name << '\n'
          io << "fi\n"
        end
      end

      private def arms(io : IO, node : ::Kebab::Schema::Command, path : Array(String)) : Nil
        io << "    " << path.join("__") << ")\n"
        io << "      compadd -- " << Completion.candidate_words(node).join(' ') << "\n"
        io << "      ;;\n"
        node.subcommands.each { |subcommand| arms(io, subcommand, path + [subcommand.name]) }
      end
    end
  end
end
