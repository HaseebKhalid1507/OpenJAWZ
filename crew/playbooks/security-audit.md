# Security Audit Playbook

## Trigger Phrases
- "security audit {target}"
- "pentest {target}"
- "check {target} for vulnerabilities"
- "security assessment of {target}"

## Phase Breakdown

### Phase 1: Reconnaissance
**Mode:** parallel  
**Comms Channel:** recon-{timestamp}

```yaml
agents:
  - agent: researcher
    task: "Map attack surface of {target}. Identify: entry points, APIs, authentication mechanisms, data flows, external dependencies. Use axel search for known vulnerabilities in dependencies. Post findings to recon channel."
    
  - agent: sysadmin
    task: "System enumeration of {target}. Check: permissions, configurations, exposed services, network topology, access controls. Document infrastructure. Post technical details to recon channel."
    
  - agent: implementer
    task: "Dependency and toolchain analysis of {target}. List all libraries, frameworks, versions. Search for CVEs using the web tool. Post vulnerability candidates to recon channel."
```

### Phase 2: Vulnerability Assessment
**Mode:** parallel  
**Comms Channel:** vulns-{timestamp}

```yaml
agents:
  - agent: pentester
    task: "Active security testing of {target}. Test: injection points (SQL/XSS/command), authentication bypass, authorization flaws, IDOR, session management. Coordinate via vulns channel to avoid conflicts. Document all findings with POC."
    
  - agent: optimizer
    task: "Logic and design flaw analysis of {target}. Find: race conditions, state confusion, business logic bypasses, architectural weaknesses. Use recon channel data. Post sophisticated attack vectors to vulns channel."
    
  - agent: debugger
    task: "Fuzzing and edge case testing of {target}. Test boundary conditions, malformed inputs, resource exhaustion. Try to trigger crashes or unexpected behavior. Post findings to vulns channel."
```

### Phase 3: Deep Analysis
**Mode:** chain

```yaml
chain:
  - agent: researcher
    task: "Analyze all findings from recon and vulns channels. Categorize by severity (Critical/High/Medium/Low), exploitability, and impact. Chain vulnerabilities for maximum effect: {previous}"
    
  - agent: reviewer
    task: "Devil's advocate review. Challenge severity ratings, find missed vectors, consider insider threats and supply chain attacks: {previous}"
```

### Phase 4: Report & Remediation
**Mode:** single

```yaml
agent: sysadmin
task: "Generate comprehensive security report from all findings: {previous}. Include: executive summary, detailed vulnerabilities with CVE/CWE mappings, proof of concepts, remediation steps, security hardening recommendations."
```

## Output Format
```markdown
# Security Audit: {target}

## Executive Summary
Risk Level: [Critical|High|Medium|Low]
Vulnerabilities Found: X Critical, Y High, Z Medium

## Critical Findings
### 1. [Vulnerability Name]
- **Type**: [CWE-XXX]
- **Location**: [file:line or endpoint]
- **Impact**: [What attacker can do]
- **POC**: ```[code]```
- **Fix**: [Specific remediation]

## Attack Surface Map
[Visual or structured representation]

## Remediation Priority
1. [Fix this first]
2. [Then this]
3. [etc]

## Security Hardening
- [Recommendation 1]
- [Recommendation 2]

## Positive Findings
[What's done well]
```

## Edge Cases
- **Access denied**: Document as finding, test from different angles
- **Rate limiting**: Coordinate agents via comms, slow down
- **Honeypots detected**: Note defensive measures, proceed carefully
- **Too many vulns**: Prioritize critical path and data exposure