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

    # :nodoc:
    # Every flag in the tree that takes values, mapped to how many the
    # generated scripts must skip when rebuilding the command path from the
    # typed words. Nil means variable arity: skip until the next flag.
    def valued_flags(node : ::Kebab::Schema::Command) : Hash(String, Int32?)
      flags = {} of String => Int32?
      collect_valued_flags(node, flags)
      flags
    end

    private def collect_valued_flags(node : ::Kebab::Schema::Command, flags : Hash(String, Int32?)) : Nil
      node.options.each do |option|
        next unless option.takes_value?

        count = option.variable? ? nil : option.min_values
        ["--#{option.long}", option.short.try { |short| "-#{short}" }].compact.each do |flag|
          existing = flags[flag]?
          # The same name can take different counts on different commands.
          # Prefer variable, then the larger count. Over-skipping only costs
          # suggestions, under-skipping pollutes the path.
          if !flags.has_key?(flag)
            flags[flag] = count
          elsif existing && (count.nil? || count > existing)
            flags[flag] = count
          end
        end
      end
      node.subcommands.each { |subcommand| collect_valued_flags(subcommand, flags) }
    end
  end
end
