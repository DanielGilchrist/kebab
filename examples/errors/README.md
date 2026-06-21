# Error handling

Every parse failure is a value in the `Kebab::Errors` union. In parsing mode you handle it in the `in Kebab::Errors` arm, dispatching on the type of failure.

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
- both: `InvalidValue::Exact(T, C)`

`main.cr` matches `Of(OutputFormat)` and `Of(Int32)` to give a targeted message per target type. The `when` arms cover the failures worth a custom message. Everything else falls to `else`, which prints kebab's default rendering of the error.

### Other error types

The `else` arm catches the variants this CLI doesn't special-case (unknown option, missing argument, etc.) and lets kebab render them. See the `crystal docs` output for the full list.

### Letting commands handle their own errors

In run mode a command can intercept its own errors with `def self.on_parse_error(error, stderr)`, which `Type.run` calls for the responsible command. See [`../suggestions/`](../suggestions/) for that pattern.
