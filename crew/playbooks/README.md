# Playbooks — Agent Orchestration Patterns

**Playbooks are predefined orchestration blueprints.** When the user says "deep research on X," the orchestrator doesn't improvise — it loads `deep-research.md` and executes the same proven pattern every time. Consistency over creativity. Precision over improvisation.

No more ad-hoc agent selection. No more forgetting which specialist handles what. The playbook **defines the crew, the phases, and the handoffs.** Period.

---

## How the orchestrator Uses Playbooks

1. **Intent Recognition** — the orchestrator matches user messages against playbook triggers
2. **Parameter Extraction** — Fills placeholders (`{topic}`, `{codebase}`, `{target}`)
3. **Phase Execution** — Runs each phase sequentially (single/parallel/chain)
4. **Output Aggregation** — Collects results according to playbook output spec
5. **Delivery** — Returns consolidated response to user

---

## Playbook Format

Every playbook is a `.md` file in `/usr/share/openjawz/crew/playbooks/` with this exact structure:

```markdown
# Playbook Name

## Metadata
- **Intent Keywords:** `keyword1, keyword2, keyword3`
- **Triggers:** `"phrase to match", "another trigger"`
- **Parameters:** `topic, codebase, target, deadline`
- **Estimated Duration:** `5-15 minutes`

## Description
Brief description of what this playbook accomplishes and when to use it.

## Phases

### Phase 1: [Name] (mode: single/parallel/chain)
**Agents:** agent1, agent2, agent3
**Comms Channel:** `channel-name` (if parallel with 3+ agents)
**Tasks:**
- **agent1:** Task description with {placeholders}
- **agent2:** Another task with {placeholders}
- **agent3:** Third task referencing {previous} (if chain mode)

### Phase 2: [Name] (mode: single/parallel/chain)
[Continue pattern...]

## Output Format
Description of how to consolidate phase results into final response.

## Edge Cases
- **Scenario:** Condition to handle
  **Action:** What to do
- **Scenario:** Another edge case  
  **Action:** Response strategy

## Success Criteria
Measurable outcomes that indicate playbook completion.
```

---

## Task Templates & Placeholders

### Standard Placeholders
- `{topic}` — Main subject/research target
- `{codebase}` — Repository/project path
- `{target}` — System/service/person to analyze
- `{deadline}` — Time constraint
- `{context}` — Additional background from user
- `{previous}` — Output from previous phase (chain mode only)

### Template Examples
```markdown
**researcher:** Analyze {topic} from technical architecture perspective. Focus on {context} if provided.

**implementer:** Execute implementation of {topic} in {codebase}. Reference architectural decisions from {previous}.

**pentester:** Penetration test {target} system. Document vulnerabilities and attack vectors for {topic}.
```

### Dynamic Extraction
the orchestrator extracts placeholder values from user messages:
- "Research blockchain consensus mechanisms" → `{topic}` = "blockchain consensus mechanisms"
- "Security audit ./myproject" → `{target}` = "./myproject"
- "Need this by Friday" → `{deadline}` = "Friday"

---

## Communication Channels

### Comms Rules
- **Single Agent:** No comms needed
- **2 Parallel Agents:** Direct handoff, no channel
- **3+ Parallel Agents:** Mandatory comms channel for coordination

### Channel Naming
- Format: `{playbook}-{phase}` (e.g., `deep-research-recon`, `security-audit-exploit`)
- Agents coordinate findings and avoid duplicate work
- Check `openjawz comms unread` before completing tasks

### Coordination Patterns
```markdown
# Post findings
openjawz comms post research-recon researcher "Found critical vulnerability in auth system" --type finding

# Ask for clarification  
openjawz comms post research-recon implementer "Need more details on API endpoints" --to researcher --type question

# Signal completion
openjawz comms post research-recon researcher "Recon phase complete, 15 findings documented" --type alert
```

---

## Available Roles

Role files live in `~/.synaps-cli/agents/<role>.md` (installed by `openjawz crew install`). Model per role comes from `identity.env` (`MODEL`); role files may override.

