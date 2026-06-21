# Custom error rendering

`on_parse_error` gives a command full control over how its parse errors look. This example reads the error's accessors and prints a "did you mean" hint built with the stdlib `Levenshtein` module.

## Run it

```sh
crystal run main.cr -- deploy api -e prod --force

# Suggest the nearest command or option for a typo
crystal run main.cr -- delpoy api
crystal run main.cr -- deploy api --forse

# Too far from anything: no hint
crystal run main.cr -- xyz
crystal run main.cr -- deploy api --bogus

# Not a suggestion case, so kebab renders its default
crystal run main.cr -- deploy
```

## How it works

### Errors route to the command that produced them

`UnknownCommand` fires while the parent parses the subcommand name, so its handler lives on the parent (`Fleet`). `UnknownOption` fires while the child parses its own flags, so that handler lives on the child (`Deploy`). `Type.run` sends each error to the `on_parse_error` of the command named by `error.command`.

### Building the message

Each error carries `input` (the token the user typed) and `schema` (the command being parsed). The handlers pull the candidates from the schema:

- `UnknownCommand` → `error.schema.subcommands` (the valid subcommands).
- `UnknownOption` → `error.schema.options` (the declared options).

Those candidates feed `Levenshtein.find`, which returns the nearest match within its tolerance or `nil`. A `nil` means nothing was close, so no hint is shown.

### Falling through

Returning `false` from `on_parse_error` leaves kebab to render its default. Both handlers only claim the errors they improve on, so a missing argument or invalid value still gets the built-in output.
