# Troubleshooting (quick)

| Symptom | Try |
|---|---|
| `nlm: command not found` | Add `~/.local/bin` to `PATH`, or use an absolute path in `config.yaml` |
| Session expired / 401 | `nlm login` again |
| MCP tools not showing up | `hermes mcp test gemini_notebook_mcp`, then `/reload-mcp` |
| 429 / quota | `nlm usage`, wait, and query less often |
| Saved memory not recalled | Make sure it was saved as a **text source** (`source_add`), not a note |

For more help, see the official [`notebooklm-mcp-cli` docs](https://github.com/jacob-bd/notebooklm-mcp-cli/tree/main/docs) or ask in [t.me/HermesAgentIndonesia](https://t.me/HermesAgentIndonesia).
