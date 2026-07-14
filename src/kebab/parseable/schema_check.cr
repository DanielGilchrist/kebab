module Kebab
  module Parseable
    macro __kebab_validate_schema
      {%
        allowed_option_keys = ["short", "long", "description", "converter", "global", "arity", "value_names", "count"]
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
            argument_bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
            if argument_bases.size != 1
              raise "Field '#{ivar.name}' on #{@type} has an unsupported type: `#{ivar.type}`. " \
                    "A field's type must be a single type, optionally nilable (like `String?` or `Int32 = 0`). " \
                    "For dispatching across multiple command types, use @[Kebab::Subcommand]."
            end
            base = argument_bases.first
            element = base.name(generic_args: false).stringify == "Array" ? base.type_vars.first : base
            element_types = element <= ::Tuple ? element.type_vars : [element]
            if element_types.any? { |element_type| element_type == Bool }
              raise "@[Kebab::Argument] '#{ivar.name}' has a Bool value type. Bool fields can't be positional. Use @[Kebab::Option] for flags."
            end
            if element <= ::Tuple && element.type_vars.size < 2
              raise "@[Kebab::Argument] '#{ivar.name}' has type `#{element}`. A one-value tuple is a plain value. Use `#{element.type_vars.first}` directly."
            end
            if element_types.any? { |element_type| element_type <= ::Tuple || element_type.name(generic_args: false).stringify == "Array" }
              raise "Field '#{ivar.name}' on #{@type} has type `#{base}`. Value types must be simple. Nested tuples and arrays can't parse from the command line."
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
            if (count = option[:count]) && !count.is_a?(BoolLiteral)
              raise "@[Kebab::Option(count:)] on '#{ivar.name}' must be true or false, got `#{count}`."
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
            if bases.first == Bool && option[:converter]
              raise "@[Kebab::Option] '#{ivar.name}' is a Bool flag and never converts a value. Remove the `converter:`."
            end
            option_base = bases.first
            option_array = option_base.name(generic_args: false).stringify == "Array"
            option_occurrence = option_array ? option_base.type_vars.first : option_base
            option_tuple = option_occurrence <= ::Tuple
            option_value_types = option_tuple ? option_occurrence.type_vars : [option_occurrence]
            if !!option[:count]
              if ivar.type.nilable?
                raise "Counted flag '#{ivar.name}' on #{@type} can't be nilable. Use `Int32 = 0`."
              end
              if option_base == Bool
                raise "@[Kebab::Option(count:)] on '#{ivar.name}': a Bool flag is already a flag. Counting needs a number. Use `Int32 = 0`."
              end
              unless option_base < ::Int
                raise "@[Kebab::Option(count:)] on '#{ivar.name}': a counted flag must be an integer type like `Int32` or `UInt8`. Use `Int32 = 0`."
              end
              if option[:converter]
                raise "@[Kebab::Option(count:)] on '#{ivar.name}': a counted flag takes no value to convert. Remove the `converter:`."
              end
              if option[:arity]
                raise "@[Kebab::Option(count:)] on '#{ivar.name}': a counted flag takes no values. Remove the `arity:`."
              end
              if option[:value_names]
                raise "@[Kebab::Option(count:)] on '#{ivar.name}': a counted flag takes no values. Remove the `value_names:`."
              end
            end
            if option_base != Bool && option_value_types.any? { |value_type| value_type == Bool }
              raise "@[Kebab::Option] '#{ivar.name}' has type `#{option_base}`. A flag can't take a value, so it can't be one of several. Use a plain `Bool`, or `Int32` with `count: true` for `-vvv` counting."
            end
            if option_tuple && option_occurrence.type_vars.size < 2
              raise "@[Kebab::Option] '#{ivar.name}' has type `#{option_occurrence}`. A one-value tuple is a plain value. Use `#{option_occurrence.type_vars.first}` directly."
            end
            if option_value_types.any? { |value_type| value_type <= ::Tuple || value_type.name(generic_args: false).stringify == "Array" }
              raise "Field '#{ivar.name}' on #{@type} has type `#{option_base}`. Value types must be simple. Nested tuples and arrays can't parse from the command line."
            end
            if arity = option[:arity]
              arity_bounds = arity.is_a?(RangeLiteral) ? [arity.begin, arity.end] : [arity]
              integral = arity_bounds.all? { |bound| bound.is_a?(Nop) || (bound.is_a?(NumberLiteral) && bound.kind != :f32 && bound.kind != :f64) }
              unless (arity.is_a?(NumberLiteral) || arity.is_a?(RangeLiteral)) && integral
                raise "@[Kebab::Option(arity:)] on '#{ivar.name}' must be an Int like `2` or an inclusive Range like `1..` or `2..4`, got `#{arity}`."
              end
              if option_base == Bool
                raise "@[Kebab::Option(arity:)] on '#{ivar.name}': a Bool flag takes no values. Remove the `arity:`."
              end
              if option_tuple
                raise "@[Kebab::Option(arity:)] on '#{ivar.name}': the tuple type `#{option_occurrence}` already fixes the arity at #{option_occurrence.type_vars.size}. Remove the `arity:`."
              end
              unless option_array
                raise "@[Kebab::Option(arity:)] on '#{ivar.name}': `#{option_base}` takes one value. Use `Tuple(...)` for a fixed group of values, or `Array(T)` for a collection."
              end
              if arity.is_a?(RangeLiteral)
                if arity.excludes_end?
                  raise "@[Kebab::Option(arity:)] on '#{ivar.name}' must be an inclusive Range (`#{arity.begin}..#{arity.end}`), got `#{arity}`."
                end
                if arity.begin.is_a?(Nop) || arity.begin < 1
                  raise "@[Kebab::Option(arity:)] on '#{ivar.name}': an occurrence must take at least one value, and `#{arity}` allows zero. Start the range at 1 or more."
                end
                if !arity.end.is_a?(Nop) && arity.end < arity.begin
                  raise "@[Kebab::Option(arity:)] on '#{ivar.name}': `#{arity}` is empty."
                end
                if option[:global]
                  raise "@[Kebab::Option] '#{ivar.name}' is global with a variable arity. A greedy global would swallow subcommands. Use a fixed arity or a repeatable option."
                end
              elsif arity < 1
                raise "@[Kebab::Option(arity:)] on '#{ivar.name}': an occurrence must take at least one value, got `#{arity}`."
              end
            end
            if names = option[:value_names]
              names_literal = (names.is_a?(TupleLiteral) || names.is_a?(ArrayLiteral)) && names.size > 0 && names.all? { |name| name.is_a?(StringLiteral) }
              unless names_literal
                raise "@[Kebab::Option(value_names:)] on '#{ivar.name}' must be a tuple of Strings like `{\"min\", \"max\"}`, got `#{names}`."
              end
              if option_base == Bool
                raise "@[Kebab::Option(value_names:)] on '#{ivar.name}': a Bool flag takes no values. Remove the `value_names:`."
              end
            end
            seen_options << ivar
          end
        end

        option_specs = seen_options.map do |ivar|
          option = ivar.annotation(::Kebab::Option)
          bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
          base = bases.first
          array = base.name(generic_args: false).stringify == "Array"
          occurrence = array ? base.type_vars.first : base
          tuple = occurrence <= ::Tuple
          arity = option && option[:arity]
          counted = !!(option && option[:count])
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
          {
            name:          ivar.name.stringify,
            long:          (option && option[:long]) || ivar.name.stringify.gsub(/_/, "-"),
            short:         option && option[:short],
            converter:     option && option[:converter],
            global:        option && option[:global],
            names:         option && option[:value_names],
            field_type:    base,
            array:         array,
            tuple:         tuple,
            min_values:    min_values,
            max_values:    max_values,
            convert_types: tuple ? occurrence.type_vars : [occurrence],
          }
        end
        argument_specs = seen_arguments.map do |ivar|
          argument = ivar.annotation(::Kebab::Argument)
          bases = ivar.type.union? ? ivar.type.union_types.reject { |union_type| union_type == Nil } : [ivar.type]
          base = bases.first
          variadic = base.name(generic_args: false).stringify == "Array"
          inner = variadic ? base.type_vars.first : base
          tuple = inner <= ::Tuple
          converter = argument && argument[:converter]
          collects = converter && (converter.is_a?(Path) || converter.is_a?(Generic) || converter.is_a?(TypeNode)) &&
                     (converter.resolve.class.methods + converter.resolve.methods).any? { |method| method.name.stringify == "collect" }
          {
            ivar:          ivar,
            name:          ivar.name.stringify,
            arg_name:      (argument && argument[:name]) || ivar.name.stringify.gsub(/_/, "-"),
            converter:     converter,
            variadic:      variadic,
            collects:      collects,
            field_type:    base,
            tuple:         tuple,
            convert_types: tuple ? inner.type_vars : [inner],
          }
        end

        option_specs.each do |spec|
          if names = spec[:names]
            expected = spec[:max_values] != spec[:min_values] ? 1 : spec[:min_values]
            if names.size != expected
              if spec[:max_values] != spec[:min_values]
                raise "@[Kebab::Option(value_names:)] on '#{spec[:name].id}': a variable-arity option gets one name (rendered `<#{names.first}>...`), got #{names.size}."
              else
                raise "@[Kebab::Option(value_names:)] on '#{spec[:name].id}' names #{names.size} values, but --#{spec[:long].id} takes #{expected}."
              end
            end
          end
          if spec[:max_values] != spec[:min_values]
            unless seen_arguments.empty?
              raise "Field '#{spec[:name].id}' on #{@type} has a variable arity, but #{@type} also declares positional arguments. " \
                    "A greedy option would swallow them. Use a fixed arity or a repeatable option."
            end
            unless seen_subcommands.empty?
              raise "Field '#{spec[:name].id}' on #{@type} has a variable arity, but #{@type} dispatches to a subcommand. " \
                    "A greedy option would swallow the subcommand name. Use a fixed arity or a repeatable option."
            end
          end
        end

        # Bool only reaches here as a flag option. Bool positionals were rejected above.
        convertible_numbers = ::Kebab::Convert::NUMBER_SUFFIXES.keys.map(&.resolve)

        (option_specs + argument_specs).each do |spec|
          if converter = spec[:converter]
            if spec[:tuple] && spec[:convert_types].uniq.size != 1
              raise "Field '#{spec[:name].id}' on #{@type}: a converter converts every value the same way, but `#{spec[:field_type]}` mixes types. " \
                    "Drop the `converter:` (each position converts on its own), or make the tuple homogeneous."
            end
            type = spec[:convert_types].first
            # `extend self` puts methods on the instance side, so check both.
            convert_defs = converter.resolve.class.methods + converter.resolve.methods
            collect_method = convert_defs.find { |method| method.name.stringify == "collect" }
            if collect_method && spec[:tuple]
              raise "Field '#{spec[:name].id}' on #{@type}: `collect` folds one value per occurrence, but `#{spec[:field_type]}` groups values into tuples. " \
                    "Use `Array(#{spec[:convert_types].first})`-style fields with `collect`, or drop it."
            end

            element_label = collect_method ? "<element>".id : type
            signature = "`self.convert(input : String) : #{element_label} | Kebab::Convert::Failure`"
            convert_method = convert_defs.find { |method| method.name.stringify == "convert" && method.args.size == 1 }
            unless convert_method
              if convert_defs.any? { |method| method.name.stringify == "convert" }
                raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `convert` must take a single argument. Expected #{signature.id}."
              else
                raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter} needs #{signature.id}."
              end
            end

            # Resolving fails for a generic converter's type var and for a `self` return,
            # so those pass unchecked. The call site's type check enforces the rest.
            convert_return = convert_method.return_type
            element = nil
            unless converter.is_a?(Generic) || convert_return.is_a?(Nop)
              element_parts = (convert_return.is_a?(Union) ? convert_return.types : [convert_return]).reject { |part| !part.is_a?(Self) && part.resolve == ::Kebab::Convert::Failure }
              element = element_parts.first if element_parts.size == 1 && !element_parts.first.is_a?(Self)
            end

            unless converter.is_a?(Generic)
              arg_restriction = convert_method.args.first.restriction
              if !arg_restriction.is_a?(Nop) && arg_restriction.resolve != String
                raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `convert` must take `String`, not `#{arg_restriction}`. Expected #{signature.id}."
              end
            end

            if collect_method
              # Repeatable via `collect`: `convert` parses each occurrence,
              # `collect` folds every converted occurrence into the field.
              collect_signature = "`self.collect(values : Array(#{element || "<element>".id})) : #{spec[:field_type]} | Kebab::Convert::Failure`"
              if collect_method.args.size != 1
                raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `collect` must take a single argument. Expected #{collect_signature.id}."
              end
              unless converter.is_a?(Generic)
                collect_arg = collect_method.args.first.restriction
                unless collect_arg.is_a?(Nop)
                  resolved_arg = collect_arg.resolve
                  arg_is_array = resolved_arg.name(generic_args: false).stringify == "Array"
                  unless arg_is_array && (element.nil? || resolved_arg.type_vars.first == element.resolve)
                    raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `collect` must take the values `convert` produces. Expected #{collect_signature.id}, got `#{collect_arg}`."
                  end
                end
                collect_return = collect_method.return_type
                unless collect_return.is_a?(Nop)
                  collect_parts = collect_return.is_a?(Union) ? collect_return.types : [collect_return]
                  unless collect_parts.all? { |part| part.is_a?(Self) || part.resolve == ::Kebab::Convert::Failure || part.resolve <= spec[:field_type] }
                    raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `collect` must return `#{spec[:field_type]} | Kebab::Convert::Failure`, not `#{collect_return}`."
                  end
                end
              end
            else
              unless converter.is_a?(Generic) || convert_return.is_a?(Nop)
                parts = convert_return.is_a?(Union) ? convert_return.types : [convert_return]
                unless parts.all? { |part| part.is_a?(Self) || part.resolve == ::Kebab::Convert::Failure || part.resolve <= type }
                  # An Array field's converter may also produce several elements
                  # from one value (like splitting on commas).
                  whole = (spec[:array] || spec[:variadic]) && !spec[:tuple] &&
                          parts.all? { |part| part.is_a?(Self) || part.resolve == ::Kebab::Convert::Failure || (part.resolve.name(generic_args: false).stringify == "Array" && part.resolve.type_vars.first <= type) }
                  unless whole
                    if spec[:tuple]
                      raise "Field '#{spec[:name].id}' on #{@type}: `#{spec[:field_type]}` converts each value on its own, " \
                            "so converter #{converter}'s `convert` must return `#{type} | Kebab::Convert::Failure`, not `#{convert_return}`."
                    elsif spec[:array] || spec[:variadic]
                      raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `convert` must return " \
                            "`#{type} | Kebab::Convert::Failure` (one element per value) or `Array(#{type}) | Kebab::Convert::Failure` (several), not `#{convert_return}`."
                    elsif spec[:long]
                      raise "Field '#{spec[:name].id}' on #{@type} has type `#{spec[:field_type]}`, but converter #{converter}'s `convert` returns `#{convert_return}`. " \
                            "Either return `#{spec[:field_type]} | Kebab::Convert::Failure` (one occurrence, parsed whole), or add " \
                            "`self.collect(values : Array(#{element || "<element>".id})) : #{spec[:field_type]} | Kebab::Convert::Failure` to make the option repeatable."
                    else
                      raise "Field '#{spec[:name].id}' on #{@type}: converter #{converter}'s `convert` must return `#{type} | Kebab::Convert::Failure`, not `#{convert_return}`."
                    end
                  end
                end
              end
            end
          elsif bad = spec[:convert_types].find { |value_type| !(value_type == Bool || value_type == String || convertible_numbers.includes?(value_type) || value_type.resolve.ancestors.includes?(::Enum)) }
            if spec[:long] && !spec[:array] && !spec[:tuple]
              raise "Field '#{spec[:name].id}' on #{@type} has type `#{bad}`, which kebab can't convert. " \
                    "Use `Array(T)` for a repeatable option, add a `converter:` (one whose `collect` builds a `#{bad}` makes the option repeatable, see Kebab::Convert), " \
                    "or use a built-in type (String, a number, or an enum)."
            else
              raise "Field '#{spec[:name].id}' on #{@type} has type `#{bad}`, which kebab can't convert. " \
                    "Add a `converter:` (see Kebab::Convert), or use a built-in type (String, a number, or an enum)."
            end
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
        option_specs.each do |spec|
          if existing = long_names[spec[:long]]
            raise "Duplicate long option --#{spec[:long].id} on #{@type}: '#{existing.id}' and '#{spec[:name].id}' both use it."
          end
          long_names[spec[:long]] = spec[:name]
        end

        short_letters = {} of Char => String
        option_specs.each do |spec|
          if short = spec[:short]
            if existing = short_letters[short]
              raise "Duplicate short option -#{short.id} on #{@type}: '#{existing.id}' and '#{spec[:name].id}' both use it."
            end
            short_letters[short] = spec[:name]
          end
        end

        argument_names = {} of String => String
        argument_specs.each do |spec|
          if existing = argument_names[spec[:arg_name]]
            raise "Duplicate argument <#{spec[:arg_name].id}> on #{@type}: '#{existing.id}' and '#{spec[:name].id}' both use it."
          end
          argument_names[spec[:arg_name]] = spec[:name]
        end

        tail_specs = argument_specs.select { |spec| spec[:variadic] || spec[:collects] }
        if tail_specs.size > 1
          raise "#{@type} has #{tail_specs.size} arguments that consume the remaining positionals (variadic `Array(T)` or a converter with `collect`). Only one is allowed."
        end
        if tail_specs.size == 1 && tail_specs.first[:ivar] != seen_arguments.last
          raise "Argument '#{tail_specs.first[:name].id}' on #{@type} consumes the remaining positionals, so it must be the last one."
        end

        seen_optional_argument = false
        argument_specs.each do |spec|
          optional = spec[:ivar].type.nilable? || spec[:ivar].has_default_value?
          if seen_optional_argument && !optional
            raise "Argument '#{spec[:name].id}' on #{@type} is required but comes after an optional argument. Required positionals have to come first."
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
        option_specs.each do |spec|
          if spec[:global]
            global_clash_names << "--#{spec[:long].id}"
            global_clash_names << "-#{spec[:short].id}" if spec[:short]
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
