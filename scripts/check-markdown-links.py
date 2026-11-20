#!/usr/bin/env python3
"""Check local relative Markdown links and image paths."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r'!?\[[^\]]*\]\(([^)]+)\)')
errors = []
for markdown in sorted(ROOT.rglob('*.md')):
    if '.git' in markdown.parts:
        continue
    text = markdown.read_text(encoding='utf-8')
    for raw in LINK.findall(text):
        target = raw.strip().split(maxsplit=1)[0].strip('<>')
        if not target or target.startswith(('http://', 'https://', 'mailto:', '#', 'tel:')):
            continue
        path_part = target.split('#', 1)[0].split('?', 1)[0]
        if not path_part:
            continue
        candidate = (markdown.parent / path_part).resolve()
        try:
            candidate.relative_to(ROOT.resolve())
        except ValueError:
            errors.append(f'{markdown.relative_to(ROOT)}: link escapes repository: {target}')
            continue
        if not candidate.exists():
            errors.append(f'{markdown.relative_to(ROOT)}: missing local target: {target}')

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('All local Markdown links resolve.')
