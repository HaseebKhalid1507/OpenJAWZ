# keys/

Public material only. The real signing key is generated offline and never enters this repo; what lives here is:

- `openjawz.gpg` — binary keyring export (`gpg --export <KEYID> > openjawz.gpg`)
- `openjawz-trusted` — `<FINGERPRINT>:4:` (ownertrust)
- `openjawz-revoked` — revoked fingerprints, one per line (empty until needed)

Until the release key is published these files are absent and the package is built with a throwaway key (`packages/build-repo.sh --throwaway`). The release fingerprint is printed in the README once it exists.
