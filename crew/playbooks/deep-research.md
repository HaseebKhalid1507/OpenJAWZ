# Deep Research Playbook

## Trigger Phrases
- "deep dive on {topic}"
- "research {topic} comprehensively"
- "I need everything on {topic}"
- "full analysis of {topic}"

## Core Rule
**Every research task connects back to us.** Agents don't just find information — they find information *in relation to our system, our projects, our context.* External findings get compared to what we already have. Gaps between industry state and our state get flagged. This is applied research, not academic research.

## Phase Breakdown

### Phase 1: Internal Recon (single)
**Mode:** single

```yaml
agent: researcher
task: "INTERNAL FIRST. Search everything we have on {topic}:
  1. axel search '{topic}' — hybrid search (vector + keyword + graph)
  2. axel search --category notes "{topic}" — indexed notes
  3. Read any relevant files in $OPENJAWZ_HOME/notes/ that relate to {topic}
  4. Check $OPENJAWZ_HOME/context/ for mentions in session history or project briefs
  
  Write a brief of EVERYTHING we already know about {topic} — what we've built, what we've discussed, what's in our knowledge base. This becomes the baseline all other agents reference.
  
  Save to $OPENJAWZ_HOME/workspace/research-{topic-slug}-internal.md"
```

### Phase 2: External Search (5 agents, 4 concurrent)
**Mode:** parallel  
**Comms Channel:** research-{timestamp}

the orchestrator posts the internal brief to the comms channel before dispatching. Every agent reads it first.

```yaml
agents:
  - agent: implementer
    task: "Search academic papers and technical documentation on {topic} using the web tool. Focus on authoritative sources, research papers, and technical specs. RELATE BACK: compare findings against the internal brief — what's new vs what we already know? Post key findings to research channel."
    
  - agent: writer
    task: "Search web for {topic} using the web tool. Find recent articles, blog posts, tutorials, and community discussions. Look for practical implementations and real-world usage. RELATE BACK: flag anything that contradicts or extends what we've built. Post interesting finds to research channel."
    
  - agent: sysadmin
    task: "Search GitHub for repos related to {topic}. Clone the most relevant 2-3 repos to $OPENJAWZ_HOME/workspace/research/. Read source code, READMEs, architecture docs, and examples. Analyze how {topic} is actually implemented in real codebases. RELATE BACK: compare implementation patterns to our own approach. Post code insights to research channel."
    
  - agent: debugger
    task: "Hunt for the edges of {topic}. Search for limitations, controversies, failure cases, and alternative approaches using the web tool. Find the stuff the hype articles don't mention — scaling problems, tradeoffs, what breaks, what people complain about. RELATE BACK: do any of these failure modes apply to us? Post technical insights to research channel."
    
  - agent: pentester
    task: "Security and risk analysis of {topic}. Search for vulnerabilities, attack vectors, supply chain risks, and trust issues using the web tool. RELATE BACK: assess our exposure — are we vulnerable to any of these risks with our current setup? Post security findings to research channel."
```

### Phase 3: Analysis Chain
**Mode:** chain

```yaml
chain:
  - agent: optimizer
    task: "Review the internal brief AND all external findings from research channel. Produce a gap analysis: what the industry does vs what we do, what we're ahead on, what we're behind on, what we should steal. Identify strategic opportunities: {previous}"
    
  - agent: reviewer
    task: "Critical analysis of everything. Challenge the research quality — biases, missing perspectives, hype vs reality. Challenge our own system too — are we doing things wrong? What are we ignoring? No sacred cows: {previous}"
```

### Phase 4: Synthesis
**Mode:** single

```yaml
agent: researcher
task: "Create comprehensive research report from all phases: {previous}. Structure: Executive Summary, What We Already Have, What the Industry Does, Gap Analysis, Practical Recommendations, Open Questions, References. This report should be actionable — not just 'here's what exists' but 'here's what we should do about it.'"
```

## Output Format
```markdown
# {topic} — Research Report

## Executive Summary
[2-3 paragraph overview — what we found, what it means for us]

## What We Already Have
[Our current implementation, knowledge, approach to {topic}]

## What the Industry Does
### Core Concepts
[Key definitions, patterns, standards]

### Technical Landscape
[Frameworks, implementations, approaches]

### Source Code Insights
[What we learned from reading actual repos]

## Gap Analysis
| Area | Industry State | Our State | Gap | Priority |
|------|---------------|-----------|-----|----------|
| ... | ... | ... | ... | high/med/low |

## Security & Risks
[Threat model for {topic} — what could go wrong, our exposure]

## Recommendations
1. [Actionable thing we should do]
2. [Another thing]
3. [...]

## Contradictions & Debates
[Conflicting viewpoints found in research]

## Open Questions
[What remains unknown or needs deeper investigation]

## References
[Sorted by relevance, with source type: paper/repo/article/discussion]
```

## Edge Cases
- **No internal context**: Skip Phase 1, note we're starting from planner
- **Topic too broad**: Focus subtopics across parallel agents
- **Conflicting info**: Flag contradictions, trace sources, let reviewer tear it apart
- **Outdated info**: Prioritize recent sources, note historical context
- **Sensitive topic**: Skip posting findings to comms if they contain credentials or private info
