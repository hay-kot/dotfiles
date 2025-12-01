---
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git diff:*)
description: Review and iterate on an existing task plan, discussing trade-offs and design decisions with the user.
---

## Overview

Review the existing `PLAN.local.md` file in the repository root, analyze its quality and completeness, and collaborate with the user to improve it through discussion of trade-offs and design decisions.

## Review Process

### 1. Initial Assessment

Read and evaluate the current plan against these criteria:

- **Clarity**: Are the steps specific enough to execute without ambiguity?
- **Completeness**: Does the plan cover all aspects of the task?
- **Sequencing**: Are dependencies properly ordered? Are there steps that could be parallelized?
- **Risk Identification**: Are potential failure points and edge cases addressed?
- **Testability**: Does each step have clear validation criteria?
- **Scope**: Is the plan appropriately scoped, or does it over/under-engineer the solution?

### 2. Codebase Alignment Check

Verify the plan against the current repository state:

- Confirm referenced files and paths still exist
- Check for recent commits that may affect the plan
- Identify any new context that should inform the approach
- Flag any assumptions that may no longer hold

### 3. Gap Analysis

Identify what's missing or could be improved:

- Missing error handling considerations
- Unaddressed edge cases
- Opportunities for better abstraction or reuse
- Testing gaps
- Documentation needs

## Discussion Points

**Before suggesting changes, engage the user with specific questions about:**

### Architecture & Design Decisions

- Present alternative approaches you've identified and ask which aligns better with their goals
- Ask about constraints not mentioned in the plan (performance, backwards compatibility, etc.)
- Clarify intended scope boundaries—what's explicitly out of scope?

### Implementation Trade-offs

- Identify trade-offs in the current approach (e.g., simplicity vs. flexibility, speed vs. maintainability)
- Ask about acceptable compromises given timeline or resource constraints
- Discuss build-vs-buy decisions for any components

### Integration Concerns

- Ask how this work should interact with existing systems
- Clarify rollout strategy (feature flags, gradual rollout, etc.)
- Discuss backwards compatibility requirements

### Validation & Success Criteria

- Confirm what "done" looks like from the user's perspective
- Ask about priority of different requirements if trade-offs are needed
- Discuss acceptable test coverage levels

## Output Format

Structure your review as:

1. **Summary of Current Plan**
   - Brief overview of what the plan proposes
   - Overall assessment (1-2 sentences)

2. **Strengths**
   - What the plan does well
   - Approaches worth preserving

3. **Questions for Discussion**
   - Numbered list of specific questions requiring user input
   - Group by category (Design, Trade-offs, Validation, etc.)
   - Explain why each question matters for the implementation

4. **Suggested Improvements**
   - Hold detailed suggestions until after discussing questions with the user
   - Note areas you'll address once you have their input

## Instructions

1. Read `PLAN.local.md` thoroughly before making any assessments
2. Explore relevant parts of the codebase to validate your understanding
3. **Ask your questions before proposing changes**—user input should shape your recommendations
4. Be specific in your questions; avoid generic queries
5. After discussion, offer to update the plan with agreed-upon changes
6. Preserve the original plan structure unless the user wants it reorganized
