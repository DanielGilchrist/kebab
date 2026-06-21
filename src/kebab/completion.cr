require "./schema/command"
require "./completion/fish"
require "./completion/bash"
require "./completion/zsh"

module Kebab
  # Generates shell completion scripts from a command's `Schema::Command`.
  # `Shell` covers the shells kebab ships. `Type.schema` is public, so any
  # other shell can be generated from it directly.
  module Completion
    extend self

    # The shells kebab ships generators for.
    enum Shell
      Fish
      Bash
      Zsh

      def generate(command : ::Kebab::Schema::Command, binary : String? = nil) : String
        case self
        in Fish then Completion::Fish.generate(command, binary)
        in Bash then Completion::Bash.generate(command, binary)
        in Zsh  then Completion::Zsh.generate(command, binary)
        end
      end
    end

    # :nodoc:
    # Subcommand names and option flags offered at a node (bash, zsh).
    def candidate_words(node : ::Kebab::Schema::Command) : Array(String)
      words = node.subcommands.map(&.name)
      node.options.each do |option|
        words << "--#{option.long}"
        if short = option.short
          words << "-#{short}"
        end
      end
      words
    end
  end
end
