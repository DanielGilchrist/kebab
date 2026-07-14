# Repeated and multi-value options

`--tag a --tag b` is a repeated option. `--range 0 50` is a multi-value option. Kebab reads both from the field's type: `Array(T)` repeats, `Tuple(A, B)` takes a group of values in one go, and `Array(Tuple(A, B))` repeats the group. A converter with `collect` folds repeats into any other type.

## Run it

```sh
crystal run main.cr -- report 1 2 3.5 4 --column time -c cost --tag q1 --tag final --range 0 50
crystal run main.cr -- report -vvv --column time    # verbosity 3
crystal run main.cr -- gather --files a.csv b.csv c.csv
crystal run main.cr -- report --help

# Errors
crystal run main.cr -- report --tag a --tag a 1 2   # duplicate tags
crystal run main.cr -- report --range 5             # expects 2 values, got 1
crystal run main.cr -- report 1 2 3                 # "3" dangles off the last pair
```

## How it works

### Repetition is opt-in through the type

`column : Array(String)` makes `--column` repeatable: `--column time -c cost` collects both, in order. Its converter returns `Array(String)`, so one value can carry several elements and `--column time,cost -c size` collects all three. A scalar option given twice is still an error.

### Folding repeats into other types

`tag : Set(String)` has a converter with a `collect`. Each occurrence goes through `convert`, then `collect` builds the set from all of them, and decides what duplicates mean. This one rejects them:

```
Error: "a", "a" aren't valid tags for "--tag" (duplicate tags)
```

A `collect` failure is a `Kebab::Error::InvalidCollection` carrying every raw value.

### Value groups

`range : Tuple(Int32, Int32)` takes both values from one occurrence, each position parsed as its own type. `value_names: {"min", "max"}` names the placeholders, so help renders `--range <min> <max>`. Coming up short is an error:

```
Error: option "--range" expects 2 values, got 1.
```

### Grouped positionals

`points : Array(Tuple(Float64, Float64))` consumes the remaining positionals in X/Y pairs: `1 2 3.5 4` is two points, and the usage line reads `<points> <points>...`. A token that half-fills a pair is an error:

```
Error: "3" wasn't expected here.
```

### Counting occurrences

`verbosity : UInt8` with `count: true` counts how many times the flag appears: `-vvv`, `-v -v -v`, and `--verbosity` three times all give 3. It takes no value and never ends a short cluster, so `-vvc time` counts twice and still reads `-c`. Any integer type works, `UInt8` just keeps it small.

### Variadic values

`arity: 1..` on `--files` consumes values until the next option. Kebab only allows that where nothing can be swallowed: a command with no positional arguments and no subcommand. That's why `gather` is a leaf with nothing else on it. Anywhere else is a compile error.
