require "colorize"

require "./completion"
require "./convert"
require "./errors"
require "./help"
require "./parse_exit"
require "./parseable/schema_check"
require "./renderer"
require "./schema/argument"
require "./schema/command"
require "./schema/option"
require "./schema/usage"
require "./token"

module Kebab
  # Included on a `struct` to make it parseable from `Array(String)` args.
  # See the project README for examples.
  module Parseable
    macro included
      @__kebab_parent_path : Array(String) = [] of String
      @__kebab_inherited_globals : Array(::Kebab::Schema::Option) = [] of ::Kebab::Schema::Option

      # Parses `args` (defaulting to `ARGV`) into either an instance of `self`,
      # a `Kebab::Help` (if the user asked for help), or one of the
      # `Kebab::Errors` variants. Never raises.
      def self.parse(args : Array(String) = ARGV) : self | ::Kebab::Help | ::Kebab::Errors
        __kebab_parse(args, [] of String)
      end

      # :nodoc:
      def self.__kebab_parse(args : Array(String), parent_path : Array(String), inherited_globals : Array(::Kebab::Schema::Option) = [] of ::Kebab::Schema::Option) : self | ::Kebab::Help | ::Kebab::Errors
        new(__kebab_args: args, __kebab_parent_path: parent_path, __kebab_inherited_globals: inherited_globals)
      rescue ex : ::Kebab::ParseExit
        ex.result
      end

      # Parses `args` and dispatches: calls `instance.run(*forward_args, **forward_kwargs)`
      # on success, writes help to `stdout`, writes errors to `stderr`.
      # Returns `true` on success or help, `false` on error.
      # Define `self.on_parse_error` on a command to customise how errors for that command are rendered.
      def self.run(args : Array(String), *forward_args, stdout : IO = STDOUT, stderr : IO = STDERR, **forward_kwargs) : Bool
        case result = parse(args)
        when ::Kebab::Help
          stdout.puts(result)
          true
        when ::Kebab::Errors
          handled = __kebab_route_error(result, stderr)
          stderr.puts(result) unless handled
          false
        else
          result.run(*forward_args, **forward_kwargs)
          true
        end
      end

      # Override this on a command to customise how its parse errors are
      # rendered when invoked through `self.run`. Return `true` to suppress
      # kebab's default rendering, `false` to fall through to it.
      def self.on_parse_error(error : ::Kebab::Errors, stderr : ::IO) : Bool
        false
      end

      # Returns the command and its whole subtree as an immutable
      # `Kebab::Schema::Command`, derived at compile time. Pure and total,
      # never raises.
      def self.schema : ::Kebab::Schema::Command
        __kebab_schema([] of String)
      end

      {% verbatim do %}
        def self.__kebab_route_error(error : ::Kebab::Errors, stderr : ::IO) : Bool
          target = error.command
          return on_parse_error(error, stderr) if target == self

          {% begin %}
            {% subcommand_ivar = @type.instance_vars.find(&.annotation(::Kebab::Subcommand)) %}
            {% if subcommand_ivar %}
              {% members = subcommand_ivar.type.union? ? subcommand_ivar.type.union_types.reject { |union_type| union_type == Nil } : [subcommand_ivar.type] %}
              {% for member in members %}
                if {{member}}.__kebab_route_error(error, stderr)
                  return true
                end
              {% end %}
            {% end %}
          {% end %}

          false
        end

        def self.__kebab_schema(parent_path : Array(String), inherited_globals : Array(::Kebab::Schema::Option) = [] of ::Kebab::Schema::Option) : ::Kebab::Schema::Command
          {% begin %}
            {%
              command = @type.annotation(::Kebab::Command)
              command_name = (command && command[:name]) || @type.name.stringify.split("::").last.underscore
              summary = (command && command[:summary]) || ""

              option_rows = [] of Nil
              global_rows = [] of Nil
              argument_rows = [] of Nil
              subcommand_members = [] of Nil
              requires_subcommand = false
              user_help_long = false
              user_help_short = false
              has_declared_options = false

              @type.instance_vars.each do |ivar|
                if subcommand = ivar.annotation(::Kebab::Subcommand)
                  requires_subcommand = !!(subcommand[:required])
                  members = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
                  members.each { |member| subcommand_members << member }
                elsif argument = ivar.annotation(::Kebab::Argument)
                  argument_name = argument[:name] || ivar.name.stringify.gsub(/_/, "-")
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  is_variadic = base.name(generic_args: false).stringify == "Array"
                  argument_rows << {argument_name, argument[:description] || "", is_variadic}
                elsif option = ivar.annotation(::Kebab::Option)
                  has_declared_options = true
                  long = option[:long] || ivar.name.stringify.gsub(/_/, "-")
                  short = option[:short]
                  user_help_long = true if long == "help"
                  user_help_short = true if short == 'h'
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  row = {long, short, option[:description] || "", base != Bool}
                  option_rows << row
                  global_rows << row if option[:global]
                end
              end

              member_pairs = [] of Nil
              user_help_subcommand = false
              subcommand_members.each do |member|
                member_command = member.annotation(::Kebab::Command)
                member_name = (member_command && member_command[:name]) || member.name.stringify.split("::").last.underscore
                user_help_subcommand = true if member_name == "help"
                member_pairs << {member_name, member}
              end
              member_pairs = member_pairs.sort_by { |member_pair| member_pair[0] }
            %}

            %path = parent_path + [{{command_name}}]

            # This command's own `global: true` options, propagated down so a
            # subcommand's help/completion lists the globals usable there too.
            %own_globals = [
              {% for global_row in global_rows %}
                ::Kebab::Schema::Option.new(
                  long: {{global_row[0]}},
                  short: {{global_row[1]}},
                  description: {{global_row[2]}},
                  takes_value: {{global_row[3]}},
                ),
              {% end %}
            ] of ::Kebab::Schema::Option

            %options = [
              {% for option_row in option_rows %}
                ::Kebab::Schema::Option.new(
                  long: {{option_row[0]}},
                  short: {{option_row[1]}},
                  description: {{option_row[2]}},
                  takes_value: {{option_row[3]}},
                ),
              {% end %}
            ] of ::Kebab::Schema::Option
            inherited_globals.each { |inherited_global| %options << inherited_global }
            {% unless user_help_long || user_help_short %}
              %options << ::Kebab::Schema::Option.new(long: "help", short: 'h', description: "Show this help", takes_value: false)
            {% end %}

            ::Kebab::Schema::Command.new(
              path: %path,
              summary: {{summary}},
              options: %options,
              arguments: [
                {% for argument_row in argument_rows %}
                  ::Kebab::Schema::Argument.new({{argument_row[0]}}, {{argument_row[1]}}, {{argument_row[2]}}),
                {% end %}
              ] of ::Kebab::Schema::Argument,
              subcommands: [
                {% for member_pair in member_pairs %}
                  {{member_pair[1]}}.__kebab_schema(%path, inherited_globals + %own_globals),
                {% end %}
                {% if !member_pairs.empty? && !user_help_subcommand %}
                  ::Kebab::Schema::Command.new(path: %path + ["help"], summary: "Show this help"),
                {% end %}
              ] of ::Kebab::Schema::Command,
              has_options: {{has_declared_options}} || !inherited_globals.empty?,
              requires_subcommand: {{requires_subcommand}},
            )
          {% end %}
        end

        def initialize(*, __kebab_args args : Array(String), __kebab_parent_path parent_path : Array(String) = [] of String, __kebab_inherited_globals inherited_globals : Array(::Kebab::Schema::Option) = [] of ::Kebab::Schema::Option)
          @__kebab_parent_path = parent_path
          @__kebab_inherited_globals = inherited_globals
          __kebab_validate_schema

          {% begin %}
              {%
                option_ivars = [] of Nil
                argument_ivars = [] of Nil
                subcommand_ivars = [] of Nil

                @type.instance_vars.each do |ivar|
                  if ivar.annotation(::Kebab::Subcommand)
                    subcommand_ivars << ivar
                  elsif ivar.annotation(::Kebab::Argument)
                    argument_ivars << ivar
                  elsif ivar.annotation(::Kebab::Option)
                    option_ivars << ivar
                  end
                end

                option_specs = option_ivars.map do |ivar|
                  option = ivar.annotation(::Kebab::Option)
                  bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
                  {
                    ivar:        ivar,
                    name:        ivar.name,
                    long:        (option && option[:long]) || ivar.name.stringify.gsub(/_/, "-"),
                    short:       option && option[:short],
                    description: (option && option[:description]) || "",
                    converter:   option && option[:converter],
                    base:        bases.first,
                    takes_value: bases.first != Bool,
                    global:      option && option[:global],
                  }
                end
                short_specs = option_specs.select { |spec| spec[:short] }
                global_specs = option_specs.select { |spec| spec[:global] }

                argument_specs = argument_ivars.map do |ivar|
                  argument = ivar.annotation(::Kebab::Argument)
                  bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
                  base = bases.first
                  variadic = base.name(generic_args: false).stringify == "Array"
                  {
                    ivar:        ivar,
                    name:        ivar.name,
                    arg_name:    (argument && argument[:name]) || ivar.name.stringify.gsub(/_/, "-"),
                    description: (argument && argument[:description]) || "",
                    converter:   argument && argument[:converter],
                    base:        base,
                    variadic:    variadic,
                    inner:       variadic ? base.type_vars.first : base,
                  }
                end

                user_defined_help_long = option_specs.any? { |spec| spec[:long] == "help" }
                user_defined_help_short = option_specs.any? { |spec| spec[:short] == 'h' }
                has_variadic_argument = argument_specs.any? { |spec| spec[:variadic] }

                subcommand_ivar = subcommand_ivars.first
                subcommand_members = if subcommand_ivar
                                       subcommand_ivar.type.union? ? subcommand_ivar.type.union_types : [subcommand_ivar.type]
                                     else
                                       [] of Nil
                                     end
                subcommand_names = subcommand_members.map do |member|
                  (member.annotation(::Kebab::Command) && member.annotation(::Kebab::Command)[:name]) || member.name.stringify.split("::").last.underscore
                end
                user_defined_help_subcommand = subcommand_names.includes?("help")

                command_annotation = @type.annotation(::Kebab::Command)
                own_command_name = (command_annotation && command_annotation[:name]) || @type.name.stringify.split("::").last.underscore
              %}

              {% for spec in option_specs + argument_specs %}
                %value{spec[:name]} : {{spec[:base]}}? = nil
              {% end %}

              {% if subcommand_ivar %}
                %value{subcommand_ivar.name} : ::Union({{subcommand_members.splat}}, ::Nil) = nil
              {% end %}

              {% for spec in option_specs %}
                %schema{spec[:name]} = ::Kebab::Schema::Option.new(long: {{spec[:long]}}, short: {{spec[:short]}}, description: {{spec[:description]}}, takes_value: {{spec[:takes_value]}})
              {% end %}
              {% for spec in argument_specs %}
                %arg_schema{spec[:name]} = ::Kebab::Schema::Argument.new(name: {{spec[:arg_name]}}, description: {{spec[:description]}}, variadic: {{spec[:variadic]}})
              {% end %}

              {% if !global_specs.empty? || subcommand_ivar %}
                %own_globals = [
                  {% for spec in global_specs %}
                    %schema{spec[:name]},
                  {% end %}
                ] of ::Kebab::Schema::Option
              {% end %}
              {% unless global_specs.empty? %}
                args = __kebab_hoist_globals(args, %own_globals)
              {% end %}

              {% unless subcommand_ivar %}
                %positionals = [] of String
              {% end %}
              %separated = false
              %index = 0

              while %index < args.size
                %raw = args[%index]
                %token = %separated ? ::Kebab::Token::Positional.new(%raw) : ::Kebab::Token.classify(%raw)

                case %token
                in ::Kebab::Token::Separator
                  %separated = true
                in ::Kebab::Token::Long
                  {% if option_specs.empty? %}
                    __kebab_bail(::Kebab::Help.new(__kebab_help_text)) if %token.name == "help"
                    __kebab_bail(::Kebab::Error::UnknownOption::For({{@type}}).new(input: %token.to_s, schema: __kebab_schema_node))
                  {% else %}
                    case %token.name
                    {% for spec in option_specs %}
                      when {{spec[:long]}}
                        unless %value{spec[:name]}.nil?
                          __kebab_bail(::Kebab::Error::RepeatedOption::For({{@type}}).new(%schema{spec[:name]}, schema: __kebab_schema_node))
                        end
                        {% if spec[:base] == Bool %}
                          if %inline = %token.value
                            __kebab_bail(::Kebab::Error::InvalidValue::Exact(Bool, {{@type}}).new(
                              value: %inline,
                              source: %schema{spec[:name]},
                              schema: __kebab_schema_node,
                              target_name: "flag",
                              reason: "flags don't accept inline values",
                            ))
                          end
                          %value{spec[:name]} = true
                        {% else %}
                          %raw_value = %token.value || __kebab_next_value(args, %index, %separated, %schema{spec[:name]}).tap { %index += 1 }
                          %value{spec[:name]} = __kebab_convert_value({{spec[:base]}}, %schema{spec[:name]}, %raw_value, {{spec[:converter]}})
                        {% end %}
                    {% end %}
                    {% unless user_defined_help_long %}
                      when "help"
                        __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                    {% end %}
                    else
                      __kebab_bail(::Kebab::Error::UnknownOption::For({{@type}}).new(input: %token.to_s, schema: __kebab_schema_node))
                    end
                  {% end %}
                in ::Kebab::Token::Shorts
                  %chars = %token.chars
                  if %chars.empty?
                    __kebab_bail(::Kebab::Error::UnknownOption::For({{@type}}).new(input: "-", schema: __kebab_schema_node))
                  end
                  %chars.each_char_with_index do |%char, %char_index|
                    %last_char = %char_index == %chars.size - 1
                    {% if short_specs.empty? %}
                      {% unless user_defined_help_short %}
                        __kebab_bail(::Kebab::Help.new(__kebab_help_text)) if %char == 'h'
                      {% end %}
                      __kebab_bail(::Kebab::Error::UnknownOption::For({{@type}}).new(input: "-#{%char}", schema: __kebab_schema_node))
                    {% else %}
                      case %char
                      {% for spec in short_specs %}
                        when {{spec[:short]}}
                          unless %value{spec[:name]}.nil?
                            __kebab_bail(::Kebab::Error::RepeatedOption::For({{@type}}).new(%schema{spec[:name]}, schema: __kebab_schema_node))
                          end
                          {% if spec[:base] == Bool %}
                            if %last_char && (%inline = %token.value)
                              __kebab_bail(::Kebab::Error::InvalidValue::Exact(Bool, {{@type}}).new(
                                value: %inline,
                                source: %schema{spec[:name]},
                                schema: __kebab_schema_node,
                                target_name: "flag",
                                reason: "flags don't accept inline values",
                              ))
                            end
                            %value{spec[:name]} = true
                          {% else %}
                            __kebab_bail(::Kebab::Error::MissingValue::For({{@type}}).new(%schema{spec[:name]}, schema: __kebab_schema_node)) unless %last_char

                            %raw_value = %token.value || __kebab_next_value(args, %index, %separated, %schema{spec[:name]}).tap { %index += 1 }
                            %value{spec[:name]} = __kebab_convert_value({{spec[:base]}}, %schema{spec[:name]}, %raw_value, {{spec[:converter]}})
                          {% end %}
                      {% end %}
                      {% unless user_defined_help_short %}
                        when 'h'
                          __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                      {% end %}
                      else
                        __kebab_bail(::Kebab::Error::UnknownOption::For({{@type}}).new(input: "-#{%char}", schema: __kebab_schema_node))
                      end
                    {% end %}
                  end
                in ::Kebab::Token::Positional
                  {% if subcommand_ivar %}
                    case %token.value
                    {% unless user_defined_help_subcommand %}
                      when "help"
                        __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                    {% end %}
                    {% for member, member_index in subcommand_members %}
                      when {{subcommand_names[member_index]}}
                        case %subcommand = {{member}}.__kebab_parse(args[(%index + 1)..], @__kebab_parent_path + [{{own_command_name}}], @__kebab_inherited_globals + %own_globals)
                        when {{member}}
                          %value{subcommand_ivar.name} = %subcommand
                        when ::Kebab::Help
                          __kebab_bail(%subcommand)
                        when ::Kebab::Errors
                          __kebab_bail(%subcommand)
                        else
                          raise "unreachable: #{%subcommand.class} from {{member}}.parse"
                        end

                        break
                    {% end %}
                    else
                      __kebab_bail(::Kebab::Error::UnknownCommand::For({{@type}}).new(input: %token.value, schema: __kebab_schema_node))
                    end
                  {% else %}
                    %positionals << %token.value
                  {% end %}
                end

                %index += 1
              end

              {% for spec, position in argument_specs %}
                {% if spec[:variadic] %}
                  if %positionals.size > {{position}}
                    %elements = [] of {{spec[:inner]}}
                    %i = {{position}}
                    while %i < %positionals.size
                      %elements << __kebab_convert_value({{spec[:inner]}}, %arg_schema{spec[:name]}, %positionals[%i], {{spec[:converter]}})
                      %i += 1
                    end
                    %value{spec[:name]} = %elements
                  end
                {% else %}
                  if %positional{spec[:name]} = %positionals[{{position}}]?
                    %value{spec[:name]} = __kebab_convert_value({{spec[:base]}}, %arg_schema{spec[:name]}, %positional{spec[:name]}, {{spec[:converter]}})
                  end
                {% end %}
              {% end %}

              {% if !subcommand_ivar && !has_variadic_argument %}
                if %extra = %positionals[{{argument_ivars.size}}]?
                  __kebab_bail(::Kebab::Error::UnexpectedArgument::For({{@type}}).new(%extra, __kebab_schema_node))
                end
              {% end %}

              {% if subcommand_ivar %}
                {% subcommand_annotation = subcommand_ivar.annotation(::Kebab::Subcommand) %}
                {% subcommand_required = !!(subcommand_annotation && subcommand_annotation[:required]) %}
                %assigned{subcommand_ivar.name} = %value{subcommand_ivar.name}
                if %assigned{subcommand_ivar.name}.nil?
                  {% if subcommand_required %}
                    __kebab_bail(::Kebab::Error::MissingCommand::For({{@type}}).new(__kebab_schema_node))
                  {% else %}
                    __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                  {% end %}
                end
                @{{subcommand_ivar.name}} = %assigned{subcommand_ivar.name}
              {% end %}

              {% for spec in option_specs %}
                %assigned{spec[:name]} = %value{spec[:name]}
                @{{spec[:name]}} =
                  if %assigned{spec[:name]}.nil?
                    {% if spec[:ivar].has_default_value? %}
                      {{spec[:ivar].default_value}}
                    {% elsif spec[:base] == Bool %}
                      false
                    {% elsif spec[:ivar].type.nilable? %}
                      nil
                    {% else %}
                      __kebab_bail(::Kebab::Error::MissingOption::For({{@type}}).new(option: %schema{spec[:name]}, schema: __kebab_schema_node))
                    {% end %}
                  else
                    %assigned{spec[:name]}
                  end
              {% end %}
              {% for spec in argument_specs %}
                %assigned{spec[:name]} = %value{spec[:name]}
                @{{spec[:name]}} =
                  if %assigned{spec[:name]}.nil?
                    {% if spec[:ivar].has_default_value? %}
                      {{spec[:ivar].default_value}}
                    {% elsif spec[:ivar].type.nilable? %}
                      nil
                    {% else %}
                      __kebab_bail(::Kebab::Error::MissingArgument::For({{@type}}).new(argument: %arg_schema{spec[:name]}, schema: __kebab_schema_node))
                    {% end %}
                  else
                    %assigned{spec[:name]}
                  end
              {% end %}
            {% end %}
        end

        private def __kebab_help_text : String
          node = self.class.__kebab_schema(@__kebab_parent_path, @__kebab_inherited_globals)

          ::String.build do |io|
            unless node.summary.empty?
              io << node.summary << "\n\n"
            end

            ::Kebab::Renderer.usage(io, node.usage)

            unless node.arguments.empty?
              io << "\n\n"
              ::Kebab::Renderer.section(io, "Arguments:", node.arguments)
            end

            unless node.subcommands.empty?
              io << "\n\n"
              ::Kebab::Renderer.section(io, "Commands:", node.subcommands)
            end

            io << "\n\n"
            ::Kebab::Renderer.section(io, "Options:", node.options)

            io << '\n'
          end
        end

        private def __kebab_bail(result : ::Kebab::Help | ::Kebab::Errors) : NoReturn
          raise ::Kebab::ParseExit.new(result)
        end

        private def __kebab_schema_node : ::Kebab::Schema::Command
          self.class.__kebab_schema(@__kebab_parent_path, @__kebab_inherited_globals)
        end

        # Moves this command's global options ahead of any subcommand, so they're recognised after subcommands too.
        # For subcommands with a value, its value is hoisted with it.
        private def __kebab_hoist_globals(args : Array(String), globals : Array(::Kebab::Schema::Option)) : Array(String)
          front = [] of String
          rest = [] of String
          index = 0
          separated = false
          while index < args.size
            raw = args[index]
            if separated
              rest << raw
            else
              matched : ::Kebab::Schema::Option? = nil
              inline : String? = nil
              case token = ::Kebab::Token.classify(raw)
              in ::Kebab::Token::Separator
                separated = true
              in ::Kebab::Token::Positional
                # leave for the normal loop
              in ::Kebab::Token::Long
                inline = token.value
                matched = globals.find { |option| option.long == token.name }
              in ::Kebab::Token::Shorts
                if token.chars.size == 1
                  inline = token.value
                  letter = token.chars[0]
                  matched = globals.find { |option| option.short == letter }
                end
              end

              if option = matched
                front << raw
                if option.takes_value? && inline.nil?
                  value = args[index + 1]?
                  if value && ::Kebab::Token.classify(value).is_a?(::Kebab::Token::Positional)
                    front << value
                    index += 1
                  else
                    {% begin %}
                      __kebab_bail(::Kebab::Error::MissingValue::For({{@type}}).new(option, schema: __kebab_schema_node))
                    {% end %}
                  end
                end
              else
                rest << raw
              end
            end
            index += 1
          end

          front + rest
        end

        private def __kebab_next_value(args : Array(String), index : Int32, separated : Bool, option : ::Kebab::Schema::Option) : String
          next_raw = args[index + 1]?
          if next_raw.nil? || (!separated && !::Kebab::Token.classify(next_raw).is_a?(::Kebab::Token::Positional))
            {% begin %}
              __kebab_bail(::Kebab::Error::MissingValue::For({{@type}}).new(option, schema: __kebab_schema_node))
            {% end %}
          end

          next_raw
        end

        private def __kebab_convert(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String) : T forall T
          __kebab_unwrap(type, source, raw, ::Kebab::Convert.parse(type, raw))
        end

        private def __kebab_convert(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, converter) : T forall T
          __kebab_unwrap(type, source, raw, converter.parse(raw))
        end

        private def __kebab_unwrap(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, result : T | ::Kebab::Convert::Failure) : T forall T
          case result
          in T
            result
          in ::Kebab::Convert::Failure
            {% begin %}
              __kebab_bail(::Kebab::Error::InvalidValue::Exact(T, {{@type}}).from(result, value: raw, source: source, schema: __kebab_schema_node))
            {% end %}
          end
        end
      {% end %}
    end

    macro __kebab_convert_value(base, source, raw, converter)
      {% if converter %}
        __kebab_convert({{base}}, {{source}}, {{raw}}, converter: {{converter}})
      {% else %}
        __kebab_convert({{base}}, {{source}}, {{raw}})
      {% end %}
    end

    def run(*forward_args, **forward_kwargs) : Nil
      {% begin %}
        {% subcommand_ivar = @type.instance_vars.find(&.annotation(::Kebab::Subcommand)) %}
        {% if subcommand_ivar %}
          @{{subcommand_ivar.id}}.run(*forward_args, **forward_kwargs)
        {% else %}
          raise "#{self.class}#run isn't defined. Add `def run(...) : Nil` so kebab can call it after parsing."
        {% end %}
      {% end %}
    end
  end
end
