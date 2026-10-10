---
name: notebooklm-memory
description: "Long-term, citation-grounded memory for Hermes using a Google NotebookLM (Gemini Notebook) 'Master Brain' notebook via the notebooklm-mcp-cli MCP server. Recall before answering, write back durable facts, and refuse to guess (anti-hallucination)."
version: 0.1.0
author: Addhe Warman Putra (Awan)
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [memory, long-term-memory, notebooklm, gemini-notebook, mcp, anti-hallucination, grounding, second-brain]
prerequisites:
  commands: [nlm]
---

# NotebookLM Memory (Master Brain)

Use one NotebookLM notebook, the **Master Brain**, as your long-term memory.
NotebookLM answers only from the sources in that notebook and cites them, so you get recall that comes with evidence.

Division of labour:

| Layer | What lives there | Size |
|---|---|---|
| Hermes built-in memory (`MEMORY.md` / `USER.md`) | Hot cache: identity, current priorities, the Master Brain notebook ID | small, always in context |
| **Master Brain notebook** | Durable history: decisions, facts, configs, incidents, preferences, project notes | large, queried on demand |
| Live system (shell, APIs) | Current truth about running systems | always re-check |

## Prerequisites

The full setup is in `references/setup.md`. Briefly:

- `notebooklm-mcp-cli` is installed and provides `nlm` and `notebooklm-mcp`.
- `nlm login --check` passes.
- The MCP server is registered in `~/.hermes/config.yaml` under `mcp_servers:` (example: `gemini_notebook_mcp`).
- Hermes exposes the tools prefixed with the server name, e.g. `mcp_gemini_notebook_mcp__notebook_query`. In this skill, tools are referred to by their short names (`notebook_query`, `source_add`, ...).
- The Master Brain notebook ID is known: stored in Hermes memory as `master_brain_notebook_id`, or in the env var `NLM_MEMORY_NOTEBOOK`.
  - If neither is set, call `notebook_list` and look for a notebook titled `Hermes Master Brain`.
  - Only call `notebook_create` with that title if the user agrees. Then save the ID to Hermes memory.

If the tools are missing or auth fails, follow **Failure handling** below. Never pretend recall worked.

## When to Use

- The user asks about anything from the past: "kemarin kita putuskan apa?", "what network does staging use?", "which model did we pick?", "what's my preference for X?"
- Before you state a project-specific fact (IDs, IPs, hostnames, versions, names, dates, decisions) that is not in the current conversation or in tool output from this session.
- At the start of a substantial task on a known project, to load prior decisions and known pitfalls.
- At the end of a session, or right after something worth remembering happens, to write it back.
- When the user says "ingat ini", "remember this", "catat", or "save to memory".

## When NOT to Use

- General knowledge questions that don't depend on the user's history.
- Live state you can check directly (service status, disk usage, current config). Run the command instead. Memory is historical and may be stale.
- Secrets. Never write or query tokens, passwords, API keys, cookies, private keys or credential files. See **Privacy**.
- Trivial chit-chat. Every query costs NotebookLM quota.

## Protocol 1: Recall (read)

1. **Formulate a self-contained question.** Include the project or topic name and ask for evidence explicitly:

   ```
   notebook_query(
     notebook_id=<master_brain>,
     query="Based only on the sources: <question about topic X>. Cite the source titles and dates. If the sources do not contain the answer, reply exactly: NOT_FOUND."
   )
   ```

   For large notebooks or long questions, use `notebook_query_start` and poll `notebook_query_status`.

2. **Interpret the result.**
   - Answer with citations: use it, and attribute it ("menurut catatan 2026-10-10 …").
   - `NOT_FOUND`, or no citations: treat it as **unknown**. Do not fill the gap from your own guesses.
   - Conflicting sources: prefer the most recent dated entry, mention the conflict, and offer to record a correction.

3. **Verify when possible.** If the memory is about something checkable (a config value, a running service), confirm with a live command before acting on it, then answer from the live result.

4. **Keep it cheap.** Batch related questions into one query. Don't re-query something you already recalled this session.

## Protocol 2: Write-back (remember)

Write only **durable, useful** knowledge, such as:

- decisions and their reasons
- final configurations
- names, IDs, endpoints
- incident root causes and fixes
- user preferences
- commitments and TODOs
- corrections to earlier memory

Do **not** write raw chat logs, speculation, or anything unverified.

Use **text sources** (not notes) so the content is part of what `notebook_query` is grounded on:

