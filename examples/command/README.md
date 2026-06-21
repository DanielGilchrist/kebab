# Command mode

The struct carries its behaviour in `def run`. `Type.run(ARGV)` parses, calls `run` on success, and writes help or errors to `stdout`/`stderr` for you.

## Run it

```sh
crystal run main.cr -- Daniel
crystal run main.cr -- Daniel -l -n 3
crystal run main.cr -- --help
crystal run main.cr -- Daniel --doesnt-exist
```

## How it works

`Greet.run(ARGV)` returns `Bool`. `true` for success or help, `false` for parse errors.

`Type.run` forwards any extra positional or keyword args through to `run`. If `Greet#run` took a `context`:

```crystal
Greet.run(ARGV, context)    # calls run(context)
Greet.run(ARGV, db: my_db)  # calls run(db: my_db)
```

Every `run` in a command tree must accept the same signature. A subcommand parent forwards its args straight to the chosen child, so they all have to agree.

## Redirecting output

```crystal
stdout = IO::Memory.new
stderr = IO::Memory.new
Greet.run(ARGV, stdout: stdout, stderr: stderr)
```

Help goes to `stdout`. Errors go to `stderr`.
