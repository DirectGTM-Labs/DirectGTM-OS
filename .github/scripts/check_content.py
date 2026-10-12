"""Check content changes; report existing scaffolding without claiming it works.

This checks syntax and local file links, not source accuracy, schema semantics,
the quality of a growth method, or whether a Python application is implemented.
"""

import argparse
import ast
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tomllib
from urllib.parse import unquote, urlsplit

import yaml


TEXT_SUFFIXES = {'.md', '.json', '.yaml', '.yml', '.toml', '.py', '.sql', '.j2', '.psv'}
INLINE_LINK = re.compile(r'!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|[^\s)]+)(?:\s+[\"\'][^\n]*?[\"\'])?\s*\)')


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def inspect_file(root, name):
    path = root / name
    issues = []
    if any(part != part.strip() for part in Path(name).parts):
        issues.append('file or directory name has leading/trailing whitespace')
    if path.suffix.lower() not in TEXT_SUFFIXES:
        return issues
    try:
        text = path.read_text(encoding='utf-8')
        if not text.strip():
            if path.name != '__init__.py':
                issues.append('empty placeholder; not a completed implementation')
            return issues
        if path.suffix == '.json':
            json.loads(text)
        elif path.suffix in {'.yaml', '.yml'}:
            yaml.safe_load(text)
        elif path.suffix == '.toml':
            tomllib.loads(text)
        elif path.suffix == '.py':
            ast.parse(text, filename=name)
        elif path.suffix == '.md':
            # Avoid links in fenced examples. Check inline local file links only;
            # external URLs, reference-style links and section anchors are not checked.
            in_fence = False
            fence_mark = None
            prose = []
            for line in text.splitlines():
                match = re.match(r'^\s*(`{3,}|~{3,})', line)
                if match:
                    mark = match.group(1)[0]
                    if not in_fence:
                        in_fence, fence_mark = True, mark
                    elif mark == fence_mark:
                        in_fence, fence_mark = False, None
                    continue
                if not in_fence:
                    prose.append(line)
            for match in INLINE_LINK.finditer('\n'.join(prose)):
                target = match.group(1).strip('<>')
                parts = urlsplit(target)
                if parts.scheme or parts.netloc or not parts.path:
                    continue
                # Root-relative links on GitHub can be site routes, not repo files.
                if parts.path.startswith('/'):
                    continue
                destination = path.parent / unquote(parts.path)
                if not destination.exists():
                    issues.append('missing local link target: ' + target)
    except (UnicodeError, ValueError, SyntaxError, yaml.YAMLError) as exc:
        issues.append(str(exc))
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='.')
    parser.add_argument('--base', default=os.environ.get('BASE_SHA', ''))
    parser.add_argument('--org-profile', action='store_true')
    args = parser.parse_args()
    root = Path(args.root).resolve()
    tracked = git(root, 'ls-files', '-z').decode().split('\0')[:-1]
    tracked = [name for name in tracked if (root / name).is_file()]

    required = ['README.md']
    is_profile = args.org_profile or os.environ.get('GITHUB_REPOSITORY', '').endswith('/.github')
    if is_profile:
        required.append('profile/README.md')
    failures = []
    for name in required:
        path = root / name
        if not path.is_file() or not path.read_text(encoding='utf-8').strip():
            failures.append(name + ': required published entry point is missing or empty')
        elif not re.search(r'^#\s+\S', path.read_text(encoding='utf-8'), re.MULTILINE):
            failures.append(name + ': add a top-level Markdown title')

    base = args.base.strip()
    if base and set(base) != {'0'}:
        if not re.fullmatch(r'[0-9a-fA-F]{40,64}', base):
            raise SystemExit('BASE_SHA must be a commit hash')
        changed = set(git(root, 'diff', '--diff-filter=ACMR', '--name-only', '-z', base, 'HEAD').decode().split('\0'))
        changed.discard('')
    else:
        changed = set()
        print('Baseline/manual run: report existing scaffolding; required README entry points remain enforced.')

    backlog = []
    for name in tracked:
        issues = inspect_file(root, name)
        if issues:
            entries = [name + ': ' + issue for issue in issues]
            for issue, entry in zip(issues, entries):
                # Planned scaffold files can remain empty or be moved. Only
                # published README entry points must be nonempty at this stage.
                if issue.startswith('empty placeholder') and name not in required:
                    backlog.append(entry)
                elif name in changed or name in required:
                    failures.append(entry)
                else:
                    backlog.append(entry)
    if backlog:
        print(f'Existing content backlog: {len(backlog)} issue(s). These are not functional-test passes.')
        for item in backlog[:12]:
            print('BACKLOG: ' + item)
        if len(backlog) > 12:
            print(f'... {len(backlog) - 12} more issue(s); run the script after each content update.')
    if failures:
        for item in failures:
            print('FAIL: ' + item, file=sys.stderr)
        return 1
    print(f'Content checks passed: {len(changed)} changed path(s); published entry points verified.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
