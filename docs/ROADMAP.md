# Roadmap

Progress means verified behavior, not just code existing. [BUILD_STATUS.md](../BUILD_STATUS.md) is the validation record.

## Implemented prototype

- [x] Native application shell and action-oriented screens
- [x] App Group inbox and lightweight Share Extension
- [x] Bounded text/image/PDF/URL-metadata intake
- [x] Local Vision OCR and PDFKit extraction
- [x] MLX/Qwen adapter and pinned model integrity catalog
- [x] Typed output validation and explicit action approval
- [x] EventKit and protected local-save handlers
- [x] Synthetic benchmark suite and deterministic security harness
- [x] Documentation and repository workflows

## Next: make the iPhone workflow pass

- [ ] Build the entire iOS app and extension with full Xcode
- [ ] Run app-hosted tests and verify App Group provisioning
- [ ] Run a real Qwen model smoke test on standard iPhone 15
- [ ] Pass the interview-screenshot acceptance flow
- [ ] Pass the malicious-screenshot acceptance flow
- [ ] Verify exactly one approved Calendar/Reminder write
- [ ] Repeat in Airplane Mode and inspect a zero-network inference trace
- [ ] Verify cancellation, repeat execution, memory and thermal behavior

## Before broader distribution

- [ ] Assess a pinned grammar-constrained generation implementation
- [ ] Independently verify full model weights in release infrastructure
- [ ] Harden cross-process aggregate inbox quota accounting
- [ ] Test Share Sheet providers across Photos, Safari, Files and Notes
- [ ] Complete accessibility, localization and recovery-path review
- [ ] Complete privacy manifest, license and archive review
- [ ] Choose the original-code license and distribution policy

## Experiments after the default passes

Compare 1.7B INT4, 1.7B INT8 and 4B INT4 with the same synthetic suite and device conditions. Download models only after explicit selection. Do not weaken memory protection to obtain a speed result.

Cloud AI, autonomous sending/deletion and arbitrary model tools are outside the current product scope.
