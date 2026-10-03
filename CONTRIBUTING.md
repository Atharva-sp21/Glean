# Contributing

Private Action is a private iOS prototype. Start with [setup](docs/GETTING_STARTED.md), [architecture](ARCHITECTURE.md) and the [security model](SECURITY.md).

## Development workflow

1. Create a focused branch from `main`.
2. Keep policy/model changes in `Core` where they can be tested without an iPhone.
3. Run core checks and the repository checks before opening a pull request.
4. If target membership or dependencies change, update `project.yml`, regenerate with XcodeGen 2.46.0 and commit the project and reviewed dependency pins together.
5. Describe the user-visible behavior, relevant tests and anything not yet verified on a device.

```sh
swift build --package-path Core
swift run --package-path Core SecurityChecks
swift test --package-path Core  # Full Xcode required
python3 Scripts/check_boundaries.py
python3 Scripts/check_repository.py
```

## Review expectations

- Treat shared content and model output as untrusted data.
- Preserve validation → explicit confirmation → deterministic execution.
- Keep network calls in the model downloader. Never add cloud inference, remote OCR or a model HTTP tool implicitly.
- Do not expose deletion, message sending, generic file access, URL execution or code execution to the model.
- Preserve file protection, backup exclusion, input bounds, generation bounds and cancellation.
- Verify model manifest size/hash changes and review dependency upgrades explicitly.
- Avoid logging prompts, OCR text, documents, names or generated replies.
- Use synthetic examples in tests, issues and screenshots. Do not attach real user content or credentials.
- Keep measured results separate from target values. Record physical-device tests in the format described in BENCHMARKING.md.

## Pull requests and releases

Use the pull request template. A passing CI run is not a substitute for physical iPhone acceptance. First release requires closing the gates in BUILD_STATUS.md and docs/ROADMAP.md. No automatic deployment or release publication is configured.

Security concerns should follow the private reporting instructions in SECURITY.md rather than a public issue. Licensing of original code remains undecided; do not add a blanket open-source license without the repository owner's choice.
