#!/usr/bin/env python3
"""Check repository hygiene without network access or third-party Python packages."""
from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', '.build', 'DerivedData', '__pycache__'}
required = [
    'README.md', 'ARCHITECTURE.md', 'SECURITY.md', 'BENCHMARKING.md',
    'BUILD_STATUS.md', 'MODEL_LICENSES.md', 'CONTRIBUTING.md',
    'docs/GETTING_STARTED.md', 'docs/ROADMAP.md', 'docs/assets/banner.svg',
    '.github/workflows/ci.yml', '.github/workflows/ios-build.yml',
    '.github/pull_request_template.md', 'project.yml',
    'PrivateAction.xcodeproj/project.pbxproj',
]
for name in required:
    assert (ROOT / name).is_file(), f'Missing repository file: {name}'

for path in ROOT.rglob('*'):
    if not path.is_file() or SKIP.intersection(path.relative_to(ROOT).parts):
        continue
    if path.suffix in {'.md', '.swift', '.yml', '.yaml', '.json', '.py', '.pbxproj'}:
        text = path.read_text()
        assert not re.search(r'/(?:Users|home)/[^/]+/', text), f'Personal absolute path in {path.relative_to(ROOT)}'
        assert not re.search(r'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{40,}', text), f'Possible GitHub credential in {path.relative_to(ROOT)}'
        assert not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', text), f'Private key in {path.relative_to(ROOT)}'
    if path.suffix == '.md':
        for link in re.findall(r'\]\(([^)]+)\)', text):
            target = link.split('#', 1)[0]
            if not target or re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', target):
                continue
            assert (path.parent / target).exists(), f'Broken local link in {path.relative_to(ROOT)}: {target}'
    if path.suffix in {'.plist', '.entitlements', '.xcprivacy'}:
        plistlib.loads(path.read_bytes())

ET.parse(ROOT / 'docs/assets/banner.svg')
lock = json.loads((ROOT / 'PrivateAction.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())
assert len(lock['pins']) == 6, 'Unexpected dependency set; review lockfile changes'
for package in lock['pins']:
    assert re.fullmatch(r'[0-9a-f]{40}', package['state']['revision']), 'Dependency without an immutable revision'
for workflow in (ROOT / '.github/workflows').glob('*.yml'):
    text = workflow.read_text()
    assert 'contents: read' in text, f'Workflow should use read-only repository permissions: {workflow.name}'
    for action in re.findall(r'uses:\s*(\S+)', text):
        assert re.fullmatch(r'[^@]+@[0-9a-f]{40}', action), f'Unpinned action: {action}'
print('PASS: repository files, relative links, asset/config syntax, credential patterns, and dependency/action pins')
