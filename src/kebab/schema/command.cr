module Kebab
  module Schema
    # A subcommand entry: `name` (used at the CLI) and `summary` (shown in help).
    record Command, name : String, summary : String
  end
end