```
source_add(
  notebook_id=<master_brain>,
  source_type="text",
  title="mem/2026-10-10/mastercontrol-hermes-migration",
  text=<entry in the format below>,
  wait=True
)
```

Entry format (one topic per source; keep it under ~1 page):

```markdown
# <Topic title>
date: 2026-10-10
project: <project or "personal">
type: decision | fact | config | incident | preference | todo | correction
supersedes: <title of older entry, or "none">

## Summary
<2-5 sentences, plain facts>

## Details
- <key: value facts, exact names/IDs/versions>

## Evidence
- <how this was verified: command output, user statement, document link>
```

Rules:

- **Title convention:** `mem/<YYYY-MM-DD>/<project>-<topic>`. It must be unique, descriptive and greppable.
- **Append-only:** never call `source_delete`, `notebook_delete` or rename/overwrite tools on the Master Brain without explicit user confirmation in this conversation.
- **Corrections:** add a new entry with `type: correction` and `supersedes: <old title>`. Don't edit history.
- **Report the write:** tell the user briefly ("📝 dicatat ke Master Brain: <title>").
- **If `source_add` fails:** say so. Don't claim it was saved. The CLI fallback is `scripts/memory-write.sh`.

### End-of-session wrap-up

When a substantial session ends (or the user says "wrap up" / "selesai"):

1. List 1-5 durable items from the session (decisions, configs, fixes, preferences, open TODOs).
2. Show the list to the user.
3. On approval, or immediately if the user has asked for auto-save, write each one as a source.

## Protocol 3: Anti-hallucination gate

Before sending any answer that contains project-specific facts, check every claim. It must come from one of these, and you should be able to name which:

1. **Memory**: a cited Master Brain source (give the title/date).
2. **Live evidence**: tool or command output from this session.
3. **The user**: stated in this conversation.
4. **General knowledge**: not specific to the user's systems.

If a claim fits none of these, it is **unknown**:

- Say "tidak tahu" / "belum tercatat di memori" / "I don't have that recorded".
- Offer to check live or to record it once the user confirms it.
- **Never invent** IDs, IPs, hostnames, ports, versions, file paths, people, dates or past decisions.

Never report success ("berhasil", "done", "saved", "deployed") without output that proves it.

## Privacy

Everything you write is stored in the user's Google account.

- **Redact before writing.** Replace secrets with `<REDACTED>`: tokens, API keys, passwords, cookies, private keys, OAuth codes, full credit-card or ID numbers.
- Never read, print or upload the contents of `~/.notebooklm-mcp-cli/`, browser profiles, `.env` files or vaults.
- Don't store third parties' personal data unless the user explicitly asks.

## Quota & limits

- NotebookLM has per-account rate limits (rolling windows) and a per-notebook source cap that depends on the account tier.
  - Check with `usage_get` (MCP) or `nlm usage` (CLI) before bulk operations.
- On HTTP 429 or quota errors: stop, tell the user, and don't retry in a loop.
- When the notebook nears its source cap, propose a **consolidation**:
  - merge old `mem/<date>/…` entries into `mem/archive/<YYYY-MM>/<project>` summaries;
  - delete the originals only after the user confirms.
- Or start `Hermes Master Brain 2` and record its ID in Hermes memory.

## Failure handling

| Symptom | What to do |
|---|---|
| MCP tools not available / 0 tools | Recall is **unavailable**: say so. Suggest `scripts/nlm-healthcheck.sh` and `references/troubleshooting.md`. |
| Auth expired / 401 / "session expired" | Ask the user to run `nlm login` (or `nlm auth refresh` on servers). Never ask them to paste cookies into chat. |
| Timeout on query | Retry once with `notebook_query_start` + polling; if it still fails, report it. |
| Recall unavailable but user needs an answer | Answer only from live evidence or this conversation, and say explicitly that long-term memory couldn't be checked. |

## Quick Reference

| Need | MCP tool | CLI fallback |
|---|---|---|
| Find Master Brain | `notebook_list` | `nlm notebook list --json` |
| Recall | `notebook_query` | `nlm notebook query <id> "<q>" --json` |
| Long recall | `notebook_query_start` / `notebook_query_status` | — |
| Remember | `source_add` (`source_type="text"`) | `scripts/memory-write.sh` |
| What's stored | `notebook_get` | `nlm source list <id>` |
| Quota | `usage_get` | `nlm usage` |
| Health | — | `scripts/nlm-healthcheck.sh` |
