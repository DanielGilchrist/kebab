# Parsing mode

Use kebab as a pure argument parser. The struct holds the parsed data and nothing else (no `def run`). The caller pattern-matches on the result and does whatever.

## Run it

```sh
crystal run main.cr -- Daniel
crystal run main.cr -- Daniel -l
crystal run main.cr -- --help
crystal run main.cr -- --bogus
```

## How it works

`Greet.parse(ARGV)` returns `Greet | Kebab::Help | Kebab::Errors` and never raises. The `case ... in` is exhaustive so the compiler tells you if you forget a branch.

Good fit when:
- the CLI is small enough that the parsed data is all you need
- you want full control over success/help/error rendering
- you don't want the command struct to carry behaviour
