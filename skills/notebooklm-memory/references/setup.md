# Setup: NotebookLM MCP for Hermes

This page covers the minimal setup. For details, see the official [`notebooklm-mcp-cli` docs](https://github.com/jacob-bd/notebooklm-mcp-cli). NotebookLM is now branded "Gemini Notebook".

> [!WARNING]
> `notebooklm-mcp-cli` is an **unofficial** client. It can break when Google changes things, and heavy automated use may get an account rate-limited. A dedicated Google account is recommended.

## 1. Install and log in

```bash
uv tool install notebooklm-mcp-cli   # provides `nlm` and `notebooklm-mcp`
nlm login                            # opens a browser; sign in to Google
nlm login --check
```

For servers without a browser, see the [authentication docs](https://github.com/jacob-bd/notebooklm-mcp-cli/blob/main/docs/AUTHENTICATION.md).

> [!CAUTION]
> `~/.notebooklm-mcp-cli/` is equivalent to a logged-in Google session. Never commit it or paste it into chat.

## 2. Register the MCP server

Add this to `~/.hermes/config.yaml` (see [examples/config.yaml](../../../examples/config.yaml)):

```yaml
mcp_servers:
  gemini_notebook_mcp:
    command: "notebooklm-mcp"
    args: []
    timeout: 300
```

Then test the server:

```bash
hermes mcp test gemini_notebook_mcp
```

Finally, run `/reload-mcp` in chat or restart Hermes.

## 3. Install this skill

```bash
git clone https://github.com/addhe/hermes-agent-skills.git ~/hermes-agent-skills
```

Then add the repo's `skills/` directory to `~/.hermes/config.yaml`:

```yaml
skills:
  external_dirs:
    - ~/hermes-agent-skills/skills
```

## 4. Create the Master Brain

Ask the agent:

> "Buat notebook NotebookLM bernama 'Hermes Master Brain' untuk long-term memory dan simpan ID-nya di memory."

Or set `NLM_MEMORY_NOTEBOOK=<notebook id>` in `~/.hermes/.env`.

To check that everything works, run `scripts/nlm-healthcheck.sh`.

---

📘 **Production setup guide:** headless VM auth, Hermes-specific pitfalls, a hardened setup prompt, and an incident runbook. It's available through the **Hermes Agent Indonesia** community: [t.me/HermesAgentIndonesia](https://t.me/HermesAgentIndonesia).
