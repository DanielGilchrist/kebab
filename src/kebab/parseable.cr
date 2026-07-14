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
          __kebab_validate_schema
          {% begin %}
            {%
              command = @type.annotation(::Kebab::Command)
              command_name = (command && command[:name]) || @type.name.stringify.split("::").last.underscore
              summary = (command && command[:summary]) || ""

              option_specs = [] of Nil
              argument_specs = [] of Nil
              subcommand_members = [] of Nil
              requires_subcommand = false

              @type.instance_vars.each do |ivar|
                if subcommand = ivar.annotation(::Kebab::Subcommand)
                  requires_subcommand = !!(subcommand[:required])
                  members = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
                  members.each { |member| subcommand_members << member }
                elsif argument = ivar.annotation(::Kebab::Argument)
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  variadic = base.name(generic_args: false).stringify == "Array"
                  inner = variadic ? base.type_vars.first : base
                  converter = argument[:converter]
                  collects = converter && (converter.resolve.class.methods + converter.resolve.methods).any? { |method| method.name.stringify == "collect" }
                  argument_specs << {
                    arg_name:     argument[:name] || ivar.name.stringify.gsub(/_/, "-"),
                    description:  argument[:description] || "",
                    variadic:     !!(variadic || collects),
                    width:        inner <= ::Tuple ? inner.type_vars.size : 1,
                    choices_enum: (!converter && inner < ::Enum) ? inner : nil,
                  }
                elsif option = ivar.annotation(::Kebab::Option)
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  array = base.name(generic_args: false).stringify == "Array"
                  occurrence = array ? base.type_vars.first : base
                  tuple = occurrence <= ::Tuple
                  counted = !!option[:count]
                  arity = option[:arity]
                  min_values = 0
                  max_values = 0
                  if base != Bool && !counted
                    if tuple
                      min_values = occurrence.type_vars.size
                      max_values = occurrence.type_vars.size
                    elsif arity.is_a?(RangeLiteral)
                      min_values = arity.begin
                      max_values = arity.end.is_a?(Nop) ? nil : arity.end
                    elsif arity
                      min_values = arity
                      max_values = arity
                    else
                      min_values = 1
                      max_values = 1
                    end
                  end
                  value_names = if names = option[:value_names]
                                  names.map { |name| name }
                                elsif base == Bool || counted
                                  [] of Nil
                                elsif max_values != min_values
                                  ["value"]
                                else
                                  (1..min_values).map { "value" }
                                end
                  option_specs << {
                    long:         option[:long] || ivar.name.stringify.gsub(/_/, "-"),
                    short:        option[:short],
                    description:  option[:description] || "",
                    value_names:  value_names,
                    min_values:   min_values,
                    max_values:   max_values,
                    global:       option[:global],
                    choices_enum: (!option[:converter] && occurrence < ::Enum) ? occurrence : nil,
                  }
                end
              end

              has_declared_options = !option_specs.empty?
              user_help_long = option_specs.any? { |spec| spec[:long] == "help" }
              user_help_short = option_specs.any? { |spec| spec[:short] == 'h' }

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

            %options = [
              {% for spec in option_specs %}
                ::Kebab::Schema::Option.new(long: {{spec[:long]}}, short: {{spec[:short]}}, description: {{spec[:description]}}, value_names: [{{spec[:value_names].splat}}] of ::String, min_values: {{spec[:min_values]}}, max_values: {{spec[:max_values]}}, value_choices: {% if spec[:choices_enum] %}{{spec[:choices_enum]}}.names.map(&.underscore).sort{% else %}[] of ::String{% end %}),
              {% end %}
            ] of ::Kebab::Schema::Option

            # Subcommands get this command's globals for their help and completion. The
            # %options indices hold because inherited globals and help are appended after.
            %own_globals = [
              {% for spec, index in option_specs %}
                {% if spec[:global] %}%options[{{index}}],{% end %}
              {% end %}
            ] of ::Kebab::Schema::Option

            inherited_globals.each { |inherited_global| %options << inherited_global }
            {% unless user_help_long || user_help_short %}
              %options << ::Kebab::Schema::Option.new(long: "help", short: 'h', description: "Show this help", value_names: [] of ::String, min_values: 0, max_values: 0)
            {% end %}

            ::Kebab::Schema::Command.new(
              path: %path,
              summary: {{summary}},
              options: %options,
              arguments: [
                {% for spec in argument_specs %}
                  ::Kebab::Schema::Argument.new(name: {{spec[:arg_name]}}, description: {{spec[:description]}}, variadic: {{spec[:variadic]}}, value_count: {{spec[:width]}}, value_choices: {% if spec[:choices_enum] %}{{spec[:choices_enum]}}.names.map(&.underscore).sort{% else %}[] of ::String{% end %}),
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
                  base = bases.first
                  array = base.name(generic_args: false).stringify == "Array"
                  occurrence = array ? base.type_vars.first : base
                  tuple = occurrence <= ::Tuple
                  counted = !!(option && option[:count])
                  arity = option && option[:arity]
                  min_values = 0
                  max_values = 0
                  if base != Bool && !counted
                    if tuple
                      min_values = occurrence.type_vars.size
                      max_values = occurrence.type_vars.size
                    elsif arity.is_a?(RangeLiteral)
                      min_values = arity.begin
                      max_values = arity.end.is_a?(Nop) ? nil : arity.end
                    elsif arity
                      min_values = arity
                      max_values = arity
                    else
                      min_values = 1
                      max_values = 1
                    end
                  end
                  value_names = if names = option && option[:value_names]
                                  names.map { |name| name }
                                elsif base == Bool || counted
                                  [] of Nil
                                elsif max_values != min_values
                                  ["value"]
                                else
                                  (1..min_values).map { "value" }
                                end
                  converter = option && option[:converter]
                  collects = converter && (converter.resolve.class.methods + converter.resolve.methods).any? { |method| method.name.stringify == "collect" }
                  {
                    ivar:        ivar,
                    name:        ivar.name,
                    long:        (option && option[:long]) || ivar.name.stringify.gsub(/_/, "-"),
                    short:       option && option[:short],
                    description: (option && option[:description]) || "",
                    converter:   converter,
                    base:        base,
                    array:       array,
                    occurrence:  occurrence,
                    tuple:       tuple,
                    tuple_types: tuple ? occurrence.type_vars : nil,
                    element:     array ? base.type_vars.first : base,
                    min_values:  min_values,
                    max_values:  max_values,
                    value_names: value_names,
                    collects:    collects,
                    count:       counted,
                    repeatable:  array || collects || counted,
                    global:      option && option[:global],
                  }
                end
                short_specs = option_specs.select { |spec| spec[:short] }
                global_specs = option_specs.select { |spec| spec[:global] }
                digit_shorts = short_specs.any? { |spec| spec[:short].stringify =~ /\d/ }

                argument_specs = argument_ivars.map do |ivar|
                  argument = ivar.annotation(::Kebab::Argument)
                  bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
                  base = bases.first
                  variadic = base.name(generic_args: false).stringify == "Array"
                  inner = variadic ? base.type_vars.first : base
                  tuple = inner <= ::Tuple
                  converter = argument && argument[:converter]
                  collects = converter && (converter.resolve.class.methods + converter.resolve.methods).any? { |method| method.name.stringify == "collect" }
                  {
                    ivar:        ivar,
                    name:        ivar.name,
                    arg_name:    (argument && argument[:name]) || ivar.name.stringify.gsub(/_/, "-"),
                    description: (argument && argument[:description]) || "",
                    converter:   converter,
                    base:        base,
                    variadic:    variadic,
                    collects:    collects,
                    inner:       inner,
                    tuple:       tuple,
                    tuple_types: tuple ? inner.type_vars : nil,
                    width:       tuple ? inner.type_vars.size : 1,
                  }
                end

                user_defined_help_long = option_specs.any? { |spec| spec[:long] == "help" }
                user_defined_help_short = option_specs.any? { |spec| spec[:short] == 'h' }
                has_variadic_argument = argument_specs.any? { |spec| spec[:variadic] || spec[:collects] }

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
                {% if spec[:collects] %}
                  %value{spec[:name]} = nil
                  %raws{spec[:name]} = [] of ::String
                {% else %}
                  %value{spec[:name]} : {{spec[:base]}}? = nil
                {% end %}
              {% end %}

              {% if subcommand_ivar %}
                %value{subcommand_ivar.name} : ::Union({{subcommand_members.splat}}, ::Nil) = nil
              {% end %}

              {% for spec in option_specs %}
                %schema{spec[:name]} = ::Kebab::Schema::Option.new(long: {{spec[:long]}}, short: {{spec[:short]}}, description: {{spec[:description]}}, value_names: [{{spec[:value_names].splat}}] of ::String, min_values: {{spec[:min_values]}}, max_values: {{spec[:max_values]}})
              {% end %}
              {% for spec in argument_specs %}
                %arg_schema{spec[:name]} = ::Kebab::Schema::Argument.new(name: {{spec[:arg_name]}}, description: {{spec[:description]}}, variadic: {{spec[:variadic]}}, value_count: {{spec[:width]}})
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
                {% unless digit_shorts %}
                  if %token.is_a?(::Kebab::Token::Shorts) && %raw.matches?(/\A-\.?\d/)
                    %token = ::Kebab::Token::Positional.new(%raw)
                  end
                {% end %}

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
                        {% unless spec[:repeatable] %}
                          unless %value{spec[:name]}.nil?
                            __kebab_bail(::Kebab::Error::RepeatedOption::For({{@type}}).new(%schema{spec[:name]}, schema: __kebab_schema_node))
                          end
                        {% end %}
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
                        {% elsif spec[:count] %}
                          if %inline = %token.value
                            __kebab_bail(::Kebab::Error::InvalidValue::Exact({{spec[:base]}}, {{@type}}).new(
                              value: %inline,
                              source: %schema{spec[:name]},
                              schema: __kebab_schema_node,
                              target_name: "flag",
                              reason: "flags don't accept inline values",
                            ))
                          end
                          __kebab_count_up(%value{spec[:name]}, {{spec[:base]}})
                        {% else %}
                          __kebab_option_value(%value{spec[:name]}, {% if spec[:collects] %}%raws{spec[:name]}{% else %}nil{% end %}, %schema{spec[:name]}, %token.value, %index, %separated, {{spec[:base]}}, {{spec[:element]}}, {{spec[:tuple_types]}}, {{spec[:array]}}, {{spec[:collects]}}, {{spec[:converter]}}, {{spec[:min_values]}}, {{spec[:max_values]}}, nil)
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
                    __kebab_bail(::Kebab::Error::UnknownOption::For({{@type}}).new(input: %raw, schema: __kebab_schema_node))
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
                          {% unless spec[:repeatable] %}
                            unless %value{spec[:name]}.nil?
                              __kebab_bail(::Kebab::Error::RepeatedOption::For({{@type}}).new(%schema{spec[:name]}, schema: __kebab_schema_node, invoked: "-#{%char}"))
                            end
                          {% end %}
                          {% if spec[:base] == Bool %}
                            if %last_char && (%inline = %token.value)
                              __kebab_bail(::Kebab::Error::InvalidValue::Exact(Bool, {{@type}}).new(
                                value: %inline,
                                source: %schema{spec[:name]},
                                schema: __kebab_schema_node,
                                target_name: "flag",
                                reason: "flags don't accept inline values",
                                invoked: "-#{%char}",
                              ))
                            end
                            %value{spec[:name]} = true
                          {% elsif spec[:count] %}
                            if %last_char && (%inline = %token.value)
                              __kebab_bail(::Kebab::Error::InvalidValue::Exact({{spec[:base]}}, {{@type}}).new(
                                value: %inline,
                                source: %schema{spec[:name]},
                                schema: __kebab_schema_node,
                                target_name: "flag",
                                reason: "flags don't accept inline values",
                                invoked: "-#{%char}",
                              ))
                            end
                            # A counted short takes no value and does not end the cluster.
                            __kebab_count_up(%value{spec[:name]}, {{spec[:base]}})
                          {% else %}
                            # A valued short ends the cluster: the rest is its value (`-j4`), or the next token when it's last (`-j 4`).
                            if %last_char
                              __kebab_option_value(%value{spec[:name]}, {% if spec[:collects] %}%raws{spec[:name]}{% else %}nil{% end %}, %schema{spec[:name]}, %token.value, %index, %separated, {{spec[:base]}}, {{spec[:element]}}, {{spec[:tuple_types]}}, {{spec[:array]}}, {{spec[:collects]}}, {{spec[:converter]}}, {{spec[:min_values]}}, {{spec[:max_values]}}, "-#{%char}")
                            else
                              # The tokenizer split any `=` into `value`, so put it back: `-Dfoo=bar` gives `-D` the value `foo=bar`.
                              %attached = %chars[(%char_index + 1)..]
                              %attached = "#{%attached}=#{%token.value}" if %token.value
                              __kebab_option_value(%value{spec[:name]}, {% if spec[:collects] %}%raws{spec[:name]}{% else %}nil{% end %}, %schema{spec[:name]}, %attached, %index, %separated, {{spec[:base]}}, {{spec[:element]}}, {{spec[:tuple_types]}}, {{spec[:array]}}, {{spec[:collects]}}, {{spec[:converter]}}, {{spec[:min_values]}}, {{spec[:max_values]}}, "-#{%char}")
                              break
                            end
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
                    # Tokens after `--` are operands, never command dispatch.
                    if %separated
                      __kebab_bail(::Kebab::Error::UnexpectedArgument::For({{@type}}).new(%token.value, __kebab_schema_node))
                    end
                    case %token.value
                    {% unless user_defined_help_subcommand %}
                      when "help"
                        # `app help sub` shows sub's help, like `app sub --help`. Bare `help` shows this command's.
                        if %index + 1 < args.size
                          case %help = {{@type}}.__kebab_parse(args[(%index + 1)..] + ["--help"], @__kebab_parent_path, @__kebab_inherited_globals)
                          when ::Kebab::Help
                            __kebab_bail(%help)
                          when ::Kebab::Errors
                            __kebab_bail(%help)
                          else
                            __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                          end
                        else
                          __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                        end
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

              {% offset = 0 %}
              {% for spec in argument_specs %}
                {% if spec[:variadic] && spec[:tuple] %}
                  if %positionals.size > {{offset}}
                    if (%remainder{spec[:name]} = (%positionals.size - {{offset}}) % {{spec[:width]}}) != 0
                      __kebab_bail(::Kebab::Error::UnexpectedArgument::For({{@type}}).new(%positionals[%positionals.size - %remainder{spec[:name]}], __kebab_schema_node))
                    end
                    %elements = [] of {{spec[:inner]}}
                    %i = {{offset}}
                    while %i < %positionals.size
                      %elements << { {% for tuple_type, tuple_position in spec[:tuple_types] %} __kebab_convert_value({{tuple_type}}, %arg_schema{spec[:name]}, %positionals[%i + {{tuple_position}}], {{spec[:converter]}}), {% end %} }
                      %i += {{spec[:width]}}
                    end
                    %value{spec[:name]} = %elements
                  end
                {% elsif spec[:variadic] %}
                  if %positionals.size > {{offset}}
                    %elements = [] of {{spec[:inner]}}
                    %i = {{offset}}
                    while %i < %positionals.size
                      {% if spec[:converter] %}
                        __kebab_append(%elements, __kebab_convert_element(%arg_schema{spec[:name]}, %positionals[%i], {{spec[:converter]}}))
                      {% else %}
                        %elements << __kebab_convert({{spec[:inner]}}, %arg_schema{spec[:name]}, %positionals[%i])
                      {% end %}
                      %i += 1
                    end
                    %value{spec[:name]} = %elements
                  end
                {% elsif spec[:collects] %}
                  if %positionals.size > {{offset}}
                    %i = {{offset}}
                    while %i < %positionals.size
                      %element{spec[:name]} = __kebab_convert_element(%arg_schema{spec[:name]}, %positionals[%i], {{spec[:converter]}})
                      if %existing{spec[:name]} = %value{spec[:name]}
                        %existing{spec[:name]} << %element{spec[:name]}
                      else
                        %value{spec[:name]} = [%element{spec[:name]}]
                      end
                      %raws{spec[:name]} << %positionals[%i]
                      %i += 1
                    end
                  end
                {% elsif spec[:tuple] %}
                  if %positionals.size >= {{offset + spec[:width]}}
                    %value{spec[:name]} = { {% for tuple_type, tuple_position in spec[:tuple_types] %} __kebab_convert_value({{tuple_type}}, %arg_schema{spec[:name]}, %positionals[{{offset + tuple_position}}], {{spec[:converter]}}), {% end %} }
                  elsif %positionals.size > {{offset}}
                    __kebab_bail(::Kebab::Error::MissingArgument::For({{@type}}).new(argument: %arg_schema{spec[:name]}, schema: __kebab_schema_node))
                  end
                  {% offset = offset + spec[:width] %}
                {% else %}
                  if %positional{spec[:name]} = %positionals[{{offset}}]?
                    %value{spec[:name]} = __kebab_convert_value({{spec[:base]}}, %arg_schema{spec[:name]}, %positional{spec[:name]}, {{spec[:converter]}})
                  end
                  {% offset = offset + 1 %}
                {% end %}
              {% end %}

              {% if !subcommand_ivar && !has_variadic_argument %}
                if %extra = %positionals[{{offset}}]?
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

              # Option specs carry `:long`; argument specs don't, which tells them apart.
              {% for spec in option_specs + argument_specs %}
                %assigned{spec[:name]} = %value{spec[:name]}
                @{{spec[:name]}} =
                  if %assigned{spec[:name]}.nil?
                    {% if spec[:ivar].has_default_value? %}
                      {{spec[:ivar].default_value}}
                    {% elsif spec[:count] %}
                      {{spec[:base]}}.zero
                    {% elsif spec[:base] == Bool %}
                      false
                    {% elsif spec[:ivar].type.nilable? %}
                      nil
                    {% elsif spec[:long] %}
                      __kebab_bail(::Kebab::Error::MissingOption::For({{@type}}).new(option: %schema{spec[:name]}, schema: __kebab_schema_node))
                    {% else %}
                      __kebab_bail(::Kebab::Error::MissingArgument::For({{@type}}).new(argument: %arg_schema{spec[:name]}, schema: __kebab_schema_node))
                    {% end %}
                  else
                    {% if spec[:collects] %}
                      __kebab_collect({{spec[:base]}}, {% if spec[:long] %}%schema{spec[:name]}{% else %}%arg_schema{spec[:name]}{% end %}, %raws{spec[:name]}, {{spec[:converter]}}, %assigned{spec[:name]})
                    {% else %}
                      %assigned{spec[:name]}
                    {% end %}
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
        # A global that takes a value has its value hoisted with it.
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
              invoked : String? = nil
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
                  invoked = "-#{letter}"
                elsif token.chars.size > 1
                  first = globals.find { |option| option.short == token.chars[0] }
                  if first && first.takes_value?
                    # An attached-value global (`-steam`) hoists whole, its value already in the token.
                    matched = first
                    inline = token.chars[1..]
                  elsif token.chars.each_char.all? { |char| globals.any? { |option| option.short == char && !option.takes_value? } }
                    # A cluster of valueless globals (`-vv`, `-vq`) hoists whole and parses in place.
                    # A single non-global letter (like a subcommand's own flag) leaves the token alone.
                    matched = first
                  end
                end
              end

              if option = matched
                front << raw
                if option.takes_value? && inline.nil?
                  option.min_values.times do |consumed|
                    value = args[index + 1]?
                    if value && __kebab_value_token?(value)
                      front << value
                      index += 1
                    else
                      {% begin %}
                        __kebab_bail(::Kebab::Error::MissingValue::For({{@type}}).new(option, schema: __kebab_schema_node, got: consumed, invoked: invoked))
                      {% end %}
                    end
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

        # Negative numbers (`-5`, `-.5`) would otherwise classify as short-option clusters.
        private def __kebab_value_token?(raw : String) : Bool
          ::Kebab::Token.classify(raw).is_a?(::Kebab::Token::Positional) || /\A-(\.?\d)/.matches?(raw)
        end

        # Consumes an occurrence's worth of values for a multi-value option:
        # up to `max_values` tokens, stopping at anything that doesn't read as a
        # value. Below `min_values` is an error. The caller advances the index.
        private def __kebab_next_values(args : Array(String), index : Int32, separated : Bool, option : ::Kebab::Schema::Option, invoked : String? = nil) : Array(String)
          values = [] of String
          max = option.max_values
          while max.nil? || values.size < max
            next_raw = args[index + values.size + 1]?
            break if next_raw.nil?
            break unless separated || __kebab_value_token?(next_raw)
            values << next_raw
          end

          if values.size < option.min_values
            {% begin %}
              __kebab_bail(::Kebab::Error::MissingValue::For({{@type}}).new(option, schema: __kebab_schema_node, got: values.size, invoked: invoked))
            {% end %}
          end

          values
        end

        private def __kebab_next_value(args : Array(String), index : Int32, separated : Bool, option : ::Kebab::Schema::Option, invoked : String? = nil) : String
          next_raw = args[index + 1]?
          if next_raw.nil? || (!separated && !__kebab_value_token?(next_raw))
            {% begin %}
              __kebab_bail(::Kebab::Error::MissingValue::For({{@type}}).new(option, schema: __kebab_schema_node, invoked: invoked))
            {% end %}
          end

          next_raw
        end

        private def __kebab_convert(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, invoked : String? = nil) : T forall T
          __kebab_unwrap(type, source, raw, ::Kebab::Convert.convert(type, raw), invoked)
        end

        private def __kebab_convert(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, converter, invoked : String? = nil) : T forall T
          __kebab_unwrap(type, source, raw, converter.convert(raw), invoked)
        end

        private def __kebab_unwrap(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, result : T | ::Kebab::Convert::Failure, invoked : String? = nil) : T forall T
          case result
          in T
            result
          in ::Kebab::Convert::Failure
            {% begin %}
              __kebab_bail(::Kebab::Error::InvalidValue::Exact(T, {{@type}}).from(result, value: raw, source: source, schema: __kebab_schema_node, invoked: invoked))
            {% end %}
          end
        end

        # For a converter with `collect`, the element type is the converter's
        # business, so it is deduced from `convert`'s return instead of passed in.
        private def __kebab_convert_element(source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, converter, invoked : String? = nil)
          __kebab_unwrap_element(source, raw, converter.convert(raw), invoked)
        end

        private def __kebab_unwrap_element(source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, raw : String, result : T | ::Kebab::Convert::Failure, invoked : String? = nil) : T forall T
          __kebab_unwrap(T, source, raw, result, invoked)
        end

        private def __kebab_append(list : Array(T), element : T) : Nil forall T
          list << element
        end

        private def __kebab_append(list : Array(T), elements : Array(T)) : Nil forall T
          list.concat(elements)
        end

        private def __kebab_list(element : T) : Array(T) forall T
          [element]
        end

        private def __kebab_list(elements : Array(T)) : Array(T) forall T
          elements.dup
        end

        private def __kebab_collect(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, values : Array(String), converter, elements) : T forall T
          __kebab_unwrap_collection(type, source, values, converter.collect(elements))
        end

        private def __kebab_unwrap_collection(type : T.class, source : ::Kebab::Schema::Option | ::Kebab::Schema::Argument, values : Array(String), result : T | ::Kebab::Convert::Failure) : T forall T
          case result
          in T
            result
          in ::Kebab::Convert::Failure
            {% begin %}
              __kebab_bail(::Kebab::Error::InvalidCollection::Exact(T, {{@type}}).from(result, values: values, source: source, schema: __kebab_schema_node))
            {% end %}
          end
        end
      {% end %}
    end

    # One occurrence of a valued option: consume its values, convert them, and
    # store them on `value`. Shared by the long and short parsing branches.
    macro __kebab_option_value(value, raws, schema, inline, index, separated, base, element, tuple_types, array, collects, converter, min_values, max_values, invoked)
      {% if min_values == 1 && max_values == 1 %}
        %raw_value = {{inline}} || __kebab_next_value(args, {{index}}, {{separated}}, {{schema}}, {{invoked}}).tap { {{index}} += 1 }
        {% if collects %}
          %element = __kebab_convert_element({{schema}}, %raw_value, {{converter}}, {{invoked}})
          if %existing = {{value}}
            %existing << %element
          else
            {{value}} = [%element]
          end
          {{raws}} << %raw_value
        {% elsif array %}
          {% if converter %}
            %element = __kebab_convert_element({{schema}}, %raw_value, {{converter}}, {{invoked}})
          {% else %}
            %element = __kebab_convert({{element}}, {{schema}}, %raw_value, invoked: {{invoked}})
          {% end %}
          if %existing = {{value}}
            __kebab_append(%existing, %element)
          else
            {{value}} = __kebab_list(%element)
          end
        {% else %}
          {{value}} = __kebab_convert_value({{base}}, {{schema}}, %raw_value, {{converter}}, {{invoked}})
        {% end %}
      {% else %}
        if %inline = {{inline}}
          __kebab_bail(::Kebab::Error::InvalidValue::Exact({{base}}, {{@type}}).new(
            value: %inline,
            source: {{schema}},
            schema: __kebab_schema_node,
            reason: "takes multiple values as separate tokens, not inline",
            invoked: {{invoked}},
          ))
        end
        %values = __kebab_next_values(args, {{index}}, {{separated}}, {{schema}}, {{invoked}})
        {{index}} += %values.size
        {% if tuple_types && !array %}
          {{value}} = { {% for tuple_type, position in tuple_types %} __kebab_convert_value({{tuple_type}}, {{schema}}, %values[{{position}}], {{converter}}, {{invoked}}), {% end %} }
        {% elsif tuple_types %}
          %element = { {% for tuple_type, position in tuple_types %} __kebab_convert_value({{tuple_type}}, {{schema}}, %values[{{position}}], {{converter}}, {{invoked}}), {% end %} }
          if %existing = {{value}}
            %existing << %element
          else
            {{value}} = [%element] of {{element}}
          end
        {% elsif collects %}
          %values.each do |%one|
            %element = __kebab_convert_element({{schema}}, %one, {{converter}}, {{invoked}})
            if %existing = {{value}}
              %existing << %element
            else
              {{value}} = [%element]
            end
            {{raws}} << %one
          end
        {% else %}
          %values.each do |%one|
            {% if converter %}
              %element = __kebab_convert_element({{schema}}, %one, {{converter}}, {{invoked}})
            {% else %}
              %element = __kebab_convert({{element}}, {{schema}}, %one, invoked: {{invoked}})
            {% end %}
            if %existing = {{value}}
              __kebab_append(%existing, %element)
            else
              {{value}} = __kebab_list(%element)
            end
          end
        {% end %}
      {% end %}
    end

    # Counts one more occurrence, saturating at the type's maximum so a flood of
    # flags (`-vvv...`) can never overflow a narrow int and break `never raises`.
    macro __kebab_count_up(value, base)
      %current = {{value}} || {{base}}.zero
      {{value}} = %current < {{base}}::MAX ? %current + 1 : %current
    end

    macro __kebab_convert_value(base, source, raw, converter, invoked = nil)
      {% if converter %}
        __kebab_convert({{base}}, {{source}}, {{raw}}, converter: {{converter}}, invoked: {{invoked}})
      {% else %}
        __kebab_convert({{base}}, {{source}}, {{raw}}, invoked: {{invoked}})
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
