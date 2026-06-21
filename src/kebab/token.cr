require "./token/long"
require "./token/positional"
require "./token/separator"
require "./token/shorts"

module Kebab
  # :nodoc:
  module Token
    alias Any = Long | Shorts | Positional | Separator
  end
end
