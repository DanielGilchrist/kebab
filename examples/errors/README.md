# Error handling

Every parse failure is a value in the `Kebab::Errors` union. Errors are dispatchable by type and command. Commands can also intercept their own errors with `self.on_parse_error`.

## Run it

```sh
crystal run main.cr -- "select *"
crystal run main.cr -- "select *" -f yaml

# Below 3 result in a parsing error
crystal run main.cr -- "select *" -f xml
crystal run main.cr -- "select *" -l potato
crystal run main.cr -- --bogus
```

## How it works

### Typed dispatch on conversion errors

`Kebab::Error::InvalidValue` is dispatchable on:

- value type: `InvalidValue::Of(T)`
- command: `InvalidValue::For(C)`
- both: `InvalidValue::Typed(T, C)`

The handler in `main.cr` uses `Of(OutputFormat)` and `Of(Int32)` to give targeted error messages per target type.

### In-command handler

`def self.on_parse_error(error, stderr)` runs when `Type.run` hits an error attributed to the command. Return `true` to suppress kebab's default rendering. Return `false` to fall through to it.

### Other error types

The handler in `main.cr` only intercepts conversion failures. All the other variants (unknown option, missing argument, etc.) hit the `else false` and kebab renders the default. See the `crystal docs` output for the full list.
