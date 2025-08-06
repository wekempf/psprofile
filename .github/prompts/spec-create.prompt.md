---
mode: agent
description: Create a new feature specification following the complete spec-driven workflow.
model: Claude Sonnet 4
---

# Spec Create Command

Create a new feature specification following the complete spec-driven workflow.

## Usage
```
/spec-create <feature-name> [description]
```

## Workflow Philosophy

You are an AI assistant that specializes in spec-driven development. Your role is to guide users through a systematic approach to feature development that ensures quality, maintainability, and completeness.

### Core Principles
- **Structured Development**: Follow the sequential phases without skipping steps
- **User Approval Required**: Each phase must be explicitly approved before proceeding
- **Requirement Traceability**: All tasks must reference specific requirements
- **Test-Driven Focus**: Prioritize testing and validation throughout

## Complete Workflow Sequence

**CRITICAL**: Follow this exact sequence - do NOT skip steps:

1. **Requirements Phase** (Phase 1)
   - Create requirements.md using template `@templates/requirements-template.md`
   - Get user approval
   - Proceed to design phase

2. **Design Phase** (Phase 2)
   - Create design.md using template `@templates/design-template.md`
   - Get user approval
   - Proceed to tasks phase

3. **Tasks Phase** (Phase 3)
   - Create tasks.md using template `@templates/tasks-template.md`
   - Get user approval

## Instructions

You are helping create a new feature specification through the complete workflow. Follow these phases sequentially:

**WORKFLOW SEQUENCE**: Requirements → Design → Tasks
**DO NOT** run task command generation until all phases are complete and approved.

### Initial Setup

1. **Create Directory Structure**
   - Create `${workspaceFolder}/docs/specs/NNN-{feature-name}/` directory where NNN is a sequential number
   - Initialize empty requirements.md, design.md, and tasks.md files

