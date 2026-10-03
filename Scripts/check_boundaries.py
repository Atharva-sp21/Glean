#!/usr/bin/env python3
"""Static architecture checks; not a substitute for an Instruments network trace."""
from pathlib import Path
import json, re
root = Path(__file__).resolve().parents[1]
for directory in ['AI', 'Processing', 'Actions', 'App', 'Views', 'ShareExtension']:
    for path in (root / directory).glob('*.swift'):
        text = path.read_text()
        if path.name != 'ModelDownloadService.swift':
            assert not re.search(r'URLSession\s*[.(]|URLRequest\(', text), f'Network API outside downloader: {path}'
        if directory == 'AI':
            assert not re.search(r'import EventKit|EKEventStore|UIApplication|UIPasteboard|Process\(', text), f'Privileged AI capability: {path}'
        assert not re.search(r'openURL\(|performSelector|NSSelectorFromString|executeCommand|runScript', text), path
assert 'MLX' not in (root / 'ShareExtension/ShareViewController.swift').read_text()
models = json.loads((root / 'Resources/ModelManifests.json').read_text())
assert [m['repo'] for m in models] == ['mlx-community/Qwen3-1.7B-4bit', 'mlx-community/Qwen3-1.7B-8bit', 'mlx-community/Qwen3-4B-Instruct-2507-4bit']
for model in models:
    assert re.fullmatch('[a-f0-9]{40}', model['revision'])
    for file in model['files']:
        assert '/' not in file['path'] and '..' not in file['path']
        assert re.fullmatch('[a-f0-9]{64}', file['sha256'])
        assert file['size'] > 0
print('PASS: network placement, action boundary, Share Extension isolation, and pinned model manifests')
