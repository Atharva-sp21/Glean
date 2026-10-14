#!/usr/bin/env python3
"""Static architecture checks; not a substitute for an Instruments network trace."""
from pathlib import Path
import json, re
root = Path(__file__).resolve().parents[1]
for directory in ['AI', 'Processing', 'Actions', 'App', 'Views', 'ShareExtension']:
    for path in (root / directory).glob('*.swift'):
        text = path.read_text()
        if path.name not in {'ModelDownloadService.swift', 'GmailConnection.swift'}:
            assert not re.search(r'URLSession\s*[.(]|URLRequest\(', text), f'Network API outside downloader: {path}'
        if directory == 'AI':
            assert not re.search(r'import EventKit|EKEventStore|UIApplication|UIPasteboard|Process\(', text), f'Privileged AI capability: {path}'
        assert not re.search(r'performSelector|NSSelectorFromString|executeCommand|runScript', text), path
        if path.relative_to(root).as_posix() == 'Views/SettingsView.swift':
            # User-initiated setup navigation is separate from model-proposed actions.
            # Keep the exception confined to this view and its two trusted destinations.
            before, setup = text.split('struct BackTapSetupView: View {', 1)
            assert 'openURL(' not in before, path
            assert setup.count('openURL(') == 2, path
            assert 'url.scheme == "https", url.host == "www.icloud.com"' in setup
            assert 'url.path.hasPrefix("/shortcuts/")' in setup
            assert 'URL(string: "shortcuts://")' in setup
            assert 'Button("Add Shortcut"' in setup and 'Button("Open Shortcuts"' in setup
        else:
            assert not re.search(r'openURL\(', text), path
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

gmail = (root / 'App/GmailConnection.swift').read_text()
assert 'gmail.readonly' in gmail and 'gmail.modify' not in gmail
assert 'prefersEphemeralWebBrowserSession = true' in gmail
assert 'code_challenge_method": "S256"' in gmail
assert 'completionHandler(nil)' in gmail
assert 'UserDefaults' not in gmail and 'print(' not in gmail
