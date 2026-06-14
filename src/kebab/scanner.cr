require "./token"

module Kebab
  module Scanner
    extend self

    def scan(arg : String) : Token
      return Tokens::Positional.new(arg) if arg == "-" || arg.empty?
      return Tokens::Separator.new if arg == "--"

      if arg.starts_with?("--")
        body_start = 2
        if eq_index = arg.byte_index('=', body_start)
          Tokens::Long.new(arg[body_start...eq_index], arg.byte_slice(eq_index + 1))
        else
          Tokens::Long.new(arg.byte_slice(body_start), nil)
        end
      elsif arg.starts_with?('-')
        body_start = 1
        if eq_index = arg.byte_index('=', body_start)
          Tokens::Shorts.new(arg[body_start...eq_index], arg.byte_slice(eq_index + 1))
        else
          Tokens::Shorts.new(arg.byte_slice(body_start), nil)
        end
      else
        Tokens::Positional.new(arg)
      end
    end
  end
end
