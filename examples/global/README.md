# Global options

A normal option is only recognised before its command's subcommand. `global: true` makes an option recognised anywhere in that command's subtree, including after subcommands.

## Run it

```sh
crystal run main.cr -- status
crystal run main.cr -- status --no-colour
crystal run main.cr -- log --no-colour -n 5
crystal run main.cr -- --no-colour log
crystal run main.cr -- log --help
```

## How it works

`--no-colour` is declared on the parent but marked global:

```crystal
@[Kebab::Option(global: true, description: "Disable coloured output")]
getter? no_colour : Bool = false
```

So all of these set it, and the value lives on the `App` instance regardless of where it appeared:

```crystal
App.parse(["--no-colour", "log"])   # before the subcommand
App.parse(["log", "--no-colour"])   # after the subcommand
```

In parsing mode you read it off the parent and use it however you like:

```crystal
in App
  colour = result.no_colour? ? "off" : "on"
  # ...
```

In command mode (`def run`) the value is still on the parent, so give the parent a `run` that reads it and passes it down to the chosen subcommand:

```crystal
struct App
  # ... global no_colour + subcommand command : Status | Log

  def run : Nil
    command.run(colour: !no_colour?)
  end
end

struct Log
  # ...
  def run(colour : Bool) : Nil
    # render with or without colour
  end
end

exit(1) unless App.run(ARGV)
```

`App.run(ARGV)` parses, then calls the parent's `run`, which forwards `colour` to whichever subcommand was chosen (`Status` and `Log` both define `run(colour : Bool)`). The global is read once, where it lives, and threaded in explicitly.

## It shows up in subcommand help

Because the global is usable under `log`, it's listed in `log`'s help and completion too, not just the parent's:

```
$ crystal run main.cr -- log --help
Usage: app log [options]

Options:
  -n, --limit <value>  How many entries
      --no-colour      Disable coloured output
  -h, --help           Show this help
```

## Notes

- A global is recognised throughout its declaring command's subtree, so a descendant can't reuse its name or short letter. Doing so is a compile error.
