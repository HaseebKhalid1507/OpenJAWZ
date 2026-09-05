# Code Review Playbook

## Trigger Phrases
- "review {codebase}"
- "code review for {PR/commit/file}"
- "check code quality of {target}"
- "review changes in {context}"

## Phase Breakdown

### Phase 1: Initial Analysis
**Mode:** parallel  
**Comms Channel:** review-{timestamp}

```yaml
agents:
  - agent: sysadmin
    task: "Technical correctness review of {codebase}. Check: logic errors, API usage, error handling, resource management, compatibility. Post issues to review channel with file:line references."
    
  - agent: optimizer
    task: "Architecture and performance review of {codebase}. Analyze: design patterns, algorithmic complexity, bottlenecks, optimization opportunities. Post strategic improvements to review channel."
    
  - agent: implementer
    task: "Code style and maintainability check of {codebase}. Review: naming, documentation, test coverage, code organization. Run linters if available. Post cleanup suggestions to review channel."
    
  - agent: pentester
    task: "Security review of {codebase}. Hunt for: input validation issues, auth problems, data exposure, injection vulnerabilities. Post security concerns to review channel."
```

### Phase 2: Deep Analysis
**Mode:** parallel  
**Comms Channel:** deep-review-{timestamp}

```yaml
agents:
  - agent: reviewer
    task: "Critical design review using findings from review channel. Challenge: assumptions, design decisions, unnecessary complexity. Why does this code exist? Post fundamental questions to deep-review channel."
    
  - agent: heavy
    task: "Refactoring analysis using review channel data. Identify: duplicate code, violations of DRY/SOLID, missed abstractions. Write example refactors. Post to deep-review channel."
    
  - agent: planner
    task: "Specification compliance check. Verify code matches intended behavior, API contracts, and requirements. Note discrepancies. Use axel search for spec lookups. Post to deep-review channel."
```

### Phase 3: Synthesis
**Mode:** chain

```yaml
chain:
  - agent: researcher
    task: "Synthesize all review findings from both channels. Prioritize by: severity, effort to fix, impact on system. Create actionable review: {previous}"
    
  - agent: writer
    task: "Write developer-friendly review summary. Balance criticism with positive feedback. Suggest learning resources where needed: {previous}"
```

## Output Format
```markdown
# Code Review: {codebase}

## Summary
**Overall Quality**: [Excellent|Good|Needs Work|Poor]
**Ready to Merge**: [Yes|No|After fixes]

## Critical Issues (Must Fix)
### 1. [Issue Name]
**File**: path/to/file.ext:L42
**Issue**: [Description]
**Fix**: 
```diff
- [bad code]
+ [good code]
```

## Important Improvements
[Issues that should be fixed but aren't blockers]

## Suggestions
[Nice-to-have improvements]

## Positive Findings
- [What's done well]
- [Good patterns found]

## Security Checklist
- [ ] Input validation
- [ ] Authentication
- [ ] Authorization
- [ ] Data sanitization
- [ ] Secrets management

## Metrics
- Test Coverage: X%
- Cyclomatic Complexity: Y
- Code Duplication: Z%
```

## Edge Cases
- **Huge PR**: Focus on critical paths and API surfaces first
- **Generated code**: Skip style checks, focus on logic
- **Hotfix**: Fast security/correctness check only
- **Refactor PR**: Verify behavior unchanged, focus on improvements