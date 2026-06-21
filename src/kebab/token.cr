require "./token/long"
require "./token/positional"
require "./token/separator"
require "./token/shorts"

module Kebab
  # :nodoc:
  module Token
    alias Any = Long | Shorts | Positional | Separator

    # Classifies a single raw argument into its token type.
    def self.classify(arg : String) : Any
      return Positional.new(arg) if arg == "-" || arg.empty?
      return Separator.new if arg == "--"

      if arg.starts_with?("--")
        body_start = 2
        if eq_index = arg.byte_index('=', body_start)
          Long.new(arg[body_start...eq_index], arg.byte_slice(eq_index + 1))
        else
          Long.new(arg.byte_slice(body_start), nil)
        end
      elsif arg.starts_with?('-')
        body_start = 1
        if eq_index = arg.byte_index('=', body_start)
          Shorts.new(arg[body_start...eq_index], arg.byte_slice(eq_index + 1))
        else
          Shorts.new(arg.byte_slice(body_start), nil)
        end
      else
        Positional.new(arg)
      end
    end
  end
end
