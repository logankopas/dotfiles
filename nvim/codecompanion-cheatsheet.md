# CodeCompanion Cheatsheet

Reflects the setup in `init.lua`. Default adapter is `claude_code`, an ACP
adapter that drives the Claude Code CLI (uses your Claude Code subscription,
not the Anthropic API directly).

Full docs: https://codecompanion.olimorris.dev/

## Model-specific agents

Five ACP adapters are registered, all wrapping the same Claude Code CLI —
only the pinned model differs:

| Adapter name          | Model           |
|------------------------|-----------------|
| `claude_code`          | CLI default     |
| `claude_code_opus`     | Opus 4.8        |
| `claude_code_sonnet`   | Sonnet 5        |
| `claude_code_haiku`    | Haiku 4.5       |
| `claude_code_fable`    | Fable 5         |

Ways to use one:
- Mid-chat: press `ga` in the chat buffer to pick a different adapter/model.
- Directly: `:CodeCompanionChat adapter=claude_code_opus`
- Toggle a chat with one: `:CodeCompanionChat Toggle adapter=claude_code_haiku`

**Example** — quick lookup on Haiku, then escalate to Opus for a hard
refactor without losing the conversation:
```
:CodeCompanionChat Toggle adapter=claude_code_haiku
" ... ask your question, get an answer ...
" now press `ga` in the chat buffer and pick claude_code_opus
" continue the same conversation on the bigger model
```

## Global keymaps (already in `init.lua`)

| Key                | Mode | Action                              |
|---------------------|------|--------------------------------------|
| `<Leader>ca`        | n, v | Open the action palette (`:CodeCompanionActions`) |
| `<Leader>cm`        | n, v | Toggle the chat buffer (`:CodeCompanionChat Toggle`) |
| `<Leader>cc`        | n, v | Open the CLI interaction (`:CodeCompanionCLI`) |
| `ga`                | v    | Add the visual selection to the chat (`:CodeCompanionChat Add`) |

Command-line abbreviations: typing `cc`, `ccm`, `ccc` expand to
`CodeCompanion`, `CodeCompanionChat`, `CodeCompanionCLI` respectively.

Note: `ga` above is a **visual-mode** global mapping. Inside the chat buffer
itself, `ga` in **normal** mode is CodeCompanion's own "change adapter/model"
keymap (see below) — different mode, so no clash.

**Example** — ask about a chunk of code without leaving the file:
```
" 1. Visually select the confusing lines with V or v
" 2. Press `ga` — this runs :CodeCompanionChat Add and opens/updates the chat
"    with the selection already inserted as a #buffer reference
" 3. Type your question below it and send with <CR>
Why does this loop never terminate?
```

## Chat buffer keymaps (buffer-local, only active inside a chat buffer)

