#!/usr/bin/env python3
"""Check static L() templates, including interpolation, against bundled translations."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent.parent


def swift_string(text, index):
    result, index = '', index + 1
    while index < len(text):
        char = text[index]
        if char == '"':
            return result, index + 1
        if char == '\\':
            if text[index + 1] == '(':
                depth, index = 1, index + 2
                while depth:
                    if text[index] == '"':
                        _, index = swift_string(text, index)
                        continue
                    if text[index] == '(':
                        depth += 1
                    if text[index] == ')':
                        depth -= 1
                    index += 1
                result += '%@'
                continue
            result += {'n': '\n', 't': '\t', 'r': '\r'}.get(text[index + 1], text[index + 1])
            index += 2
            continue
        result += char
        index += 1
    raise ValueError('Unterminated Swift string')


base_file = ROOT / 'Sources/MacSenseCore/Resources/ru.lproj/Localizable.strings'
keys = {json.loads('"' + key + '"') for key in re.findall(r'^"((?:\\.|[^"\\])*)"\s*=', base_file.read_text(), re.M)}
missing = set()
for path in (ROOT / 'Sources').rglob('*.swift'):
    text = path.read_text()
    for match in re.finditer(r'\bL\("', text):
        key, _ = swift_string(text, match.end() - 1)
        if key not in keys:
            missing.add((str(path.relative_to(ROOT)), key))
for path, key in sorted(missing):
    print(f'{path}: missing translation template: {key!r}')
if missing:
    raise SystemExit(1)
print(f'All static L() templates exist; {len(keys)} bundled keys. swift test validates all five languages.')
