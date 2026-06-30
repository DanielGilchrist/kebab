module Kebab
  module Parseable
    macro __kebab_validate_schema
      {%
        allowed_option_keys = ["short", "long", "description", "converter", "global"]
        allowed_argument_keys = ["name", "description", "converter"]
        allowed_subcommand_keys = ["required"]
        allowed_command_keys = ["name", "summary"]

        seen_options = [] of Nil
        seen_arguments = [] of Nil
        seen_subcommands = [] of Nil

        ivar_names = [] of Nil
        @type.instance_vars.each { |ivar| ivar_names << ivar.name.stringify }

        @type.methods.each do |method|
          kebab_annotation = method.annotation(::Kebab::Option) ||
                             method.annotation(::Kebab::Argument) ||
                             method.annotation(::Kebab::Subcommand)
          if kebab_annotation
            method_name = method.name.stringify
            expected_ivar = method_name.ends_with?("?") ? method_name[0...(method_name.size - 1)] : method_name
            unless ivar_names.includes?(expected_ivar)
              raise "Field '#{method.name}' on #{@type} needs an explicit type. " \
                    "Declare it as `getter #{expected_ivar.id} : SomeType` (required) or " \
                    "`getter #{expected_ivar.id} : SomeType?` (optional)."
            end
          end
        end

        @type.instance_vars.each do |ivar|
          applied = [] of String
          applied << "@[Kebab::Subcommand]" if ivar.annotation(::Kebab::Subcommand)
          applied << "@[Kebab::Argument]" if ivar.annotation(::Kebab::Argument)
          applied << "@[Kebab::Option]" if ivar.annotation(::Kebab::Option)
          if applied.size > 1
            raise "Field '#{ivar.name}' on #{@type} has more than one kebab annotation: #{applied.join(", ").id}. " \
                  "Each field can only be one of an option, an argument, or a subcommand."
          end

          if subcommand = ivar.annotation(::Kebab::Subcommand)
            subcommand.named_args.keys.each do |key|
              unless allowed_subcommand_keys.includes?(key.stringify)
                raise "@[Kebab::Subcommand] on '#{ivar.name}' has unknown key `#{key.id}`. Valid keys: #{allowed_subcommand_keys.join(", ").id}."
              end
            end
            if (required = subcommand[:required]) && !required.is_a?(BoolLiteral)
              raise "@[Kebab::Subcommand(required:)] on '#{ivar.name}' must be true or false, got `#{required}`."
            end
            if ivar.has_default_value?
              raise "@[Kebab::Subcommand] field '#{ivar.name}' has a default value. Defaults aren't used here. Pass `required: true` or `required: false` instead."
            end
            if ivar.type.nilable?
              raise "@[Kebab::Subcommand] field '#{ivar.name}' on #{@type} can't be nilable. Use `required: true` or `required: false` on the annotation."
            end
            seen_subcommands << ivar
          elsif argument = ivar.annotation(::Kebab::Argument)
            argument.named_args.keys.each do |key|
              unless allowed_argument_keys.includes?(key.stringify)
                raise "@[Kebab::Argument] on '#{ivar.name}' has unknown key `#{key.id}`. Valid keys: #{allowed_argument_keys.join(", ").id}."
              end
            end
            if (name_value = argument[:name]) && !(name_value.is_a?(StringLiteral) || name_value.is_a?(StringInterpolation))
              raise "@[Kebab::Argument(name:)] on '#{ivar.name}' must be a String, got `#{name_value}`."
            end
            if (description = argument[:description]) && !(description.is_a?(StringLiteral) || description.is_a?(StringInterpolation))
              raise "@[Kebab::Argument(description:)] on '#{ivar.name}' must be a String, got `#{description}`."
            end
            if (converter = argument[:converter]) && !(converter.is_a?(Path) || converter.is_a?(Generic) || converter.is_a?(TypeNode))
              raise "@[Kebab::Argument(converter:)] on '#{ivar.name}' must be a type name like `MyConverter`, got `#{converter}`."
            end
            base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
            if base == Bool
              raise "@[Kebab::Argument] '#{ivar.name}' has type Bool. Bool fields can't be positional. Use @[Kebab::Option] for flags."
            end
            if base.name(generic_args: false).stringify == "Array" && ivar.type.nilable?
              raise "Variadic argument '#{ivar.name}' on #{@type} can't be nilable. Use `Array(T)` (and default to `[] of T` for optional)."
            end
            seen_arguments << ivar
          elsif option = ivar.annotation(::Kebab::Option)
            option.named_args.keys.each do |key|
              unless allowed_option_keys.includes?(key.stringify)
                raise "@[Kebab::Option] on '#{ivar.name}' has unknown key `#{key.id}`. Valid keys: #{allowed_option_keys.join(", ").id}."
              end
            end
            if (short = option[:short]) && !short.is_a?(CharLiteral)
              raise "@[Kebab::Option(short:)] on '#{ivar.name}' must be a Char like 'a' (single quotes), got `#{short}`."
            end
            if (long = option[:long]) && !(long.is_a?(StringLiteral) || long.is_a?(StringInterpolation))
              raise "@[Kebab::Option(long:)] on '#{ivar.name}' must be a String, got `#{long}`."
            end
            if (description = option[:description]) && !(description.is_a?(StringLiteral) || description.is_a?(StringInterpolation))
              raise "@[Kebab::Option(description:)] on '#{ivar.name}' must be a String, got `#{description}`."
            end
            if (converter = option[:converter]) && !(converter.is_a?(Path) || converter.is_a?(Generic) || converter.is_a?(TypeNode))
              raise "@[Kebab::Option(converter:)] on '#{ivar.name}' must be a type name like `MyConverter`, got `#{converter}`."
            end
            if (global = option[:global]) && !global.is_a?(BoolLiteral)
              raise "@[Kebab::Option(global:)] on '#{ivar.name}' must be true or false, got `#{global}`."
            end
            bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
            if bases.size != 1
              raise "Field '#{ivar.name}' on #{@type} has an unsupported type: `#{ivar.type}`. " \
                    "A field's type must be a single type, optionally nilable (like `String?` or `Int32 = 0`). " \
                    "For dispatching across multiple command types, use @[Kebab::Subcommand]."
            end
            if bases.first == Bool && ivar.type.nilable?
              raise "Flag '#{ivar.name}' on #{@type} can't be nilable. Use `Bool = false`."
            end
            seen_options << ivar
          end
        end

        if command = @type.annotation(::Kebab::Command)
          command.named_args.keys.each do |key|
            unless allowed_command_keys.includes?(key.stringify)
              raise "@[Kebab::Command] on #{@type} has unknown key `#{key.id}`. Valid keys: #{allowed_command_keys.join(", ").id}."
            end
          end
          if (name_value = command[:name]) && !(name_value.is_a?(StringLiteral) || name_value.is_a?(StringInterpolation))
            raise "@[Kebab::Command(name:)] on #{@type} must be a String, got `#{name_value}`."
          end
          if (summary = command[:summary]) && !(summary.is_a?(StringLiteral) || summary.is_a?(StringInterpolation))
            raise "@[Kebab::Command(summary:)] on #{@type} must be a String, got `#{summary}`."
          end
        end

        if seen_subcommands.size > 1
          raise "#{@type} has #{seen_subcommands.size} @[Kebab::Subcommand] fields. Only one is allowed."
        end

        if !seen_subcommands.empty? && !seen_arguments.empty?
          raise "#{@type} has both positional arguments and a subcommand field. A command can have one or the other, not both. " \
                "Move the positionals onto each leaf subcommand if they belong there."
        end

        long_names = {} of String => String
        seen_options.each do |ivar|
          option = ivar.annotation(::Kebab::Option)
          long = (option && option[:long]) || ivar.name.stringify.gsub(/_/, "-")
          if existing = long_names[long]
            raise "Duplicate long option --#{long.id} on #{@type}: '#{existing.id}' and '#{ivar.name}' both use it."
          end
          long_names[long] = ivar.name.stringify
        end

        short_letters = {} of Char => String
        seen_options.each do |ivar|
          option = ivar.annotation(::Kebab::Option)
          short = option && option[:short]
          if short
            if existing = short_letters[short]
              raise "Duplicate short option -#{short.id} on #{@type}: '#{existing.id}' and '#{ivar.name}' both use it."
            end
            short_letters[short] = ivar.name.stringify
          end
        end

        argument_names = {} of String => String
        seen_arguments.each do |ivar|
          argument = ivar.annotation(::Kebab::Argument)
          name = (argument && argument[:name]) || ivar.name.stringify.gsub(/_/, "-")
          if existing = argument_names[name]
            raise "Duplicate argument <#{name.id}> on #{@type}: '#{existing.id}' and '#{ivar.name}' both use it."
          end
          argument_names[name] = ivar.name.stringify
        end

        variadic_arguments = [] of Nil
        seen_arguments.each do |ivar|
          base = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil }.first : ivar.type
          variadic_arguments << ivar if base.name(generic_args: false).stringify == "Array"
        end
        if variadic_arguments.size > 1
          raise "#{@type} has #{variadic_arguments.size} variadic Array(T) arguments. Only one is allowed."
        end
        if variadic_arguments.size == 1 && variadic_arguments.first != seen_arguments.last
          raise "Variadic Array(T) argument '#{variadic_arguments.first.name}' on #{@type} must be the last positional argument."
        end

        seen_optional_argument = false
        seen_arguments.each do |ivar|
          optional = ivar.type.nilable? || ivar.has_default_value?
          if seen_optional_argument && !optional
            raise "Argument '#{ivar.name}' on #{@type} is required but comes after an optional argument. Required positionals have to come first."
          end
          seen_optional_argument ||= optional
        end

        subcommand_ivar = seen_subcommands.first
        if subcommand_ivar
          subcommand_members = subcommand_ivar.type.union? ? subcommand_ivar.type.union_types : [subcommand_ivar.type]
          subcommand_members.each do |member|
            unless member.resolve.ancestors.includes?(::Kebab::Parseable)
              raise "@[Kebab::Subcommand] field '#{subcommand_ivar.name}' on #{@type} includes #{member}, which isn't a command. " \
                    "Every type in a subcommand union must `include Kebab::Parseable`."
            end
          end
          subcommand_names = subcommand_members.map do |member|
            (member.annotation(::Kebab::Command) && member.annotation(::Kebab::Command)[:name]) || member.name.stringify.split("::").last.underscore
          end

          seen_subcommand_names = {} of String => String
          subcommand_members.each_with_index do |member, idx|
            name = subcommand_names[idx]
            if existing = seen_subcommand_names[name]
              raise "Duplicate subcommand `#{name.id}` on #{@type}: #{existing.id} and #{member.id} both resolve to it."
            end
            seen_subcommand_names[name] = member.name.stringify
          end
        end

        global_clash_names = [] of String
        seen_options.each do |ivar|
          option = ivar.annotation(::Kebab::Option)
          if option && option[:global]
            global_clash_names << "--#{(option[:long] || ivar.name.stringify.gsub(/_/, "-")).id}"
            global_clash_names << "-#{option[:short].id}" if option[:short]
          end
        end
      %}

      {% unless global_clash_names.empty? %}
        __kebab_assert_no_global_clash({{@type}}, {{global_clash_names}})
      {% end %}
    end

    # Walks `type`'s subcommand subtree and fails compilation if a descendant
    # command reuses a `global: true` option's long name or short letter. The
    # declaring command swallows it everywhere in its subtree, so the descendant
    # could never receive its own copy.
    macro __kebab_assert_no_global_clash(type, names)
      {% for ivar in type.resolve.instance_vars %}
        {% if ivar.annotation(::Kebab::Subcommand) %}
          {% members = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type] %}
          {% for member in members %}
            {% for member_ivar in member.resolve.instance_vars %}
              {% if option = member_ivar.annotation(::Kebab::Option) %}
                {% member_long = "--#{(option[:long] || member_ivar.name.stringify.gsub(/_/, "-")).id}" %}
                {% if names.includes?(member_long) %}
                  {% raise "Global option #{member_long.id} (declared on an ancestor command) is redeclared by '#{member_ivar.name}' on #{member}. " \
                           "A global option is recognised throughout its declaring command's subtree, so a descendant can't reuse its name." %}
                {% end %}
                {% if option[:short] %}
                  {% member_short = "-#{option[:short].id}" %}
                  {% if names.includes?(member_short) %}
                    {% raise "Global option #{member_short.id} (declared on an ancestor command) is redeclared by '#{member_ivar.name}' on #{member}. " \
                             "A global option is recognised throughout its declaring command's subtree, so a descendant can't reuse its short letter." %}
                  {% end %}
                {% end %}
              {% end %}
            {% end %}
            __kebab_assert_no_global_clash({{member}}, {{names}})
          {% end %}
        {% end %}
      {% end %}
    end
  end
end
