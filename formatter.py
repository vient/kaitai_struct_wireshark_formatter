#!/usr/bin/env python3
import os
import re
import sys

SCRIPT_DIR              = os.path.dirname(__file__)
TEMPLATES_DIR           = os.path.join(SCRIPT_DIR, 'templates')
PLACEHOLDER_FORMAT      = r'<<PLACEHOLDER:{}>>'     # << and >> are invalid in Lua 5.2
PARAMETER_REGEX         = r'[a-z_][a-z0-9_]*'
PLACEHOLDER_REGEX       = PLACEHOLDER_FORMAT.format(fr'(?P<name>{PARAMETER_REGEX})')
CODE_PLACEHOLDER_NAME   = '_generated_parser_code'


def die(reason):
    print(reason, file=sys.stderr)
    exit(1)


def parse_optional_arguments(args):
    res = {}
    if len(args) % 2 != 0:
        die('Optional parameter list length should be divisible by 2')
    for i in range(0, len(args), 2):
        key, value = args[i:i + 2]
        if not key.startswith('-'):
            die(f'Optional parameter name should start with `-` ({key}, {value})')
        key = key[1:]
        if not re.fullmatch(PARAMETER_REGEX, key):
            die(f'Key name {key} is not conforming to parameter format {PARAMETER_REGEX}')
        res[key] = value
    return res


def get_template_parameters(template):
    return set(match.group('name') for match in re.finditer(PLACEHOLDER_REGEX, template))


def fill_template(template, provided_parameters):
    template_parameters = get_template_parameters(template)
    missing_parameters = template_parameters - set(provided_parameters.keys())
    if missing_parameters:
        die(f'Missing template parameters {missing_parameters}, provide them in optional section')

    for parameter in template_parameters:
        placeholder = PLACEHOLDER_FORMAT.format(parameter)
        template = template.replace(placeholder, provided_parameters[parameter])

    return template


def main():
    argv = sys.argv
    if len(argv) < 3:
        die(f'Usage: {argv[0]} template-name path-to-generated-dissector [optional template parameters, -param_name param_value]')
    template_name = argv[1]
    template_file = template_name + '.lua'
    dissector_path = argv[2]
    optional_arguments = parse_optional_arguments(argv[3:])

    # fail soundly
    generated_code = open(dissector_path).read()
    optional_arguments[CODE_PLACEHOLDER_NAME] = generated_code

    available_templates = os.listdir(TEMPLATES_DIR)
    if template_file not in available_templates:
        die(f'Template {template_name} not found (searched for {template_file})')

    template = open(os.path.join(TEMPLATES_DIR, template_file)).read()
    filled_template = fill_template(template, optional_arguments)

    # print(generated_code)
    # print('\n')
    print(filled_template)


if __name__ == '__main__':
    main()
