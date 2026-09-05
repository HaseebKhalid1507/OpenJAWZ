# migrations/

Timestamped shell scripts, run in lexical order by `openjawz migrate` (and by `openjawz update` after `pacman`), per-user markers in `~/.local/state/openjawz/migrations/`. Exists from commit one so it never has to be retrofitted.

## Naming

`<epoch>-<user|system>-<slug>.sh` — epoch is the commit time (`git log -1 --format=%cd --date=unix`), so ordering ≈ merge order and never collides on a rebase. `user` runs as the user; `system` is printed, then run once under `sudo bash` after confirmation (auto under `--yes`).

## Rules

1. **Idempotent.** `mkdir -p`, `ln -sfn`, `grep -q || append`, `systemctl --user enable`. Running twice changes nothing. CI runs each migration twice and diffs `$HOME`.
2. **No inter-migration dependencies.** Each one stands alone; a late-arriving older one may run after newer ones.
3. **Header from `TEMPLATE.sh`:** `set -euo pipefail` and `# openjawz-migration: <purpose>` are mandatory; CI rejects a new file whose epoch is older than the newest existing one.
4. **Fd 3 is closed** when the runner executes you (`bash -euo pipefail FILE 3<&-`).
5. **Failure is sticky.** The runner writes `<name>.running` before and renames it to `<name>` after. If you fail, `.running` stays and every later migration is refused until `openjawz migrate --force <name>` or `--skip <name>`.

## Runner (`openjawz migrate`)

`--pending` prints names or `none` · `--list` shows state per file · `--seed-all` writes every marker without running (fresh home) · `--force <name>` clears the dirty flag and re-runs · `--skip <name>` marks done without running. Before the first pending script, `openjawz brain backup --quick` runs if the brain package is installed. New users created after install start fully migrated (the package seeds markers into `/etc/skel`).
