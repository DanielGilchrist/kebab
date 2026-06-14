require "colorize"

require "./convert"
require "./errors"
require "./help"
require "./internal"
require "./parseable/schema_check"
require "./renderer"
require "./scanner"
require "./schema/argument"
require "./schema/command"
require "./schema/option"
require "./schema/usage"

module Kebab
  module Parseable
    macro included
      @__kebab_parent_path : Array(String) = [] of String

      def self.parse(args : Array(String), parent_path : Array(String) = [] of String) : self | ::Kebab::Help | ::Kebab::Errors
        new(__kebab_args: args, __kebab_parent_path: parent_path)
      rescue ex : ::Kebab::Internal::ParseExit
        ex.result
      end

      {% verbatim do %}
        def initialize(*, __kebab_args args : Array(String), __kebab_parent_path parent_path : Array(String) = [] of String)
          @__kebab_parent_path = parent_path
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

                short_ivars = option_ivars.select { |option_ivar| option_ivar.annotation(::Kebab::Option) && option_ivar.annotation(::Kebab::Option)[:short] }

                long_names = {} of String => String
                option_ivars.each do |ivar|
                  option = ivar.annotation(::Kebab::Option)
                  long = (option && option[:long]) || ivar.name.stringify.gsub(/_/, "-")
                  long_names[long] = ivar.name.stringify
                end
                short_letters = {} of Char => String
                option_ivars.each do |ivar|
                  short = ivar.annotation(::Kebab::Option)[:short]
                  short_letters[short] = ivar.name.stringify if short
                end
                user_defined_help_long = long_names["help"] != nil
                user_defined_help_short = short_letters['h'] != nil

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

                has_variadic_argument = argument_ivars.any? do |ivar|
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  base.name(generic_args: false).stringify == "Array"
                end
              %}

              {% for ivar in option_ivars + argument_ivars %}
                {% bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type] %}
                %value{ivar.name} : {{bases.first}}? = nil
              {% end %}

              {% if subcommand_ivar %}
                %value{subcommand_ivar.name} : ::Union({{subcommand_members.splat}}, ::Nil) = nil
              {% end %}

              {% unless subcommand_ivar %}
                %positionals = [] of String
              {% end %}
              %separated = false
              %index = 0

              while %index < args.size
                %raw = args[%index]
                %token = %separated ? ::Kebab::Tokens::Positional.new(%raw) : ::Kebab::Scanner.scan(%raw)

                case %token
                in ::Kebab::Tokens::Separator
                  %separated = true
                in ::Kebab::Tokens::Long
                  {% if option_ivars.empty? %}
                    __kebab_bail(::Kebab::Help.new(__kebab_help_text)) if %token.name == "help"
                    __kebab_bail(::Kebab::Error::UnknownOption.new(%token.to_s, __kebab_options_schema, __kebab_usage))
                  {% else %}
                    case %token.name
                    {% for ivar in option_ivars %}
                      {%
                        option = ivar.annotation(::Kebab::Option)
                        long = (option && option[:long]) || ivar.name.stringify.gsub(/_/, "-")
                        converter = option && option[:converter]
                        base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                      %}
                      when {{long}}
                        unless %value{ivar.name}.nil?
                          __kebab_bail(::Kebab::Error::RepeatedOption.new("--#{{{long}}}"))
                        end
                        {% if base == Bool %}
                          if %inline = %token.value
                            __kebab_bail(::Kebab::Error::InvalidValueOf(Bool).new(
                              value: %inline,
                              option: "--#{{{long}}}",
                              target_name: "flag",
                              reason: "flags don't accept inline values",
                            ))
                          end
                          %value{ivar.name} = true
                        {% else %}
                          %raw_value = %token.value || __kebab_next_value(args, %index, %separated, "--#{{{long}}}").tap { %index += 1 }
                          {% if converter %}
                            %value{ivar.name} = __kebab_convert({{base}}, "--#{{{long}}}", %raw_value, converter: {{converter}})
                          {% else %}
                            %value{ivar.name} = __kebab_convert({{base}}, "--#{{{long}}}", %raw_value)
                          {% end %}
                        {% end %}
                    {% end %}
                    {% unless user_defined_help_long %}
                      when "help"
                        __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                    {% end %}
                    else
                      __kebab_bail(::Kebab::Error::UnknownOption.new(%token.to_s, __kebab_options_schema, __kebab_usage))
                    end
                  {% end %}
                in ::Kebab::Tokens::Shorts
                  %chars = %token.chars
                  if %chars.empty?
                    __kebab_bail(::Kebab::Error::UnknownOption.new("-", __kebab_options_schema, __kebab_usage))
                  end
                  %chars.each_char_with_index do |%char, %char_index|
                    %last_char = %char_index == %chars.size - 1
                    {% if short_ivars.empty? %}
                      {% unless user_defined_help_short %}
                        __kebab_bail(::Kebab::Help.new(__kebab_help_text)) if %char == 'h'
                      {% end %}
                      __kebab_bail(::Kebab::Error::UnknownOption.new("-#{%char}", __kebab_options_schema, __kebab_usage))
                    {% else %}
                      case %char
                      {% for ivar in short_ivars %}
                        {%
                          option = ivar.annotation(::Kebab::Option)
                          short = option[:short]
                          converter = option[:converter]
                          base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                        %}
                        when {{short}}
                          unless %value{ivar.name}.nil?
                            __kebab_bail(::Kebab::Error::RepeatedOption.new("-#{{{short}}}"))
                          end
                          {% if base == Bool %}
                            if %last_char && (%inline = %token.value)
                              __kebab_bail(::Kebab::Error::InvalidValueOf(Bool).new(
                                value: %inline,
                                option: "-#{{{short}}}",
                                target_name: "flag",
                                reason: "flags don't accept inline values",
                              ))
                            end
                            %value{ivar.name} = true
                          {% else %}
                            __kebab_bail(::Kebab::Error::MissingValue.new("-#{{{short}}}")) unless %last_char

                            %raw_value = %token.value || __kebab_next_value(args, %index, %separated, "-#{{{short}}}").tap { %index += 1 }
                            {% if converter %}
                              %value{ivar.name} = __kebab_convert({{base}}, "-#{{{short}}}", %raw_value, converter: {{converter}})
                            {% else %}
                              %value{ivar.name} = __kebab_convert({{base}}, "-#{{{short}}}", %raw_value)
                            {% end %}
                          {% end %}
                      {% end %}
                      {% unless user_defined_help_short %}
                        when 'h'
                          __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                      {% end %}
                      else
                        __kebab_bail(::Kebab::Error::UnknownOption.new("-#{%char}", __kebab_options_schema, __kebab_usage))
                      end
                    {% end %}
                  end
                in ::Kebab::Tokens::Positional
                  {% if subcommand_ivar %}
                    case %token.value
                    {% unless user_defined_help_subcommand %}
                      when "help"
                        __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                    {% end %}
                    {% for member, member_index in subcommand_members %}
                      when {{subcommand_names[member_index]}}
                        case %subcommand = {{member}}.parse(args[(%index + 1)..], parent_path: @__kebab_parent_path + [{{own_command_name}}])
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
                      __kebab_bail(::Kebab::Error::UnknownCommand.new(%token.value, __kebab_commands_schema, __kebab_usage))
                    end
                  {% else %}
                    %positionals << %token.value
                  {% end %}
                end

                %index += 1
              end

              {% for ivar, position in argument_ivars %}
                {%
                  argument = ivar.annotation(::Kebab::Argument)
                  argument_name = (argument && argument[:name]) || ivar.name.stringify.gsub(/_/, "-")
                  converter = argument && argument[:converter]
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  is_variadic = base.name(generic_args: false).stringify == "Array"
                %}
                {% if is_variadic %}
                  {% inner_type = base.type_vars.first %}
                  if %positionals.size > {{position}}
                    %elements = [] of {{inner_type}}
                    %i = {{position}}
                    while %i < %positionals.size
                      {% if converter %}
                        %elements << __kebab_convert({{inner_type}}, {{argument_name}}, %positionals[%i], converter: {{converter}})
                      {% else %}
                        %elements << __kebab_convert({{inner_type}}, {{argument_name}}, %positionals[%i])
                      {% end %}
                      %i += 1
                    end
                    %value{ivar.name} = %elements
                  end
                {% else %}
                  if %positional{ivar.name} = %positionals[{{position}}]?
                    {% if converter %}
                      %value{ivar.name} = __kebab_convert({{base}}, {{argument_name}}, %positional{ivar.name}, converter: {{converter}})
                    {% else %}
                      %value{ivar.name} = __kebab_convert({{base}}, {{argument_name}}, %positional{ivar.name})
                    {% end %}
                  end
                {% end %}
              {% end %}

              {% if !subcommand_ivar && !has_variadic_argument %}
                if %extra = %positionals[{{argument_ivars.size}}]?
                  __kebab_bail(::Kebab::Error::UnexpectedArgument.new(%extra, __kebab_arguments_schema, __kebab_usage))
                end
              {% end %}

              {% if subcommand_ivar %}
                {% subcommand_annotation = subcommand_ivar.annotation(::Kebab::Subcommand) %}
                {% subcommand_required = !!(subcommand_annotation && subcommand_annotation[:required]) %}
                %assigned{subcommand_ivar.name} = %value{subcommand_ivar.name}
                if %assigned{subcommand_ivar.name}.nil?
                  {% if subcommand_required %}
                    __kebab_bail(::Kebab::Error::MissingCommand.new(__kebab_commands_schema, __kebab_usage))
                  {% else %}
                    __kebab_bail(::Kebab::Help.new(__kebab_help_text))
                  {% end %}
                end
                @{{subcommand_ivar.name}} = %assigned{subcommand_ivar.name}
              {% end %}

              {% for ivar in option_ivars + argument_ivars %}
                {%
                  option = ivar.annotation(::Kebab::Option)
                  argument = ivar.annotation(::Kebab::Argument)
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type

                  display_name =
                    if argument
                      (argument[:name] || ivar.name.stringify.gsub(/_/, "-"))
                    else
                      "--#{((option && option[:long]) || ivar.name.stringify.gsub(/_/, "-")).id}"
                    end
                %}
                %assigned{ivar.name} = %value{ivar.name}
                @{{ivar.name}} =
                  if %assigned{ivar.name}.nil?
                    {% if ivar.has_default_value? %}
                      {{ivar.default_value}}
                    {% elsif base == Bool %}
                      false
                    {% elsif ivar.type.nilable? %}
                      nil
                    {% else %}
                      {% if argument %}
                        __kebab_bail(::Kebab::Error::MissingArgument.new({{display_name}}, __kebab_arguments_schema, __kebab_usage))
                      {% else %}
                        __kebab_bail(::Kebab::Error::MissingOption.new({{display_name}}, __kebab_options_schema, __kebab_usage))
                      {% end %}
                    {% end %}
                  else
                    %assigned{ivar.name}
                  end
              {% end %}
            {% end %}
        end

        private def __kebab_usage
          {% begin %}
            {%
              command = @type.annotation(::Kebab::Command)
              command_name = (command && command[:name]) || @type.name.stringify.split("::").last.underscore

              has_subcommand = false
              has_options = false
              argument_names = [] of Nil
              tail_variadic = false

              @type.instance_vars.each do |ivar|
                if ivar.annotation(::Kebab::Subcommand)
                  has_subcommand = true
                elsif argument = ivar.annotation(::Kebab::Argument)
                  argument_name = argument[:name] || ivar.name.stringify.gsub(/_/, "-")
                  argument_names << argument_name
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  tail_variadic = base.name(generic_args: false).stringify == "Array"
                elsif ivar.annotation(::Kebab::Option)
                  has_options = true
                end
              end
            %}

            {% if has_subcommand %}
              ::Kebab::Schema::Usage::Subcommand.new(
                command_path: @__kebab_parent_path + [{{command_name}}],
                has_options: {{has_options}},
              )
            {% else %}
              ::Kebab::Schema::Usage::Arguments.new(
                command_path: @__kebab_parent_path + [{{command_name}}],
                has_options: true,
                argument_names: {{argument_names}} of ::String,
                has_variadic_tail: {{tail_variadic}},
              )
            {% end %}
          {% end %}
        end

        private def __kebab_commands_schema : Array(::Kebab::Schema::Command)
          {% begin %}
            {%
              command_rows = [] of Nil
              user_defined_help_subcommand = false

              @type.instance_vars.each do |ivar|
                if ivar.annotation(::Kebab::Subcommand)
                  members = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
                  members.each do |member|
                    member_command = member.annotation(::Kebab::Command)
                    member_name = (member_command && member_command[:name]) || member.name.stringify.split("::").last.underscore
                    user_defined_help_subcommand = true if member_name == "help"
                    command_rows << {member_name, (member_command && member_command[:summary]) || ""}
                  end
                end
              end

              command_rows = command_rows.sort_by { |command_row| command_row[0] }
              if !command_rows.empty? && !user_defined_help_subcommand
                command_rows << {"help", "Show this help"}
              end
            %}

            [
              {% for command_row in command_rows %}
                ::Kebab::Schema::Command.new({{command_row[0]}}, {{command_row[1]}}),
              {% end %}
            ] of ::Kebab::Schema::Command
          {% end %}
        end

        private def __kebab_options_schema : Array(::Kebab::Schema::Option)
          {% begin %}
            {%
              option_rows = [] of Nil
              user_defined_help_long = false
              user_defined_help_short = false

              @type.instance_vars.each do |ivar|
                if option = ivar.annotation(::Kebab::Option)
                  long = option[:long] || ivar.name.stringify.gsub(/_/, "-")
                  short = option[:short]
                  user_defined_help_long = true if long == "help"
                  user_defined_help_short = true if short == 'h'
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  option_rows << {long, short, option[:description] || "", base != Bool}
                end
              end

              unless user_defined_help_long || user_defined_help_short
                option_rows << {"help", 'h', "Show this help", false}
              end
            %}

            [
              {% for option_row in option_rows %}
                ::Kebab::Schema::Option.new(
                  long: {{option_row[0]}},
                  short: {{option_row[1]}},
                  description: {{option_row[2]}},
                  takes_value: {{option_row[3]}},
                ),
              {% end %}
            ] of ::Kebab::Schema::Option
          {% end %}
        end

        private def __kebab_arguments_schema : Array(::Kebab::Schema::Argument)
          {% begin %}
            {%
              argument_rows = [] of Nil
              @type.instance_vars.each do |ivar|
                if argument = ivar.annotation(::Kebab::Argument)
                  argument_name = argument[:name] || ivar.name.stringify.gsub(/_/, "-")
                  base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
                  is_variadic = base.name(generic_args: false).stringify == "Array"
                  argument_rows << {argument_name, argument[:description] || "", is_variadic}
                end
              end
            %}

            [
              {% for argument_row in argument_rows %}
                ::Kebab::Schema::Argument.new({{argument_row[0]}}, {{argument_row[1]}}, {{argument_row[2]}}),
              {% end %}
            ] of ::Kebab::Schema::Argument
          {% end %}
        end

        private def __kebab_help_text : String
          {% begin %}
            {% command = @type.annotation(::Kebab::Command) %}
            {% summary = command && command[:summary] %}

            ::String.build do |%io|
              {% if summary %}
                %io << {{summary}} << "\n\n"
              {% end %}

              ::Kebab::Renderer.usage(%io, __kebab_usage)

              %arguments = __kebab_arguments_schema
              unless %arguments.empty?
                %io << "\n\n"
                ::Kebab::Renderer.section(%io, "Arguments:", %arguments)
              end

              %commands = __kebab_commands_schema
              unless %commands.empty?
                %io << "\n\n"
                ::Kebab::Renderer.section(%io, "Commands:", %commands)
              end

              %io << "\n\n"
              ::Kebab::Renderer.section(%io, "Options:", __kebab_options_schema)

              %io << '\n'
            end
          {% end %}
        end
      {% end %}
    end

    def run(context) : Nil
      {% begin %}
        {% subcommand_ivar = @type.instance_vars.find(&.annotation(::Kebab::Subcommand)) %}
        {% if subcommand_ivar %}
          @{{subcommand_ivar.id}}.run(context)
        {% else %}
          raise "#{self.class}#run isn't defined. Add `def run(context : YourContextType) : Nil` so kebab can call it after parsing."
        {% end %}
      {% end %}
    end

    private def __kebab_bail(result : ::Kebab::Help | ::Kebab::Errors) : NoReturn
      raise ::Kebab::Internal::ParseExit.new(result)
    end

    private def __kebab_next_value(args : Array(String), index : Int32, separated : Bool, name : String) : String
      next_raw = args[index + 1]?
      if next_raw.nil? || (!separated && !::Kebab::Scanner.scan(next_raw).is_a?(::Kebab::Tokens::Positional))
        __kebab_bail(::Kebab::Error::MissingValue.new(name))
      end

      next_raw
    end

    private def __kebab_convert(type : T.class, name : String, raw : String) : T forall T
      __kebab_unwrap(type, name, raw, ::Kebab::Convert.parse(type, raw))
    end

    private def __kebab_convert(type : T.class, name : String, raw : String, converter) : T forall T
      __kebab_unwrap(type, name, raw, converter.parse(raw))
    end

    private def __kebab_unwrap(type : T.class, name : String, raw : String, result : T | ::Kebab::Convert::Failure) : T forall T
      case result
      in T
        result
      in ::Kebab::Convert::Failure
        __kebab_bail(::Kebab::Error::InvalidValueOf(T).from(result, value: raw, option: name))
      end
    end
  end
end
