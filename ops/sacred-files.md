# Sacred files — agents never write these directly
# One path per line. Placeholders are identity.env keys. Read by the subagent preamble,
# `openjawz shutdown`, `openjawz toolmake check`, and the before_tool_call guard (v0.2).
{{OPENJAWZ_HOME}}/SOUL.md
{{OPENJAWZ_HOME}}/OP.md
{{OPENJAWZ_HOME}}/data/tasks.json
{{OPENJAWZ_HOME}}/data/tasks_history.json
{{OPENJAWZ_HOME}}/context/**
~/.synaps-cli/config
~/.synaps-cli/system.md
~/.synaps-cli/subagent-preamble.md
$XDG_CONFIG_HOME/axel/{{AGENT_NAME}}.r8
