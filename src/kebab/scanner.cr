require "./token"

module Kebab
  # :nodoc:
  module Scanner
    extend self

    def scan(arg : String) : Token::Any
      return Token::Positional.new(arg) if arg == "-" || arg.empty?
      return Token::Separator.new if arg == "--"

      if arg.starts_with?("--")
        body_start = 2
        if eq_index = arg.byte_index('=', body_start)
          Token::Long.new(arg[body_start...eq_index], arg.byte_slice(eq_index + 1))
        else
          Token::Long.new(arg.byte_slice(body_start), nil)
        end
      elsif arg.starts_with?('-')
        body_start = 1
        if eq_index = arg.byte_index('=', body_start)
          Token::Shorts.new(arg[body_start...eq_index], arg.byte_slice(eq_index + 1))
        else
          Token::Shorts.new(arg.byte_slice(body_start), nil)
        end
      else
        Token::Positional.new(arg)
      end
    end
  end
end
