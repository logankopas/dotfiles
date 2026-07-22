# Research CodeCompanion prompt

## Purpose

A CodeCompanion prompt library entry that, given a topic, researches it across
the local repository and the web, follows important threads, and writes a
summarized report with references and technical appendices — without ever
blocking on a tool-approval prompt.

## Trigger

New file: `prompts/research.md`, following the existing markdown prompt
convention (see `prompts/fix.md`, `prompts/explain.md`).

```yaml
name: Research topic
interaction: chat
description: Research a topic across the local repo and the web, write a summarized report with references
opts:
  alias: research
  is_slash_cmd: true
  user_prompt: true
  auto_submit: true
```

- Action Palette entry — `user_prompt: true` opens an input box asking for the
  topic before the chat is created.
- `/research <topic>` — usable inline inside an already-open chat.
- Runs as a normal chat interaction through the existing ACP `claude_code`
  adapter(s) — same tool/permission model as an interactive Claude Code
  session, not the separate terminal-based `CodeCompanionCLI` path.

## System prompt behavior

1. **Local track** — use `Read`/`Grep`/`Glob` plus read-only git inspection
   (`log`, `show`, `blame`, `diff`) against the current project for relevant
   code, comments, ADRs, and existing docs.
2. **Web track** — use `WebSearch` and `WebFetch` to find official docs,
   source, and community discussion. Follow secondary links (RFCs, issues,
   changelogs) that materially affect the answer, rather than stopping at the
   first hit.
3. Explicitly restricted to non-interactive tools: no `Edit`, no `Bash` beyond
   safe read-only inspection commands, no `Write` except the single output
   file.
4. Output: write `~/notes/research/<YYYY-MM-DD>-<kebab-case-slug>.md`, dated
   using the model's own session context (no extra date tooling needed),
   structured as:
   - **Summary** — a short, standalone answer to the topic
   - **References** — every source consulted
   - **Appendices** — one per thread followed, holding the technical detail
5. The final chat reply states the file's full path only (not the report
   body). The user opens it by placing the cursor on the path and pressing
   `gf` — no auto-open automation, to avoid guessing which chat interactions
   are "research" ones.

No adapter/model is forced in the prompt; it uses whatever's active in the
chat (switchable with `ga` as usual).

## Permission changes (`~/.claude/settings.json`, global)

Add to `permissions.allow`:

- `WebSearch`
- `Write(~/notes/research/**)`
- `WebFetch(domain:...)` for, in addition to the existing
  `codecompanion.olimorris.dev` and `raw.githubusercontent.com`:
  - Code hosting / packages: `github.com`, `gitlab.com`, `pypi.org`, `npmjs.com`
  - General reference: `developer.mozilla.org`, `stackoverflow.com`,
    `discuss.python.org`
  - Python/Django/web stack: `docs.python.org`, `docs.djangoproject.com`,
    `django-ninja.dev`, `docs.pydantic.dev`, `flask.palletsprojects.com`,
    `werkzeug.palletsprojects.com`
  - Frontend: `react.dev`, `redux.js.org`
  - Infra: `docs.celeryq.dev`, `www.postgresql.org`, `docs.docker.com`,
    `kubernetes.io`, `cloud.google.com`, `developer.hashicorp.com`
  - Community: `community.plotly.com`

These are global settings, so they cover both interactive Claude Code CLI use
and ACP sessions spawned from Neovim (same binary, same config).

## Out of scope

- Automatic buffer-opening after the report is written (rejected in favor of
  `gf` — simpler, and avoids inferring which chat sessions count as
  "research" ones).
- Forcing a specific adapter/model for this prompt.
- Changes to the `CodeCompanionCLI` terminal-agent path — this prompt only
  uses the chat/ACP path.
