# Troubleshooting

| # | Symptom | Likely cause | Fix |
|---|---|---|---|
| 1 | `nlm: command not found` | `~/.local/bin` is not on `PATH`; this is common for systemd services | `uv tool update-shell`, or use absolute paths in `config.yaml` |
| 2 | `nlm login --check` fails / "session expired" / 401 | Google cookies expired or were revoked | `nlm auth refresh`; if that fails, run `nlm login` again (desktop) and re-copy to the server |
| 3 | Login works on the desktop but not after copying to the server | Protected (keychain) storage, or only `cookies.json` was copied | Log in again with `nlm login --storage file` and copy the **whole** `~/.notebooklm-mcp-cli/` |
| 4 | Permission denied reading credentials | Wrong owner/UID after extracting the tarball | `chown -R $(id -u):$(id -g) ~/.notebooklm-mcp-cli` |
| 5 | Hermes fails to start / YAML error | Tabs or bad indentation in `config.yaml` | Validate with `python3 -c "import yaml; ..."`, then restore the `.bak` |
| 6 | MCP "connected" but 0 tools | `tools:` filter too strict, or a broken server install | Remove `include`/`exclude` filters, `uv tool upgrade notebooklm-mcp-cli`, `/reload-mcp` |
| 7 | Duplicate / confusing tools | Two NotebookLM MCP servers registered | Keep only one server per account |
| 8 | `hermes mcp add` → "Connection closed" | Quick-detect quirk in some Hermes versions | Write the `mcp_servers:` YAML by hand |
| 9 | 429 / quota exceeded | Rate limit (rolling window) or weekly cap | Check `nlm usage`, wait, and reduce query frequency |
| 10 | Query timeout | Many or large sources | Use `notebook_query_start` + `notebook_query_status`, or pass a longer `timeout` |
| 11 | Recall answers don't include something the agent "saved" | It was saved as a **note**, not a source, or `source_add` failed | Save as a `source_type="text"` source and check with `nlm source list <id>` |
| 12 | "Source limit reached" | Per-notebook source cap for the account tier | Consolidate old `mem/…` entries into monthly archives, or start a second notebook |

After a rollback (restoring `config.yaml.bak`):

```bash
python3 -c "import yaml,os; yaml.safe_load(open(os.path.expanduser('~/.hermes/config.yaml')))"
pkill -f notebooklm-mcp || true
# then /reload-mcp in chat, or restart the gateway service
```
