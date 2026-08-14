from pathlib import Path
import re

path = Path('lib/l10n/app_i18n.dart')
text = path.read_text(encoding='utf-8')
lines = text.splitlines(keepends=True)

start = next(i for i, line in enumerate(lines) if 'static const Map<String, String> _en = {' in line)
end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith('  };'))

key_re = re.compile(r"^\s*'((?:\\'|[^'])+)'\s*:")
seen = set()
out = []
removed = []

for i, line in enumerate(lines):
    if start < i < end:
        match = key_re.match(line)
        if match:
            key = match.group(1)
            if key in seen:
                removed.append(key)
                continue
            seen.add(key)
    out.append(line)

path.write_text(''.join(out), encoding='utf-8')
print(f'deduplicated {len(removed)} translation key(s)')
for key in removed:
    print(f'  - {key}')
