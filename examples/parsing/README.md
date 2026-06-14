# Parsing mode

Use kebab as a pure argument parser. The struct holds the parsed data and nothing else. No `def run`. The caller pattern-matches on the result and does whatever it wants.

## Run it

```
crystal run main.cr -- Daniel
crystal run main.cr -- Daniel -l
crystal run main.cr -- --help
crystal run main.cr -- --bogus
```

## What to look at

`Greet.parse(ARGV)` returns `Greet | Kebab::Help | Kebab::Errors`. The `case ... in` is exhaustive so the compiler tells you if you forget a branch.

Good fit when:
- the CLI is small enough that the parsed data is all you need
- you want full control over success/help/error rendering
- you don't want the command struct to carry behaviour
