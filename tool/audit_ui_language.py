from pathlib import Path
import re

ROOT = Path('lib')
TARGETS = [ROOT / 'screens', ROOT / 'widgets']
AR = re.compile(r'[\u0600-\u06FF]')
STRING = re.compile(r"(['\"])(.*?)(?<!\\)\1", re.S)
NON_TEXT_PROPS = re.compile(r'(tooltip|labelText|hintText|helperText|errorText|semanticLabel|message)\s*:\s*([\'\"])(.*?)(?<!\\)\2', re.S)

rows = []
for root in TARGETS:
    if not root.exists():
        continue
    for path in sorted(root.rglob('*.dart')):
        text = path.read_text(encoding='utf-8')
        arabic_literals = [m.group(2) for m in STRING.finditer(text) if AR.search(m.group(2))]
        if not arabic_literals:
            continue
        localized_text = 'widgets/localized_text.dart' in text or "localized_text.dart" in text
        hide_text = 'hide Text' in text
        risky_props = [
            (m.group(1), m.group(3).strip())
            for m in NON_TEXT_PROPS.finditer(text)
            if AR.search(m.group(3)) and 'context.tr(' not in m.group(0)
        ]
        dynamic_arabic = []
        for literal in arabic_literals:
            clean = ' '.join(literal.split())
            if '$' in literal:
                dynamic_arabic.append(clean)
        if "join(' و ')" in text:
            dynamic_arabic.append("join(' و ')")
        if '_arabicMonths[' in text or '_weekdays[' in text:
            dynamic_arabic.append('Arabic date/month array used at runtime')

        is_screen = '/screens/' in f'/{path.as_posix()}'
        legacy = (
            is_screen
            and 'Scaffold(' in text
            and 'NeoWorkspace' not in text
            and 'neo_workspace_chrome.dart' not in text
        )
        basic_list = legacy and ('ListView.builder' in text or 'ListTile(' in text) and 'AppTextStyles' not in text
        basic_empty = legacy and 'Center(' in text and ('لا توجد' in text or 'حتى الآن' in text)
        score = 0
        issues = []
        if not localized_text or not hide_text:
            score += 5
            issues.append('Arabic UI literals may bypass LocalizedText')
        if risky_props:
            score += min(8, len(risky_props) * 2)
            issues.append(f'{len(risky_props)} untranslated non-Text properties')
        if dynamic_arabic:
            score += min(10, len(dynamic_arabic) * 2)
            issues.append(f'{len(dynamic_arabic)} runtime-composed Arabic strings need review')
        if basic_list:
            score += 3
            issues.append('legacy ListView/ListTile presentation')
        if basic_empty:
            score += 2
            issues.append('legacy empty state')
        if legacy and len(text) < 12000:
            score += 1
            issues.append('small legacy screen shell')
        if score:
            examples = [f'{k}: {v[:48]}' for k, v in risky_props[:2]]
            examples += [f'runtime: {v[:56]}' for v in dynamic_arabic[:2]]
            rows.append((score, path.as_posix(), ', '.join(issues), '; '.join(examples)))

rows.sort(key=lambda item: (-item[0], item[1]))
lines = [
    '# NeoTask UI + Language Audit',
    '',
    'Automated static audit of `lib/screens` and `lib/widgets`, including runtime-composed Arabic strings that can leak into English mode.',
    '',
    '| Score | File | Issues | Risk examples |',
    '|---:|---|---|---|',
]
for score, path, issues, examples in rows:
    lines.append(f'| {score} | `{path}` | {issues} | {examples.replace("|", "/")} |')

lines += ['', f'Flagged files: **{len(rows)}**', '']
Path('ui-language-audit.md').write_text('\n'.join(lines), encoding='utf-8')
print('\n'.join(lines[:40]))
