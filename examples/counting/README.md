# Counting flags

`count: true` turns an integer field into a counter, the `ssh -vvv` idiom: a flag you stack to dial something up.

## Run it

```sh
crystal run main.cr -- -vvv
crystal run main.cr -- -v -v -q
crystal run main.cr --          # verbosity 0
```

## How it works

`verbosity : UInt8` counts occurrences: `-vvv`, `-v -v -v`, and `--verbosity` three times all give 3. It takes no value and never ends a short cluster, so the letters after it still parse as their own flags: `-vvq` counts twice and sets `-q`.

Use any integer type. `UInt8` keeps it to a single byte here. The count saturates at the type's maximum, so a flood of flags can never overflow it.
