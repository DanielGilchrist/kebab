# Command mode

The struct carries its behaviour in `def run`. `Type.run(ARGV)` parses, calls `run` on success, and writes help or errors to `stdout`/`stderr` for you.

## Run it

```sh
crystal run main.cr -- Daniel
crystal run main.cr -- Daniel -l -n 3
crystal run main.cr -- --help
crystal run main.cr -- Daniel --doesnt-exist
```

## What to look at

`Greet.run(ARGV)` returns `Bool`. `true` for success or help, `false` for parse errors.

`Type.run` forwards any extra positional or keyword args to `run`:

```crystal
Greet.run(ARGV, context)             # run(context)
Greet.run(ARGV, db: my_db)           # run(db: my_db)
```

Every `run` in a command tree must accept the same signature. See [`../subcommands/`](../subcommands/) for an example.

## Redirecting output

```crystal
stdout = IO::Memory.new
stderr = IO::Memory.new
Greet.run(ARGV, stdout: stdout, stderr: stderr)
```

Help goes to `stdout`. Errors go to `stderr`.
