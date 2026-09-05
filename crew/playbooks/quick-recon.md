# Quick Recon Playbook

## Trigger Phrases
- "quick check on {topic}"
- "what's {topic}?"
- "lookup {topic}"
- "brief on {topic}"
- "tl;dr {topic}"

## Phase Breakdown

### Phase 1: Parallel Quick Search
**Mode:** parallel  
**No comms needed** (too quick)

```yaml
agents:
  - agent: implementer
    task: "Quick axel search for {topic}. Get definition, key facts, recent mentions. Maximum 2 minutes."
    
  - agent: writer
    task: "Web search {topic} using the web tool. Get current status, recent news, popular resources. Focus on first page results only."
    
  - agent: researcher
    task: "Knowledge graph quick scan for {topic}. Find top 5 related concepts and key relationships. One level deep only."
```

### Optional Phase 2: Focus Dive
**Mode:** single  
**Triggered if:** User asks follow-up

```yaml
agent: optimizer
task: "Based on initial findings, identify the most strategic angle for deeper investigation of {topic}: {previous}"
```

## Output Format
```markdown
# Quick Recon: {topic}

## What it is
[1-2 sentence definition]

## Key Points
• [Fact 1]
• [Fact 2]
• [Fact 3-5]

## Current Status
[Latest developments if any]

## Related Topics
- [Connection 1]
- [Connection 2]

## Go Deeper?
→ Run `deep-research` for comprehensive analysis
→ Specific aspects to explore: [suggestions]
```

## Edge Cases
- **No results**: Suggest alternate spellings, related terms
- **Too many results**: Show most relevant, note abundance
- **Ambiguous topic**: List possibilities, ask for clarification
- **Time sensitive**: Flag if info might be outdated

## Optimization Notes
- 3 agents max for speed
- No chains (too slow)
- No comms (overhead not worth it)
- 5 minute total timeout
- Cache results for 1 hour