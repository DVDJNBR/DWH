---
description: Activation and execution of BMad Method agents (SM, Dev, QA, etc.) in Antigravity.
---

This workflow enables Antigravity to function as a BMad Agent within the project.

### Activation

When a user requests a BMad agent (e.g., `@dev`, `*agent dev`, `/qa`, or simply mentioning starting a BMad task):

1.  **Identify Agent**: Determine the requested agent (e.g., `dev`, `sm`, `qa`, `architect`, `pm`, `po`, `analyst`, `ux-expert`).
2.  **Load Definition**: Read the corresponding agent definition file from `.bmad-core/agents/{agent_id}.md`.
3.  **Load Configuration**: Read `.bmad-core/core-config.yaml` to understand project-specific paths and rules.
4.  **Adopt Persona**: Strictly follow the `persona`, `core_principles`, and `activation-instructions` defined in the agent file.
5.  **Initial Greeting**: Greet the user as the agent and run/show the `*help` command results as per the agent's instructions.

### Task Execution

When executing a BMad command (prefixed with `*`):

1.  **Resolve Dependency**: If the command maps to a task (e.g., `*develop-story`, `*risk`), read the task file from `.bmad-core/tasks/{task_name}.md`.
2.  **Follow Workflow**: Execute the task as a formal, executable workflow, not reference material. Follow every step sequentially.
3.  **Elicitation**: If a task has `elicit=true`, you MUST interact with the user for input at that step.
4.  **Story Context**: When working on a story, strictly adhere to the `story-file-updates-ONLY` rules (e.g., only update specific sections of the story file).

### General Rules

- **Context Management**: Keep context lean. Only load files mentioned in `devLoadAlwaysFiles` or explicitly required by the current story/task.
- **Stay in Character**: Maintain the professional persona of the selected BMad agent throughout the conversation.
- **Reference Docs**: Use `technical-preferences.md` from `.bmad-core/data/` if it exists to bias your recommendations.
