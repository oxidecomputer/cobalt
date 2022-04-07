# Some template engine filters
import inflection


def to_camel_case(template_string, uppercamel=False):
    return inflection.camelize(template_string, uppercase_first_letter=uppercamel)


def to_snake_case(template_string):
    return inflection.underscore(template_string)