| Role | Specialty | Notes |
|------|-----------|-------|
| **planner** | specs, schemas, interfaces | designs, does not build |
| **implementer** | execution | general-purpose workhorse |
| **reviewer** | read-only critique | severity-ranked, verdict |
| **tester** | tests | unit / integration / edge cases, coverage |
| **debugger** | root cause | hypothesis-first |
| **researcher** | deep analysis, recon | Recon Output Format |
| **sysadmin** | shell, infra, systemd | battle-tested over trendy |
| **optimizer** | bottlenecks, refactors | before/after evidence |
| **archivist** | state, diffs, rollback | what IS vs SHOULD BE |
| **pentester** | security testing | authorised targets only |
| **writer** | docs, copy | clear first, memorable second |
| **heavy** | big rewrites | explains as it goes |
| **context-updater** | engram maintenance | shutdown step 6 |
| **extractor** | memories from a brief | pure function, JSON out |

---

## Execution Modes

### Single
```markdown
**Mode:** single
**Agents:** researcher
**Tasks:**
- **researcher:** Deep technical analysis of {topic}
```

### Parallel (2-8 agents, max 4 concurrent)
```markdown
**Mode:** parallel
**Agents:** researcher, pentester, sysadmin
**Comms Channel:** `security-audit-scan`
**Tasks:**
- **researcher:** Architecture analysis of {target}
- **pentester:** Vulnerability scanning of {target}
- **sysadmin:** Configuration audit of {target}
```

### Chain (sequential with context passing)
```markdown
**Mode:** chain
**Agents:** planner, implementer, reviewer
**Tasks:**
- **planner:** Design architecture for {topic}
- **implementer:** Implement {previous} architecture in {codebase}
- **reviewer:** Review implementation from {previous} for quality issues
```

---

## Adding New Playbooks

1. Create `$OPENJAWZ_HOME/playbooks/<name>.md` (user playbooks) — or contribute to `crew/playbooks/` in the repo.
2. Use the standard format above.
3. There is no playbook CLI in v0.1: the orchestrator reads the file and dispatches the phases itself. Validate by reading it back and running one phase by hand.

### Naming Convention
- Kebab-case filenames: `deep-research.md`, `security-audit.md`
- Descriptive but concise: `code-review.md` not `comprehensive-code-quality-analysis.md`
- Action-oriented: `deploy-service.md`, `debug-performance.md`

---

## Intent Matching System

### Keyword Matching
Playbooks define **intent keywords** and **trigger phrases**:
```markdown
- **Intent Keywords:** `research, analysis, investigate, study, explore`
- **Triggers:** `"deep research on", "analyze thoroughly", "investigate the"`
```

### Matching Priority
1. **Exact trigger phrase match** (highest priority)
2. **Intent keyword density** in user message
3. **Parameter availability** (has required placeholders)
4. **Playbook specificity** (more specific beats generic)

### Fallback Behavior
- No match → Default to `debugger` single-agent improvisation
- Multiple matches → Pick most specific (most keyword matches)
- Ambiguous → Ask user to clarify with available options

### Match Examples
```
User: "I need deep research on GraphQL performance"
→ Matches: deep-research.md (trigger: "deep research on")
→ Extracts: {topic} = "GraphQL performance"

User: "Security audit the payment API"  
→ Matches: security-audit.md (keywords: security, audit)
→ Extracts: {target} = "payment API"

User: "Can someone help debug this?"
→ No specific match → Fallback to debugger improvisation
```

---

## Playbook Registry

### Current Playbooks
- `deep-research.md` — Comprehensive technical investigation
- `security-audit.md` — Multi-phase security assessment  
- `code-review.md` — Quality assurance and improvement
- `debug-session.md` — Systematic problem diagnosis
- `architecture-design.md` — System blueprint creation
- `performance-optimization.md` — Speed/efficiency improvement
- `deployment-prep.md` — Release readiness assessment

### Listing
```bash
ls /usr/share/openjawz/crew/playbooks/ $OPENJAWZ_HOME/playbooks/ 2>/dev/null
```

---

## Design Principles

### Consistency Over Creativity
Every "deep research" request gets the same proven pattern. No improvisation. No forgotten steps.

### Specialization Over Generalization  
Each agent has a defined role. No overlap. No confusion about who handles what.

### Coordination Over Chaos
Parallel agents coordinate through comms channels. No duplicate work. No missed handoffs.

### Measurement Over Intuition
Success criteria are explicit. Edge cases are documented. Results are measurable.

---

**The playbook system transforms the orchestrator from improvisational chaos into surgical precision.** Every request. Every time. Exactly as designed.

*No exceptions.*

- **gauntlet.md** — N adversaries (Stranger in a fresh container, Packager, Auditor, Architect, Reader, Operator) run in ROUNDS until a full round is clean. Use after build-feature, before calling anything shippable. Use after `build-feature`, before calling anything shippable.
