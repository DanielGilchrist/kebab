require "./usage/arguments"
require "./usage/subcommand"

module Kebab
  module Schema
    module Usage
      alias Any = Arguments | Subcommand
    end
  end
end
