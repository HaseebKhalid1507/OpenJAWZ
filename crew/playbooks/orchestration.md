# the orchestrator Multi-Agent Orchestration Playbooks v1.0

## 1. deep-research
**Trigger phrases:** "deep dive on {topic}", "research {topic} thoroughly", "I need comprehensive research on {topic}", "tell me everything about {topic}"

### Phases
**Phase 1: Parallel Reconnaissance (comms: research-{topic})**
```yaml
mode: parallel
agents:
  - agent: researcher
    task: "Search academic papers, technical documentation, and authoritative sources on {topic} using axel search and the web tool. Focus on fundamentals, theory, and established knowledge. Post key findings to research-{topic} channel."
  
  - agent: sysadmin
    task: "Find GitHub repos, technical implementations, and practical examples of {topic}. Check for production usage, common patterns, and real-world applications. Post discoveries to research-{topic} channel."
  
  - agent: writer
    task: "Search for tutorials, blog posts, community discussions, and beginner resources about {topic}. Identify common questions and pain points. Post insights to research-{topic} channel."
```

**Phase 2: Deep Analysis**
```yaml
mode: single
agent: optimizer
task: "Read all findings from research-{topic} channel. Identify the optimal angle for understanding {topic}. What's the 20% that gives 80% comprehension? Create a strategic learning path and highlight non-obvious insights. Output: structured analysis with key concepts, mental models, and strategic recommendations."
```

**Phase 3: Synthesis**
```yaml
mode: single
agent: researcher
task: "Using {previous} analysis, create comprehensive synthesis of {topic}. Structure: Executive Summary → Core Concepts → Technical Deep Dive → Practical Applications → Open Questions → Resources. Make it authoritative yet accessible."
```

**Output:** Markdown document with executive summary, deep technical analysis, practical applications, and curated resources.

**Edge cases:** 
- If topic is code-specific, add implementer in Phase 1 to analyze implementations
- If security-related, add pentester in Phase 1

---

## 2. build-feature
**Trigger phrases:** "build {feature}", "implement {feature} for {codebase}", "add {feature} functionality", "create a new feature for {feature}"

### Phases
**Phase 1: Architecture & Spec**
```yaml
mode: single
agent: planner
task: "Design architecture for {feature} in {codebase}. Analyze existing code structure, identify integration points, design interfaces and data flow. Create technical specification with clear acceptance criteria. Consider: extensibility, performance, maintainability."
```

**Phase 2: Spec Review**
```yaml
mode: parallel
agents:
  - agent: optimizer
    task: "Review {previous} spec for optimization opportunities. Is this the smartest approach? Are there unnecessary complexities? Suggest strategic improvements."
  
  - agent: reviewer  
    task: "Critically review {previous} spec. Find flaws, edge cases, potential bugs. Challenge assumptions. What will break? What's missing?"
```

**Phase 3: Implementation**
```yaml
mode: single
agent: implementer
task: "Implement {feature} according to refined spec from {previous}. Write clean, documented code with comprehensive error handling. Include unit tests. Follow project conventions in {codebase}."
```

**Phase 4: Testing & Hardening (comms: feature-test-{feature})**
```yaml
mode: parallel
agents:
  - agent: debugger
    task: "Test {previous} implementation creatively. Try to break it in unexpected ways. Write edge case tests. Post findings to feature-test-{feature} channel."
  
  - agent: pentester
    task: "Security test {previous} implementation. Check for injection vulnerabilities, access control issues, data leaks. Post security concerns to feature-test-{feature} channel."
```

**Phase 5: Final Review & Polish**
```yaml
mode: single
agent: heavy
task: "Review all code and test feedback from feature-test-{feature} channel. Refactor for clarity, enforce best practices, improve documentation. Ensure code teaches future maintainers. Output production-ready implementation."
```

**Output:** Complete feature implementation with tests, documentation, and security validation.

**Edge cases:**
- For frontend features, emphasize writer for UI/UX in Phase 1
- For system-level features, include sysadmin in Phase 2 review
- Skip Phase 5 for prototype/POC requests

---

## 3. security-audit
**Trigger phrases:** "security audit {target}", "pentest {target}", "find vulnerabilities in {target}", "check {target} for security issues"

### Phases
**Phase 1: Reconnaissance**
```yaml
mode: single
agent: researcher
task: "Perform deep reconnaissance on {target}. Map attack surface, identify technologies, find endpoints, discover dependencies. Use axel search for known vulnerabilities in identified components. Create target profile with: tech stack, exposed services, potential entry points."
```

**Phase 2: Vulnerability Analysis (comms: security-{target})**
```yaml
mode: parallel
agents:
  - agent: pentester
    task: "Perform penetration testing on {target} based on {previous} recon. Test for: injection flaws, auth bypass, misconfigurations, sensitive data exposure. Post findings with severity ratings to security-{target} channel."
  
  - agent: sysadmin
    task: "Audit {target} infrastructure and deployment. Check: permissions, network exposure, secrets management, logging, dependencies with CVEs. Post infrastructure vulnerabilities to security-{target} channel."
  
  - agent: optimizer
    task: "Analyze {target} architecture for strategic vulnerabilities. Look for: design flaws, trust boundaries, data flow issues, crypto misuse. Post architectural concerns to security-{target} channel."
```

**Phase 3: Exploit Development**
```yaml
mode: single
agent: pentester
task: "For critical vulnerabilities found in security-{target} channel, develop proof-of-concept exploits. Demonstrate impact without causing damage. Create responsible disclosure documentation."
```

