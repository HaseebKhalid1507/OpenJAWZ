# Build Feature Playbook

## Trigger Phrases
- "build {feature} for {target}"
- "implement {feature}"
- "create new feature {feature}"
- "add {feature} functionality"

## Phase Breakdown

### Phase 1: Specification
**Mode:** single

```yaml
agent: planner
task: "Design technical specification for {feature} in {target}. Include: requirements, API design, data structures, integration points, error handling, performance considerations. Search existing patterns with axel search."
```

### Phase 2: Spec Review
**Mode:** parallel  
**Comms Channel:** spec-review-{timestamp}

```yaml
agents:
  - agent: optimizer
    task: "Analyze spec for optimization opportunities. Review architecture, identify potential bottlenecks, suggest performance improvements. Post findings to spec-review channel."
    
  - agent: reviewer
    task: "Critical review of spec. Find edge cases, missing requirements, potential failures. Challenge design decisions. Post concerns to spec-review channel."
    
  - agent: sysadmin
    task: "Technical feasibility check. Verify integration points, dependencies, system compatibility. Check similar implementations with axel search. Post technical notes to spec-review channel."
```

### Phase 3: Refined Implementation
**Mode:** chain

```yaml
chain:
  - agent: planner
    task: "Refine specification based on spec-review channel feedback: {previous}"
    
  - agent: implementer
    task: "Implement {feature} following refined spec: {previous}. Write clean, documented code. Include error handling and logging."
    
  - agent: tester
    task: "Write comprehensive tests for implementation: {previous}. Unit tests, integration tests, edge cases. Aim for >90% coverage."
```

### Phase 4: Testing & Hardening
**Mode:** parallel  
**Comms Channel:** testing-{timestamp}

```yaml
agents:
  - agent: pentester
    task: "Security test the implementation. Look for vulnerabilities, injection points, auth bypasses. Try to break it. Post findings to testing channel."
    
  - agent: heavy
    task: "Code quality review and refactoring. Improve structure, remove duplication, enhance readability. Post refactored sections to testing channel."
```

### Phase 5: Final Review
**Mode:** single

```yaml
agent: sysadmin
task: "Final technical review incorporating all testing feedback. Verify: spec compliance, test coverage, security fixes applied, code quality. Prepare deployment checklist: {previous}"
```

## Output Format
```markdown
# Feature: {feature}

## Implementation Summary
- Files changed: [list]
- Lines added/removed: X/Y
- Test coverage: X%

## API Documentation
[Generated API docs]

## Testing Results
- Unit tests: X passed
- Integration tests: Y passed
- Security scan: [status]

## Deployment Checklist
- [ ] Database migrations
- [ ] Config updates
- [ ] Documentation updates
- [ ] Monitoring setup

## Code Location
[File paths and key functions]
```

## Edge Cases
- **Spec too vague**: Return to Phase 1 with specific questions
- **Failed tests**: Loop Phase 3-4 until passing
- **Security issues**: Mandatory fix before proceeding
- **Integration conflicts**: Isolate and resolve with sysadmin