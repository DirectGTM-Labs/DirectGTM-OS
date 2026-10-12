"""Execute the existing S01 SQL in an isolated PostgreSQL CI service.

Compare its three query outputs with the recorded synthetic-data results.
This proves reproducibility of the submitted SQL, not unaided SQL competence.
"""

import difflib
import os
from pathlib import Path
import subprocess
import sys


def main():
    root = Path('.').resolve()
    candidates = list(root.glob('use-cases/**/s01-opportunity-inventory/run.sql'))
    if len(candidates) != 1:
        raise SystemExit(f'Expected exactly one S01 run.sql, found {len(candidates)}. Update the CI path explicitly if the proof moves.')
    expected = (root / '.github/fixtures/s01.expected.psv').read_text(encoding='utf-8').strip()
    container = os.environ.get('POSTGRES_CONTAINER')
    if not container:
        raise SystemExit('POSTGRES_CONTAINER is required; this check needs an isolated PostgreSQL service.')
    result = subprocess.run(
        [
            'docker', 'exec', '-i', '--env', 'PGOPTIONS=-c timezone=UTC',
            container, 'psql', '--no-psqlrc', '--quiet', '--tuples-only',
            '--no-align', '--field-separator', '|',
            '--username', 'directgtm_ci', '--dbname', 'directgtm_ci',
            '--set', 'ON_ERROR_STOP=1',
        ],
        input=candidates[0].read_text(encoding='utf-8'),
        text=True, capture_output=True, timeout=120,
    )
    if result.returncode:
        print(result.stderr, file=sys.stderr)
        return result.returncode
    actual = result.stdout.strip()
    if actual != expected:
        print('\n'.join(difflib.unified_diff(expected.splitlines(), actual.splitlines(), fromfile='recorded S01 outputs', tofile='current SQL execution', lineterm='')), file=sys.stderr)
        return 1
    print('S01 passed: Q1 5x2, Q2 3x4, Q3 5x4; row order and values match the recorded outputs.')
    print('Data: synthetic. Assisted status and independent competence remain separate records.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
