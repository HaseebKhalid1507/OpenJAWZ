# Auto-Research Playbook

## Metadata
- **Intent Keywords:** `optimize, auto-research, iterate, experiment, loop`
- **Triggers:** `"auto-research {target}", "optimize {target}", "run experiments on {target}"`
- **Parameters:** `target (what to optimize), eval (how to measure), sandbox (what files to modify)`
- **Estimated Duration:** `varies — runs until stopped or budget exhausted`

## Description

One agent. One file. One metric. Loop until it stops improving.

Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch). The agent modifies code, runs an eval that outputs a number, keeps improvements, reverts failures. Git manages state. No vibes — just scores.

## When to Use

When the result is **quantifiable**. Profits, hit rates, latency, scores, error rates — if you can measure it with a number, you can auto-research it.

## How to Run

1. **Human defines three things:**
   - **Sandbox:** which file(s) the agent can modify
   - **Eval:** a command that outputs a score (or tell the agent to build one)
   - **Goal:** higher is better, or lower is better

2. **the orchestrator dispatches one agent** with the task below. Pick based on domain:
   - `implementer` for general code optimization
   - `debugger` for creative/experimental approaches
   - `sysadmin` for infrastructure/systems tuning

3. **Agent loops autonomously.** the orchestrator waits.

4. **Agent returns** experiment log + final state. the orchestrator reviews and presents.

## Agent Task Template

```
You are running an AUTO-RESEARCH loop on {target}.

SANDBOX (files you may modify): {sandbox_files}
EVAL COMMAND: {eval_command}
GOAL: {lower_is_better | higher_is_better}
FROZEN (do not touch): {frozen_files} + the eval itself

PROCEDURE:
1. git checkout -b autoresearch/{tag} (if not already on a branch)
2. Run eval on current state → record as BASELINE
3. LOOP:
   a. Read the code. Form a hypothesis.
   b. Modify sandbox file(s) only.
   c. git commit -m "exp: <hypothesis>"
   d. Run eval command, capture output.
   e. Parse the score.
   f. If IMPROVED → keep. New baseline.
   g. If NOT IMPROVED → git reset --hard HEAD~1
   h. Log to results.tsv: commit | score | status | description
   i. Repeat.

RULES:
- Never modify frozen files or the eval.
- Never fake scores.
- Always revert before trying the next experiment.
- If stuck 3+ times, try something fundamentally different.
- Simpler is better. Removing code for equal score = great outcome.
- NEVER STOP to ask if you should continue. Loop until done.

OUTPUT when finished:
- Baseline → Final score (and % change)
- Full experiment log
- Summary of what worked and what didn't
```

## Output Format

```
# Auto-Research: {target}

Baseline: {score} → Final: {score} ({change}%)
Experiments: {kept}/{total}

| # | Hypothesis | Score | Delta | Result |
|---|-----------|-------|-------|--------|
| 1 | description | 74.1 | +1.8 | ✅ KEPT |
| 2 | description | 73.9 | -0.2 | ❌ REVERTED |

## What Worked
...

## What Didn't
...
```

## Edge Cases
- **No eval exists yet:** Tell the agent to build one first, then loop.
- **Eval is noisy:** Run 3x, take median. Improvement must exceed noise.
- **All experiments fail:** Agent should try radically different approaches before giving up.
- **Not quantifiable:** Wrong playbook. Use `code-review` or `build-feature` instead.
