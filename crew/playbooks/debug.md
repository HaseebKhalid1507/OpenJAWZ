# Debug Playbook

## Trigger Phrases
- "debug {issue}"
- "fix {error} in {context}"
- "{something} is broken"
- "investigate why {behavior}"

## Phase Breakdown

### Phase 1: Reproduce & Isolate
**Mode:** parallel  
**Comms Channel:** debug-{timestamp}

```yaml
agents:
  - agent: debugger
    task: "Reproduce {issue} in {context}. Create minimal test case, document exact steps, environment, and error messages. Try variations to find boundaries. Post reproduction steps to debug channel."
    
  - agent: implementer
    task: "Gather diagnostic data for {issue}. Collect: logs, stack traces, system state, config files, recent changes. Create timeline of when it worked vs broke. Post evidence to debug channel."
    
  - agent: sysadmin
    task: "Environment analysis for {issue}. Check: system resources, permissions, network state, conflicting processes, dependency versions. Look for environmental factors. Post findings to debug channel."
```

### Phase 2: Root Cause Analysis
**Mode:** chain

```yaml
chain:
  - agent: optimizer
    task: "Analyze debug channel data. Form hypotheses about root cause. Design targeted experiments to test each hypothesis. Consider non-obvious causes: {previous}"
    
  - agent: researcher
    task: "Deep investigation following experiment plan: {previous}. Use debugger, add instrumentation, analyze code flow. Search the brain (axel search) and the web for similar issues."
```

### Phase 3: Solution Development
**Mode:** parallel  
**Comms Channel:** solutions-{timestamp}

```yaml
agents:
  - agent: implementer
    task: "Implement fix for root cause identified. Keep changes minimal and surgical. Include defensive checks to prevent recurrence. Post solution code to solutions channel."
    
  - agent: debugger
    task: "Write test cases that verify the fix and prevent regression. Include: original failure case, edge cases, related scenarios. Post test code to solutions channel."
    
  - agent: planner
    task: "Design long-term architectural improvements to prevent similar issues. Consider: better error handling, validation, monitoring. Post design notes to solutions channel."
```

### Phase 4: Verification
**Mode:** chain

```yaml
chain:
  - agent: reviewer
    task: "Review proposed fix critically. Look for: incomplete fixes, new bugs introduced, performance impact, side effects: {previous}"
    
  - agent: heavy
    task: "Apply fix and run comprehensive test suite. Verify: original issue fixed, no regressions, performance acceptable: {previous}. Refactor if needed."
```

## Output Format
```markdown
# Debug Report: {issue}

## Issue Summary
- **Symptoms**: [What user sees]
- **Root Cause**: [Technical explanation]
- **Affected Systems**: [Scope]

## Timeline
- [When started]
- [Key events]
- [When fixed]

## Root Cause Analysis
### Hypothesis 1: [Theory]
- Test: [How tested]
- Result: [What found]

## Solution
### Immediate Fix
```diff
[Code changes]
```

### Tests Added
```[language]
[Test code]
```

### Prevention
[Architectural improvements]

## Verification
- [x] Original issue resolved
- [x] Regression tests pass
- [x] Performance unchanged
```

## Edge Cases
- **Can't reproduce**: Gather more context, check environment differences
- **Multiple causes**: Fix iteratively, document each
- **Heisenbug**: Add extensive logging, use debug channel coordination
- **Fix breaks other things**: Revert, rethink approach with optimizer