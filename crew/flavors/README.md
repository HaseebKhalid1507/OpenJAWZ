# crew/flavors — empty by design

A **flavor** is voice only: a persona line, a handful of personality bullets, tone notes — at most 15 lines.
It is applied by concatenation at dispatch (`role + flavor`) and is never merged into a role file.

Flavors never add tools, rules, paths or authority. If a flavor changes *what* an agent may do, it is not a flavor.

**None ship in v0.1.** The roles in `crew/roles/` are deliberately voice-neutral; the main agent's voice comes from the
user's own answers in `openjawz onboard` (`VOICE` in `identity.env`). No franchise characters, no borrowed names:
anything shipped here must be an original archetype (e.g. *laconic-veteran*, *cold-architect*, *no-filter-critic*).

To add your own: `~/.synaps-cli/agents/<role>.md` is a plain file — append your flavor lines below the role's
`## Output style` section, or keep a `flavors/<name>.md` and concatenate at install time. `openjawz crew refresh`
never overwrites a role file you have edited.
