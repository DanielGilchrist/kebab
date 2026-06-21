require "./tokens/long"
require "./tokens/positional"
require "./tokens/separator"
require "./tokens/shorts"

module Kebab
  module Internal
    # :nodoc:
    alias Token = Tokens::Long | Tokens::Shorts | Tokens::Positional | Tokens::Separator
  end
end
