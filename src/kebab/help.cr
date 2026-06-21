module Kebab
  # Returned by `parse` when the user requested help (via `--help`, `-h`,
  # or the `help` subcommand). Carries the rendered help text.
  record Help, text : String do
    def to_s(io : IO) : Nil
      io << text
    end
  end
end