| Key            | Mode | Action                                  |
|----------------|------|-------------------------------------------|
| `<CR>`, `<C-s>`| n    | Send message                              |
| `<C-s>`        | i    | Send message                              |
| `<C-_>`        | i    | Open completion menu (`#`/`/`/`@`/`\`)    |
| `<C-c>`        | n, i | Close the chat buffer                     |
| `q`            | n    | Stop the current request                  |
| `gr`           | n    | Regenerate the last response              |
| `gx`           | n    | Clear all messages from the chat          |
| `gc`           | n    | Insert an empty codeblock                 |
| `gy`           | n    | Yank code from the last codeblock         |
| `gba`          | n    | Toggle live-sync of pinned buffers        |
| `gbd`          | n    | Toggle diff-only sync of pinned buffers   |
| `}` / `{`      | n    | Next / previous chat                      |
| `]]` / `[[`    | n    | Next / previous message header            |
| `ga`           | n    | Change adapter and/or model               |
| `gf`           | n    | Fold all codeblocks                       |
| `gd`           | n    | Show debug info for the chat              |
| `gs`           | n    | Toggle the system prompt on/off           |
| `gM`           | n    | Remove rules from the chat                |
| `gtx`          | n    | Reset cached tool approvals                |
| `gty`          | n    | Toggle yolo mode (auto-approve tool calls) |
| `gR`           | n    | Open the file path under the cursor       |
| `gm`           | n    | Send a follow-up while streaming          |
| `?`            | n    | Show this list of keymaps                 |

**Example** — the model goes down a wrong path mid-response:
```
" press `q` to stop it
" press `gx` to clear the chat if you want a clean slate, or just
" type a correction and press <CR> to steer it without clearing
```

## Variables (`#` prefix, inserted in the chat buffer)

Reference context without asking the model to fetch it.

`#buffer`, `#buffers`, `#diagnostics`, `#diff`, `#messages`, `#quickfix`,
`#selection`, `#terminal`, `#viewport`, `#this` (CLI interaction only —
selection if present, else current buffer)

**Example** — ask about a failing test using the current buffer plus its
LSP diagnostics:
```
#buffer #diagnostics

Why is this raising a type error on line 42?
```

**Example** — summarize what changed before writing a commit message:
```
#diff

Summarize these changes in one sentence for a commit message.
```

## Slash commands (`/` prefix, inserted in the chat buffer)

`/buffer`, `/file`, `/help`, `/image`, `/now`, `/rules`, `/symbols`,
`/fetch`, `/mcp`, `/share`

ACP-only (shown because all four `claude_code*` adapters are ACP):
`/acp_session_options` (change mode/reasoning level), `/command` (switch the
CLI launch command, e.g. `--yolo`), `/resume` (resume a previous ACP
session).

**Example** — pull in another file and ask for a comparison:
```
/file

" a picker opens; select the file, it gets inserted as context

How does this differ from the approach in #buffer?
```

**Example** — switch reasoning effort on an ACP session:
```
/acp_session_options

" a picker opens with mode/reasoning options for the current agent
```

## ACP passthrough (`\` prefix)

Forwards directly to the Claude Code CLI's own slash commands (e.g.
`\clear`, `\compact`) rather than CodeCompanion's own equivalents.

**Example** — free up context on a long-running session without starting a
new chat:
```
\compact
```

## Tool-approval / diff buffer keymaps

Shown only in the special diff/approval buffer that pops up when the agent
proposes a file change (buffer-local — does not conflict with your global
`g1`-`g9` buffer-switch keymaps):

| Key  | Action                          |
|------|----------------------------------|
| `gv` | View the proposed diff           |
| `g1` | Always accept changes in this buffer |
| `g2` | Accept this change               |
| `g3` | Reject this change                |
| `g4` | Cancel all pending tool calls     |
| `}` / `{` | Next / previous hunk        |

**Example** — the agent proposes an edit across several files:
```
" a diff buffer pops up for the first file
" press `gv` to review the diff
" press `g2` to accept just this file, or `g1` to trust it for the
" rest of the session and stop being asked
```

## Inline assistant (`:CodeCompanion`)

Edits code directly in the buffer instead of opening a chat.

- `:CodeCompanion <prompt>` — run at the cursor.
- `:'<,'>CodeCompanion <prompt>` — run on a visual selection.
- Override the adapter for one call: `:CodeCompanion adapter=deepseek refactor this`
- Pull in a prompt-library action with `/`: `:'<,'>CodeCompanion /tests`
- Context variables (`#{}` prefix, distinct from the chat buffer's `#` variables):
  `#{buffer}`, `#{chat}` (messages from the last chat), `#{clipboard}`

The response is classified automatically and either **replace**s the selection,
**add**s at the cursor, inserts **before** the cursor, opens a **new** buffer, or
routes to a **chat**. Diffed edits use the same `gv`/`g1`/`g2`/`g3`/`g4` keymaps
as the tool-approval diffs above.

**Note:** inline only supports **HTTP adapters** — on an ACP adapter like
`claude_code` it silently no-ops and just logs a warning. `init.lua` currently
sets `interactions.inline.adapter = "claude_code"`, so `:CodeCompanion` won't do
anything until that's pointed at an HTTP adapter (e.g. `anthropic`, `copilot`).

**Example** — add type annotations to a visual selection, no chat buffer involved:
```
" select a block in visual mode, then:
:CodeCompanion Add type annotations to these function signatures
```

## Background interactions

Small, silent LLM calls the plugin fires on its own — not a user-facing agent,
no chat buffer, no visible prompt. Configured under `interactions.background`.

- `chat.callbacks.on_ready` — runs once a chat is prepared; builtin
  `chat_make_title` auto-generates a title for it.
- `chat.callbacks.on_checkpoint` — runs at a checkpoint; builtin `compact` can
  summarize/trim history (commented out, i.e. opt-in, by default).
- `chat.opts.enabled` — master switch for **all** background chat interactions,
  `false` by default.

**Note:** background interactions also require an **HTTP adapter**. `init.lua`
sets `interactions.background.adapter = "claude_code"` (ACP), so these silently
no-op regardless of `opts.enabled` — both the adapter and `opts.enabled` need to
change for this feature to actually run.

## Ex commands

| Command | Purpose |
|---|---|
| `:CodeCompanion [prompt]` | Inline assistant at the cursor/selection |
| `:CodeCompanionChat [Toggle\|Add\|RefreshCache] [adapter=NAME] [model=NAME]` | Open/toggle a chat, or add selection to one |
| `:CodeCompanionCmd` | Ask the model to write a command-line command |
| `:CodeCompanionCLI` | Open the terminal-based CLI interaction |
| `:CodeCompanionActions` | Open the action palette |

All of the above tab-complete adapter names, including
`claude_code_opus`/`_sonnet`/`_haiku`/`_fable`.

**Example** — jump straight to the action palette to browse prompts instead
of remembering command names:
```
:CodeCompanionActions
```

## Custom prompts

Markdown prompts live in `prompts/` in this repo (wired up via
`prompt_library.markdown.dirs` in `init.lua`) and show up in the Action
Palette automatically. Edited or added a file while Neovim is running? Run
`:CodeCompanionActions refresh` to pick it up without restarting.

- `prompts/new-prompt.md` — a meta-prompt that scaffolds new prompt files for
  you. Trigger it via the Action Palette ("New Prompt"), `:CodeCompanionChat
  /newprompt`, or `/newprompt` inside an already-open chat.
