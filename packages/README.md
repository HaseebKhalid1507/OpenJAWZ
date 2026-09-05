# packages/

PKGBUILDs. This directory is the product; everything else is source for these.

| dir | what |
|---|---|
| `openjawz/` | `pkgbase=openjawz`, split into `openjawz-{meta,core,daemon,hooks,crew,ops,brain,ui}`, `arch=(any)`, members pinned to each other by exact version. `openjawz-meta` is the empty package whose `depends=` pulls the rest (+ `synaps-bin`). |
| `synaps-bin/` | the runtime, prebuilt, pinned by tag + sha256. `SYNAPS_TARBALL=` builds from a local tarball (dev). |
| `axel-bin/` | the brain, prebuilt. `optdepends` of meta until its release exists. |
| `openjawz-keyring/` | the trust root; public material only, populated on install. |

## Build

```sh
packages/build-repo.sh --throwaway               # everything from HEAD into build/repo, throwaway key (CI/dev)
packages/build-repo.sh --key <KEYID>             # release: sign packages + db with the release key
SYNAPS_TARBALL=~/dist/synaps-v0.9.1rc1-x86_64-unknown-linux-gnu.tar.gz packages/build-repo.sh …
```

Output is a flat directory (`*.pkg.tar.zst`, `.sig`, `openjawz.db`, `openjawz.db.tar.zst`, `openjawz.files` — real files, not symlinks) ready for `gh release upload repo-x86_64 …` or for `boot --local DIR`.

## Version rules

- `VERSION` at the repo root is the single source. `tests/pkg` asserts `pkgver` equals it.
- Pre-releases use the **attached** form `0.1.0rc1`: `vercmp` orders it before `0.1.0`. `0.1.0.rc1` / `0.1.0_rc1` sort *after* the release and strand users.
- `repo-add` inserts in argv order; keep one version of each package per release.

## Scriptlets

`openjawz-core.install` prints one line (`run openjawz install` / `run openjawz update`). Nothing else. Packages never enable units, never touch `$HOME`, never edit files they do not own.
