## graphify

This project has a knowledge graph in Obsidian with god nodes, community structure, and cross-file relationships.

Canonical graphify path:
`/Users/danielbelini/Documents/_Workspace/Obsidian/claude/Projects/Enerzee/graphify-out/`

The project-local `graphify-out/` path, when present, must only be a symlink/compatibility pointer to the Obsidian path above. Do not keep graphify artifacts physically inside the Git project.

Rules:

- ALWAYS read `/Users/danielbelini/Documents/_Workspace/Obsidian/claude/Projects/Enerzee/graphify-out/GRAPH_REPORT.md` before reading any source files, running grep/glob searches, or answering codebase questions. The graph is your primary map of the codebase.
- IF `/Users/danielbelini/Documents/_Workspace/Obsidian/claude/Projects/Enerzee/graphify-out/wiki/index.md` EXISTS, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code, run `graphify update .` to keep the Obsidian graph current (AST-only, no API cost). If `graphify-out/` is missing, recreate it as a symlink to the canonical Obsidian path before updating.
