---
mode: agent
description: Execute specific tasks from the approved task list.
---

# Spec Execute Command

Execute specific tasks from the approved task list.

## Usage
```
/spec-execute [task-id] [feature-name] [continue]
```

## Phase Overview

**Your Role**: Execute tasks systematically with validation

This is Phase 4 of the spec workflow. Your goal is to implement individual tasks from the approved task list, one at a time.

## Instructions

1. **Prerequisites**
   - Ensure `tasks.md` exists and is approved
   - Load the spec documents: `requirements.md`, `design.md`, and `tasks.md`
   - **Load all steering documents** (if available) found in `${workspaceFolder}/docs/steering/`: `product.md`, `tech.md`, `structure.md` and custom steering documents `*.md`
   - Identify the specific task to execute

2. **Process**
   1. Load spec documents from `${workspaceFolder}/docs/specs/{feature-name}/` directory:
      - Load `requirements.md`, `design.md`, and `tasks.md` for complete context
   2. **CRITICAL**: Mark the task and sub-tasks as in progress ([~])
   3. Execute ONLY the specified task (never multiple tasks)
   4. Implement following existing code patterns and conventions
   5. Validate implementation against referenced requirements
   6. **CRITICAL**: Mark task or sub-task as complete using the ([X])
   7. Confirm task completion status to user
   8. **CRITICAL**: Stop and wait for user review before proceeding

3. **Task Execution**
   - Focus on ONE task at a time
   - If task has sub-tasks, start with those
   - Follow the implementation details from design.md
   - Verify against requirements specified in the task

4. **Implementation Guidelines**
   - Write clean, maintainable code
   - **Follow steering documents**: Adhere to patterns in tech.md and conventions in structure.md
   - Follow existing code patterns and conventions
   - Include appropriate error handling
   - Add unit tests where specified
   - Document complex logic

5. **Validation**
   - Verify implementation meets acceptance criteria
   - Run tests if they exist
   - Check for lint/type errors and warnings
   - Ensure integration with existing code

6. **Task Completion Protocol**
When completing any task during `/spec-execute`:
   1. **Mark task complete**: Change the status to [X]
   2. **Confirm to user**: State clearly "Task X has been marked as complete"
   3. **If and ONLY if `continue` flag is provided**:
      - Goto step 2 to execute the next task
   4. **Otherwise Stop execution**: Do not proceed to next task automatically
   5. **Wait for instruction**: Let user decide next steps

## Critical Workflow Rules

### Task Execution
- **ONLY** execute one task at a time during implementation
- **CRITICAL**: Mark in progress tasks using [~]
- **CRITICAL**: Mark completed tasks using [X]
- **ALWAYS** stop after completing a task
- **NEVER** automatically proceed to the next task
- **MUST** wait for user to request next task execution
- **CONFIRM** task completion status to user

### Requirement References
- **ALL** tasks must reference specific requirements using _Requirements: X.Y_ format
- **ENSURE** traceability from requirements through design to implementation
- **VALIDATE** implementations against referenced requirements

## Task Selection
If no task-id specified:
- Look at tasks.md for the spec
- Recommend the next pending task
- Ask user to confirm before proceeding
- If the user confirms, execute the task

If no feature-name specified:
- Check `${workspaceFolder}/docs/specs/` directory for available specs
- If only one spec exists, use it
- If multiple specs exist, ask user which one to use
- Display error if no specs are found

## Examples
```
/spec-execute 1 user-authentication
/spec-execute 2.1 user-authentication
/spec-execute user-authentication
/spec-execute
```

## Important Rules
- Only execute ONE task at a time
- **ALWAYS** mark tasks as in progress [~] or complete [X]
- Always stop after completing a task
- Wait for user approval before continuing
- Never skip tasks or jump ahead
- Confirm task completion status to user

## Next Steps
After task completion, you can:
- Review the implementation
- Address any issues identified in the review
- Run tests if applicable
- If there are more tasks:
   - Inform the user of the next task to execute and the command they can use `/spec-execute [next-task-id] [feature-name]`
   - Inform the user they can check the overall progress with `/spec-list [feature-name]`
- If all tasks are complete:
   - Inform the user they should start a new AI session to ensure a clean context