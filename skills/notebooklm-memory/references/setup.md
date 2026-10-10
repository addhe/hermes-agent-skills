# Setup: NotebookLM MCP for Hermes

Tested with Hermes Agent v0.21.x and `notebooklm-mcp-cli` v0.15.x. NotebookLM is now branded "Gemini Notebook", and the package name is unchanged.

> [!WARNING]
> `notebooklm-mcp-cli` is an **unofficial** client that uses NotebookLM's internal web API. It can break when Google changes things, and heavy automated use may get an account rate-limited. A dedicated Google account for your agent is recommended.

## 1. Install the CLI and MCP server

```bash
# uv: https://docs.astral.sh/uv/
curl -LsSf https://astral.sh/uv/install.sh | sh

uv tool install notebooklm-mcp-cli      # provides `nlm` and `notebooklm-mcp`
which nlm notebooklm-mcp && nlm --version
```

If `nlm` is not found, add `~/.local/bin` to `PATH` (or run `uv tool update-shell`).

## 2. Log in

### Desktop (has a browser)

```bash
nlm login            # opens a browser; sign in to Google
nlm login --check    # must report an active session
nlm usage            # quota baseline
```

### Headless server / VM

There is no browser on the server, so pick one of these options.

- **A. Copy a plain-file login from a desktop.**
  1. On the desktop, log in with plain-file storage: `nlm login --storage file`.
  2. Copy the **whole** `~/.notebooklm-mcp-cli/` directory, not just `cookies.json`:

     ```bash
     tar czf nlm-cred.tar.gz -C ~ .notebooklm-mcp-cli
     scp nlm-cred.tar.gz agent@server:~/
     ```

  3. On the server, unpack it and lock down the permissions:

     ```bash
     tar xzf ~/nlm-cred.tar.gz -C ~ && rm ~/nlm-cred.tar.gz
     chown -R "$(id -u):$(id -g)" ~/.notebooklm-mcp-cli
     chmod 700 ~/.notebooklm-mcp-cli
     find ~/.notebooklm-mcp-cli -type f -exec chmod 600 {} +
     nlm login --check
     ```

  Protected (keychain) storage is tied to the desktop's OS keystore and **will not work** after copying. Use `--storage file` for anything you copy to a server.

  Browser cookie databases are encrypted per-OS. If the server can't use the copied Chrome profile, `nlm auth refresh` will fail there. In that case use option B or C.

- **B. Manual cookie import:** `nlm login --manual --file cookies.txt`, run on the server. The file must be transferred securely and deleted afterwards.

- **C. Log in on the server itself:** install Chrome or Chromium on the server and run `nlm login` through a remote-desktop session or a forwarded DevTools port.

Keep the session alive on unattended machines (cron or a systemd timer):

```cron
*/30 * * * * $HOME/.local/bin/nlm auth refresh >/dev/null 2>&1
```

> [!CAUTION]
> `~/.notebooklm-mcp-cli/` is equivalent to a logged-in Google session. Never commit it, paste it into chat, or put it in a world-readable location. If you automate deployment, encrypt it (e.g. ansible-vault, sops).

## 3. Register the MCP server in Hermes

Write the block directly into `~/.hermes/config.yaml`. Keys are snake_case (`mcp_servers:`); the camelCase `mcpServers` JSON printed for Claude Desktop is **not** the Hermes format.

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak.$(date +%Y%m%d_%H%M%S)
```

```yaml
mcp_servers:
  gemini_notebook_mcp:
    command: "notebooklm-mcp"     # or an absolute path, e.g. /home/agent/.local/bin/notebooklm-mcp
    args: []
    timeout: 300
    connect_timeout: 60
    tools:
      resources: false
      prompts: false
```

Notes:

- **Use underscores in the server name.** Hermes builds tool names as `mcp_<server>__<tool>`, so this becomes `mcp_gemini_notebook_mcp__notebook_query`.
- **Run only one** NotebookLM MCP server per Google account. Two servers with overlapping tool names confuse the agent.
- **Gateway PATH:** if Hermes runs as a systemd service, its `PATH` may not include `~/.local/bin`. Use the absolute path in `command`.
- **If `hermes mcp add` fails** with "Connection closed" on some Hermes versions, writing the YAML by hand as shown above works.

Then validate and test:

```bash
python3 -c "import yaml,os; yaml.safe_load(open(os.path.expanduser('~/.hermes/config.yaml')))" && echo YAML OK
hermes mcp test gemini_notebook_mcp
```

In a running chat, reload with `/reload-mcp`, or restart the gateway service.

## 4. Install this skill

```bash
git clone https://github.com/addhe/hermes-agent-skills.git ~/hermes-agent-skills
```

Then add the repo's `skills/` directory to `~/.hermes/config.yaml`:

```yaml
skills:
  external_dirs:
    - ~/hermes-agent-skills/skills
```

On shared or production hosts, keep the clone read-only for the agent user (e.g. owned by root under `/opt/hermes-agent-skills`), so the agent can't modify its own skills.

The upstream tool-reference skill is optional but recommended:

```bash
nlm skill install hermes
```

## 5. Create the Master Brain

You can ask the agent to do this:

> "Buat notebook NotebookLM bernama 'Hermes Master Brain' untuk long-term memory dan simpan ID-nya di memory."

Or do it from the CLI:

```bash
nlm notebook create "Hermes Master Brain"
nlm notebook list --json     # copy the id
```

Then tell Hermes the ID, either in chat ("simpan master_brain_notebook_id = …") or by setting `NLM_MEMORY_NOTEBOOK=<id>` in `~/.hermes/.env`.

Optional: seed it from existing notes with `scripts/seed-memory.sh`.

## 6. Verify

```bash
bash ~/hermes-agent-skills/skills/notebooklm-memory/scripts/nlm-healthcheck.sh
```

The check passes only if all of these hold:

- auth is active;
- the MCP server reports **more than 0 tools** ("connected but 0 tools" counts as a failure, not a pass);
- a read-only `notebook list` succeeds.