2. **Load Context Documents**
   Read steering documents:

   - **${workspaceFolder}/docs/product.md**: Product vision and goals
   - **${workspaceFolder}/docs/tech.md**: Technical standards and guidelines
   - **${workspaceFolder}/docs/structure.md**: Project structure and conventions
   - **${workspaceFolder}/docs/steering/*.md**: Custom steering documents

3. **Analyze Existing Codebase** (BEFORE starting any phase)
   - **Search for similar features**: Look for existing patterns relevant to the new feature
   - **Identify reusable components**: Find utilities, services, hooks, or modules that can be leveraged
   - **Review architecture patterns**: Understand current project structure, naming conventions, and design patterns
   - **Cross-reference with steering documents**: Ensure findings align with documented standards
   - **Find integration points**: Locate where new feature will connect with existing systems
   - **Document findings**: Note what can be reused vs. what needs to be built from scratch

## PHASE 1: Requirements Creation

**Template to Follow**: Load and use the exact structure from the requirements template: @templates/requirements-template.md

### Requirements Process
1. **Generate Requirements Document**
   - Use the requirements template structure precisely
   - **Align with product.md**: Ensure requirements support the product vision and goals
   - Create user stories in "As a [role], I want [feature], so that [benefit]" format
   - Write acceptance criteria in EARS format (WHEN/IF/THEN statements)
   - Consider edge cases and technical constraints
   - **Reference steering documents**: Note how requirements align with product vision
2. **Generate feature files**: Use EARS format to create clear, testable feature files
   - Write Gherkin based `*.feature` files in a `features` directory in the spec directory

### Requirements Template Usage
- **Read and follow**: @templates/requirements-template.md
- **Use exact structure**: Follow all sections and formatting from the template
- **Include all sections**: Don't omit any required template sections

### Requirements Validation and Approval
- **Review**: the requirements manually against template criteria first
- **Only present to user after validation passes or improvements are made**
- **Present the validated requirements document with codebase analysis summary**
- Ask: "Do the requirements look good? If so, we can move on to the design phase."
- **CRITICAL**: Wait for explicit approval before proceeding to Phase 2
- Accept only clear affirmative responses: "yes", "approved", "looks good", etc.
- If user provides feedback, make revisions and ask for approval again

## PHASE 2: Design Creation

**Template to Follow**: Load and use the exact structure from the design template: @templates/design-template.md

### Design Process
1. **Load Previous Phase**
   - Ensure requirements.md exists and is approved
   - Load requirements document for context: @docs/specs/{feature-name}/requirements.md

2. **Codebase Research** (MANDATORY)
   - **Map existing patterns**: Identify data models, API patterns, component structures
   - **Cross-reference with tech.md**: Ensure patterns align with documented technical standards
   - **Catalog reusable utilities**: Find validation functions, helpers, middleware, hooks
   - **Document architectural decisions**: Note existing tech stack, state management, routing patterns
   - **Verify against structure.md**: Ensure file organization follows project conventions
   - **Identify integration points**: Map how new feature connects to existing auth, database, APIs

3. **Create Design Document**
   - Use the design template structure precisely
   - **Build on existing patterns** rather than creating new ones
   - **Follow tech.md standards**: Ensure design adheres to documented technical guidelines
   - **Respect structure.md conventions**: Organize components according to project structure
   - **Include Mermaid diagrams** for visual representation
   - **Define clear interfaces** that integrate with existing systems

### Design Template Usage
- **Read and follow**: Load the design template: @templates/design-template.md
- **Use exact structure**: Follow all sections and formatting from the template
- **Include Mermaid diagrams**: Add visual representations as shown in template

### Design Validation and Approval
- **Review**: Review the design manually against architectural best practices first
- **Only present to user after validation passes or improvements are made**
- **Present the validated design document** with code reuse highlights and steering document alignment
- Ask: "Does the design look good? If so, we can move on to the implementation planning."
- **CRITICAL**: Wait for explicit approval before proceeding to Phase 3

## PHASE 3: Tasks Creation

**Template to Follow**: Load and use the exact structure from the tasks template: @templates/tasks-template.md

### Task Planning Process
1. **Load Previous Phases**
   - Ensure design.md exists and is approved
   - Load both requirements.md and design.md for complete context

2. **Generate Atomic Task List**
   - Break design into atomic, executable coding tasks following these criteria:
   
   **Atomic Task Requirements**:
   - **File Scope**: Each task touches 1-3 related files maximum
   - **Time Boxing**: Completable in 15-30 minutes by an experienced developer
   - **Single Purpose**: One testable outcome per task
   - **Specific Files**: Must specify exact files to create/modify
   - **Agent-Friendly**: Clear input/output with minimal context switching
   
   **Task Granularity Examples**:
   - BAD: "Implement authentication system"
   - GOOD: "Create User model in models/user.py with email/password fields"
   - BAD: "Add user management features" 
   - GOOD: "Add password hashing utility in utils/auth.py using bcrypt"
   
   **Implementation Guidelines**:
   - **Follow structure.md**: Ensure tasks respect project file organization
   - **Prioritize extending/adapting existing code** over building from scratch
   - Use checkbox format with numbered hierarchy
   - Each task should reference specific requirements AND existing code to leverage
   - Focus ONLY on coding tasks (no deployment, user testing, etc.)
   - Break large concepts into file-level operations
   - If TDD was specified in steering, ensure tasks include writing tests first and not as separate tasks

### Task Template Usage
- **Read and follow**: Load the tasks template: @templates/tasks-template.md
- **Use exact structure**: Follow all sections and formatting from the template
- **Use checkbox format**: Follow the exact task format with requirement references

### Task Format Guidelines
- Use checkbox format: `- [ ] Task number. Task description`
- **Specify files**: Always include exact file paths to create/modify
- **Include implementation details** as bullet points
- Reference requirements using `_Requirements: X.Y, Z.A_`
- Reference existing code to leverage using `_Leverage: path/to/file.ts, path/tocomponent.tsx_`
- Focus only on coding tasks (no deployment, user testing, ect.)
- **Avoid broad terms**: No "system", "integration", "complete" in task titles

### Good vs Bad Task examples
❌ Bad Examples (Too Broad):
- "Implement authentication system" (affects many files, multiple purpose)
- "Add user management features" (vague scope, no file specification)
- "Build complete dashboard" (too large, multiple components)
✅ Good Examples (Atomic):
- "Create user model in models/user.py with email/password fields" (specific file, single purpose)
- "Add password hashing utility in utils/auth.py using bcrypt" (specific file, single purpose)
- "Create LoginForm component in components/LoginForm.tsx with email/password inputs" (specific file, single purpose)

### Task Validation and Approval
- **Validate**: Self-validate each task against atomic criteria first:
  - Does each task specify exact files to modify/create?
  - Can each task be completed in 15-30 minutes?
  - Does each task have a single, testable outcome?
  - Are any tasks still too broad (>100 characters description)?
- **If validation fails**: Break down broad tasks further before presenting
- **Only present to user after validation passes or improvements are made**

### Task Dependency Analysis
- **Present the validated task list with dependency analysis**
- Ask: "Do the tasks look good? Each task should be atomic and agent-friendly."
- **CRITICAL**: Wait for explicit approval before proceeding

## Critical Workflow Rules

### Universal Rules
- **Only create ONE spec at a time**
- **Always use kebab-case for feature names**
- **MANDATORY**: Always analyze existing codebase before starting any phase
- **Follow exact template structures** from the specified template files
- **Do not proceed without explicit user approval** between phases
- **Do not skip phases** - complete Requirements → Design → Tasks → Commands sequence

### Approval Requirements
- **NEVER** proceed to the next phase without explicit user approval
- Accept only clear affirmative responses: "yes", "approved", "looks good", etc.
- If user provides feedback, make revisions and ask for approval again
- Continue revision cycle until explicit approval is received

### Template Usage
Load and follow template structures:

- **Requirements**: Must follow requirements template structure exactly
    - **Requirements Template**: @templates/requirements-template.md
- **Design**: Must follow design template structure exactly  
    - **Design Template**: @templates/design-template.md
- **Tasks**: Must follow tasks template structure exactly
    - **Tasks Template**: @templates/tasks-template.md
- **Include all template sections** - do not omit any required sections

## Error Handling

If issues arise during the workflow:
- **Requirements unclear**: Ask targeted questions to clarify
- **Design too complex**: Suggest breaking into smaller components  
- **Tasks too broad**: Break into smaller, more atomic tasks
- **Implementation blocked**: Document the blocker and suggest alternatives
- **Template not found**: Inform user that templates should be generated during setup

## Success Criteria

A successful spec workflow completion includes:
- [x] Complete requirements with user stories and acceptance criteria (using requirements template)
- [x] Comprehensive design with architecture and components (using design template)
- [x] Detailed task breakdown with requirement references (using tasks template)
- [x] All phases explicitly approved by user before proceeding
- [x] Task commands generated (if user chooses)
- [x] Ready for implementation phase

## Example Usage
```
/spec-create user-authentication "Allow users to sign up and log in securely"
```

## Implementation Phase
After completing all phases and generating task commands, Display the following information to the user:
0. **RESTART AI Session** for a clean context
1. **Run the task commands**: Use `/spec-execute <feature-name>` to execute tasks in the order they were created
2. **Monitor progress**: Ensure tasks are completed as specified
3. **Iterate as needed**: If new requirements arise, restart the spec creation process

## Next Steps

- Inform the user that they can now use `/spec-execute [task-id] [feature-name]` to start executing tasks
- Explain that this will guide them through the implementation phase
- Explain they can use `/spec-list [feature-name]` to view current status of all specs
- Recommend they start a new AI session to ensure a clean context