#!/usr/bin/env python3
"""Inventory Swift display literals; only explicitly translated keys are rewritten."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def quoted(text, start):
    triple = text.startswith('"""', start)
    mark = '"""' if triple else '"'
    cursor = start + len(mark)
    literal, parts, expressions = '', [], []
    while cursor < len(text):
        if text.startswith(mark, cursor):
            parts.append(literal)
            parts = [re.sub(r'\\u\{([0-9A-Fa-f]+)\}', lambda m: chr(int(m[1], 16)), part) for part in parts]
            key = ''.join(part + ('{' + str(i) + '}' if i < len(expressions) else '')
                          for i, part in enumerate(parts))
            return cursor + len(mark), key, expressions
        if text.startswith('\\(', cursor):
            parts.append(literal)
            literal = ''
            end, depth = cursor + 2, 1
            while end < len(text) and depth:
                if text[end] == '"':
                    end = quoted(text, end)[0]
                    continue
                if text[end] == '(':
                    depth += 1
                elif text[end] == ')':
                    depth -= 1
                end += 1
            expressions.append(text[cursor + 2:end - 1])
            cursor = end
        elif text[cursor] == '\\' and cursor + 1 < len(text):
            escaped = text[cursor:cursor + 2]
            literal += {'\\n': '\n', '\\t': '\t', '\\r': '\r', '\\"': '"', '\\\\': '\\'}.get(escaped, escaped)
            cursor += 2
        else:
            literal += text[cursor]
            cursor += 1
    raise ValueError(f'Unclosed string at {start}')


def strings(text):
    cursor = 0
    while cursor < len(text):
        if text.startswith('//', cursor):
            cursor = text.find('\n', cursor) if '\n' in text[cursor:] else len(text)
        elif text.startswith('/*', cursor):
            depth = 1
            cursor += 2
            while cursor < len(text) and depth:
                if text.startswith('/*', cursor):
                    depth += 1
                    cursor += 2
                elif text.startswith('*/', cursor):
                    depth -= 1
                    cursor += 2
                else:
                    cursor += 1
        elif text[cursor] == '#' and cursor + 1 < len(text) and text[cursor + 1] in '#"':
            match = re.match(r'(#+)"', text[cursor:])
            if match:
                closing = '"' + match[1]
                cursor = text.index(closing, cursor + len(match[0])) + len(closing)
            else:
                cursor += 1
        elif text[cursor] == '"':
            end, key, expressions = quoted(text, cursor)
            yield cursor, end, key, expressions
            cursor = end
        else:
            cursor += 1


def human(key):
    return bool(re.search(r'[A-Za-z]', key) and (
        ' ' in key or re.fullmatch(r'[A-Z][A-Za-z&…]+', key)
    )) and not any(term in key for term in ['#!/', 'import ', 'SELECT ', 'CREATE TABLE', 'INSERT ', 'osascript', '<!DOCTYPE'])


def inventory():
    records = {}
    paths = sorted((ROOT / 'Sources/WispApp').rglob('*.swift'))
    paths += sorted((ROOT / 'Sources/WispCore/Diagnosis').rglob('*.swift'))
    paths += [p for p in sorted((ROOT / 'Sources/WispCore').rglob('*.swift'))
              if '/Diagnosis/' not in str(p) and p.name != 'Localization.swift']
    for path in paths:
        text = path.read_text()
        for start, end, key, expressions in strings(text):
            if not human(key):
                continue
            prefix = text[text.rfind('\n', 0, start) + 1:start]
            suffix = text[end:text.find('\n', end) if '\n' in text[end:] else len(text)]
            records.setdefault(key, []).append({
                'path': str(path.relative_to(ROOT)), 'line': text.count('\n', 0, start) + 1,
                'context': (prefix + '"…"' + suffix).strip()[:200],
            })
    return records


def localized_keys(text):
    keys = set()
    for start, end, key, expressions in strings(text):
        if re.search(r"\bL\(\s*$", text[:start]):
            keys.add(key)
        for expression in expressions:
            keys.update(localized_keys(expression))
    return keys


def read_catalog(language):
    path = ROOT / f'Sources/WispCore/Resources/{language}.lproj/Localizable.strings'
    pairs = re.findall(r'^("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");$', path.read_text(), re.M)
    return {json.loads(key): json.loads(value) for key, value in pairs}


def check():
    en, zh = read_catalog('en'), read_catalog('zh-Hans')
    errors = []
    if en.keys() != zh.keys():
        errors.append('English and Chinese catalog keys differ')
    token = re.compile(r'\{\d+\}|%(?:[0-9.$+-]*)(?:@|[a-zA-Z])')
    for key in en.keys() & zh.keys():
        if sorted(token.findall(en[key])) != sorted(token.findall(zh[key])):
            errors.append(f'Placeholder mismatch: {key}')
        if not zh[key].strip():
            errors.append(f'Empty Chinese translation: {key}')
    used = set()
    for path in (ROOT / 'Sources').rglob('*.swift'):
        used.update(localized_keys(path.read_text()))
    errors.extend('Missing resource: ' + key for key in sorted(used - en.keys()))
    print(f'{len(en)} catalog entries; {len(used)} source templates; {len(errors)} errors')
    for error in errors[:50]:
        print(error)
    return bool(errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate resource coverage and placeholder parity')
    args = parser.parse_args()
    if args.check:
        raise SystemExit(check())
    data = inventory()
    output = ROOT / 'build/localization-inventory.json'
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(data)} candidate display keys; inventory: {output}')
