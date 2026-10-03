# Models and third-party notices

Weights are not included in this repository. Only reviewed model metadata and hashes are bundled. Installation downloads only the selected model; no user content is supplied in that process.

| Model | Pinned revision | Total bytes | License | Availability |
|---|---|---:|---|---|
| [Qwen3 1.7B 4-bit](https://huggingface.co/mlx-community/Qwen3-1.7B-4bit/tree/3b1b1768f8f8cf8351c712464f906e86c2b8269e) | `3b1b1768f8f8cf8351c712464f906e86c2b8269e` | 984,013,244 | Apache-2.0 | Default |
| [Qwen3 1.7B 8-bit](https://huggingface.co/mlx-community/Qwen3-1.7B-8bit/tree/8c24f6782a91421513803ce527a27dcc560ab904) | `8c24f6782a91421513803ce527a27dcc560ab904` | 1,844,239,576 | Apache-2.0 | Developer only |
| [Qwen3 4B Instruct 2507 4-bit](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit/tree/50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b) | `50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b` | 2,278,965,419 | Apache-2.0 | Developer only |

The Qwen3 base models identify Apache-2.0 licensing. The community conversions link to their upstream models. Review both the conversion repository and upstream license before commercial distribution; this is an engineering record, not a legal conclusion. Apache-2.0 text is included in ThirdPartyNotices/Qwen-Apache-2.0.txt. Preserve attribution and notices when distributing weights.

Each file has its own expected length and SHA-256 in Resources/ModelManifests.json. Large-file hashes came from immutable-revision LFS metadata; small files were downloaded and independently hashed while preparing the catalog. Full weights have not been downloaded on this build host. The installer and every model load independently hash local files. Perform independent full-weight verification in controlled release CI as well.

## Dependencies

| Dependency | Version / revision | License |
|---|---|---|
| MLX Swift LM | 2.29.3 / 5064b8c5d8ed3b0bbb71385c4124f0fc102e74a2 | MIT |
| MLX Swift | 0.29.1 | MIT |
| Swift Transformers | 1.1.6 | Apache-2.0 |
| Swift Jinja | 2.5.1 | Apache-2.0 |
| Swift Collections | 1.1.4 | Apache-2.0 with Swift exception |
| Swift Numerics | 1.1.1 | Apache-2.0 with Swift exception |

Actual license texts in ThirdPartyNotices control over this summary. Exact transitive revisions are in PrivateAction.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved. MLX contains additional nested third-party components; audit and preserve their notices when packaging a release. Apple's platform frameworks are governed by Apple's SDK terms.

XcodeGen 2.46.0 generated the project and is not an application runtime dependency. Its MIT notice is included. The icon is an original programmatically drawn asset.

## Source references

- [Pinned MLX LM source](https://github.com/ml-explore/mlx-swift-lm/tree/5064b8c5d8ed3b0bbb71385c4124f0fc102e74a2)
- [MLX Swift iOS memory guidance](https://github.com/ml-explore/mlx-swift/blob/0.29.1/Source/MLX/Documentation.docc/Articles/running-on-ios.md)
- [Qwen3 1.7B upstream](https://huggingface.co/Qwen/Qwen3-1.7B)
- [Qwen3 4B Instruct upstream](https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507)
- [Apple Share Extension guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html)