**Phase 4: Report & Remediation**
```yaml
mode: single
agent: reviewer
task: "Create comprehensive security report from {previous} findings. Structure: Executive Summary → Critical Findings → Risk Matrix → Technical Details → Remediation Steps → Timeline. Be brutally honest about severity."
```

**Output:** Professional security audit report with findings, risk ratings, POCs, and remediation guidance.

**Edge cases:**
- For web apps, add writer in Phase 2 for client-side security
- If no critical findings, skip Phase 3

---

## 4. debug
**Trigger phrases:** "debug {issue}", "fix {issue} in {codebase}", "figure out why {issue}", "solve this bug: {issue}"

### Phases
**Phase 1: Reproduction & Evidence**
```yaml
mode: single
agent: debugger
task: "Reproduce {issue} in {codebase}. Create minimal test case. Gather evidence: error messages, logs, stack traces, environmental factors. Document exact steps to reproduce. If can't reproduce, try creative variations based on {context}."
```

**Phase 2: Root Cause Analysis (comms: debug-{issue})**
```yaml
mode: parallel
agents:
  - agent: sysadmin
    task: "Perform deep technical analysis of {previous} evidence. Trace execution flow, examine system state, check resource usage. Use debugging tools. Post technical findings to debug-{issue} channel."
  
  - agent: optimizer
    task: "Analyze {previous} evidence strategically. What's the real problem vs symptoms? Look for non-obvious causes: race conditions, edge cases, architectural issues. Post strategic insights to debug-{issue} channel."
```

**Phase 3: Solution Development**
```yaml
mode: single
agent: implementer
task: "Based on root cause analysis from debug-{issue} channel, implement fix for {issue}. Make minimal necessary changes. Add regression tests. Document why the fix works."
```

**Phase 4: Verification**
```yaml
mode: single
agent: debugger
task: "Verify {previous} fix thoroughly. Run original reproduction case, try variations, check for regressions. Ensure the issue is truly resolved and no new issues introduced."
```

**Output:** Debugged code with fix, regression tests, and root cause documentation.

**Edge cases:**
- For performance issues, emphasize optimizer's optimization skills
- For intermittent bugs, extend Phase 1 with more agents
- For urgent issues, skip to Phase 3 with best guess

---

## 5. quick-recon
**Trigger phrases:** "quick look at {topic}", "what is {topic}", "give me a summary of {topic}", "brief research on {topic}"

### Phases
**Phase 1: Rapid Intel**
```yaml
mode: single
agent: researcher
task: "Quick reconnaissance on {topic}. Use axel search first for existing knowledge, then the web tool for current info. Focus on: what it is, why it matters, key facts, current state. Time-box to 10 minutes of research. Output concise briefing."
```

**Phase 2: Practical Context**
```yaml
mode: single
agent: writer
task: "Based on {previous} intel, add practical context about {topic}. How do people actually use it? Common gotchas? Quick examples? Make it immediately useful for the user."
```

**Output:** Concise 1-2 page briefing with key facts and practical context.

**Edge cases:**
- For people, use `axel search --category entities` in Phase 1
- For urgent requests, skip Phase 2
- If topic needs deep dive, recommend deep-research playbook

---

## 6. code-review
**Trigger phrases:** "review {codebase}", "code review {target}", "check {codebase} quality", "audit {codebase} code"

### Phases
**Phase 1: Structural Analysis**
```yaml
mode: single
agent: planner
task: "Review {target} architecture and structure. Evaluate: design patterns, modularity, separation of concerns, dependency management, API design. Identify architectural smells and improvement opportunities."
```

**Phase 2: Multi-Perspective Review (comms: review-{target})**
```yaml
mode: parallel
agents:
  - agent: reviewer
    task: "Critically review {target} code quality. Hunt for: bugs, code smells, unclear logic, missing tests, poor error handling. Be harsh but fair. Post issues to review-{target} channel with line numbers."
  
  - agent: optimizer
    task: "Review {target} for optimization opportunities. Find: performance bottlenecks, inefficient algorithms, redundant code, missed abstractions. Post optimization suggestions to review-{target} channel."
  
  - agent: implementer
    task: "Review {target} implementation details. Check: coding standards, documentation, test coverage, maintainability. Post practical improvements to review-{target} channel."
  
  - agent: pentester
    task: "Security review {target}. Look for: unsafe operations, injection risks, authentication flaws, data validation issues. Post security concerns to review-{target} channel."
```

**Phase 3: Synthesis & Recommendations**
```yaml
mode: single
agent: heavy
task: "Synthesize all feedback from review-{target} channel. Create actionable code review report. Prioritize issues: Critical → Major → Minor → Suggestions. For each issue, explain why it matters and how to fix it. Make the review educational, not just critical."
```

**Output:** Comprehensive code review with prioritized issues, improvement suggestions, and educational explanations.

**Edge cases:**
- For small PRs, use only reviewer in Phase 2
- For performance-critical code, add sysadmin for system-level review
- For UI code, add writer for UX review

---

## General Optimization Notes

1. **Comms channels** are used when:
   - Multiple agents work on related aspects (parallel analysis)
   - Findings need coordination (security, testing)
   - Context prevents duplicate work

2. **Opus agents** (researcher, sysadmin, optimizer, reviewer) are reserved for:
   - Deep analysis and research
   - Strategic thinking
   - Critical reviews
   - Complex technical investigations

3. **Phase ordering** optimizes for:
   - Dependencies (can't review what doesn't exist)
   - Token efficiency (reconnaissance before deep work)
   - Fast feedback (parallel where possible)

4. **Deviation triggers:**
   - Urgent requests: Skip review phases
   - Simple tasks: Reduce agent count
   - Complex domains: Add domain expert agents
   - Time constraints: Prioritize critical phases