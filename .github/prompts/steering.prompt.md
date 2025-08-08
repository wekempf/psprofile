---
mode: agent
description: Create or update steering documents that provide persistent project context.
model: Claude Sonnet 4
---

# Spec Steering Setup Command

Create or update steering documents that provide persistent project context.

## Usage
```
/steering [description]

# or

/steering add <document-name> [description]
```

## Instructions

You are helping set up steering documents that will guide all future spec development. These documents provide persistent context about the product vision, technology stack, and project structure.

This command can be run multiple times to refine or update the steering documents. If a document already exists, you should load its content and incorporate any new information provided in the description.

This command has two modes: `/steering [descripton]` to create or update standard steering documents, and `/steering add <document-name> [description]` to create or update a specific (possibly new) document.

## Process for `/steering [description]`

1. **Check for Existing Steering Documents**
   - Look for `@{workspaceFolder}/docs/steering/` directory
   - Check for existing product.md, tech.md, structure.md files
   - If they exist, load and display current content
   - Include information from the user supplied description

2. **Analyze the Project**
   - Review the codebase to understand:
     - Project type and purpose
     - Technology stack in use
     - Directory structure and patterns
     - Coding conventions
     - Existing features and functionality
   - Look for:
     - package.json, requirements.txt, go.mod, etc.
     - README files
     - Configuration files
     - Source code structure

3. **Present Inferred Details**
   - Show the user what you've learned about:
     - **Product**: Purpose, features, target users
     - **Technology**: Frameworks, libraries, tools
     - **Structure**: File organization, naming conventions
   - Format as:
     ```
     Based on my analysis, here's what I've inferred:
     
     **Product Details:**
     - [Inferred detail 1]
     - [Inferred detail 2]
     
     **Technology Stack:**
     - [Inferred tech 1]
     - [Inferred tech 2]
     
     **Project Structure:**
     - [Inferred pattern 1]
     - [Inferred pattern 2]
     ```
   - Ask: "Do these inferred details look correct? Please let me know which ones to keep or discard."

4. **Gather Missing Information**
   - Based on user feedback, identify gaps
   - Ask targeted questions to fill in missing details:
     
     **Product Questions:**
     - What is the main problem this product solves?
     - Who are the primary users?
     - What are the key business objectives?
     - What metrics define success?
     
     **Technology Questions:**
     - Are there any technical constraints or requirements?
     - What third-party services are integrated?
     - What are the performance requirements?
     
     **Structure Questions:**
     - Are there specific coding standards to follow?
     - How should new features be organized?
     - What are the testing requirements?

5. **Generate Steering Documents**
   - Create `${workspaceFolder}/docs/steering/` directory if it doesn't exist
   - Generate three files based on templates and gathered information:
     
     **product.md**: Product vision, users, features, objectives (`@templates/product-template.md`)
     **tech.md**: Technology stack, tools, constraints, decisions (`@templates/tech-template.md`)
     **structure.md**: File organization, naming conventions, patterns (`@templates/structure-template.md`)

6. **Review and Confirm**
   - Present the generated documents to the user
   - Ask for final approval before saving
   - Make any requested adjustments

## Important Notes

- **Steering documents are persistent** - they will be referenced in all future spec commands
- **Keep documents focused** - each should cover its specific domain
- **Update regularly** - steering docs should evolve with the project
- **Never include sensitive data** - no passwords, API keys, or credentials

## Example Flow

1. Analyze project and find it's a React/TypeScript app
2. Present inferred details about the e-commerce platform
3. User confirms most details but clarifies target market
4. Ask about performance requirements and third-party services
5. Generate steering documents with all gathered information
6. User reviews and approves the documents
7. Save to `${workspaceFolder}/docs/steering/` directory

## Process for `/steering add <document-name> [description]`

1. **Check for Existing Document**
   - Look for `@{workspaceFolder}/docs/steering/<document-name>.md`
   - If it exists, load and display current content
2. **Create or Update Content**
   - Include information from the user supplied description

## Next Steps

- Inform the user that they are ready to use `/spec-create <feature-name> [description]` to start defining features
- Explain that these steering documents will guide all future spec development
- Recommend they start a new AI session to ensure a clean context