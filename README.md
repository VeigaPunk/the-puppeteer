# The Puppeteer

A bridge to ChatGPT's web UI, using your existing OpenAI Plus/Pro subscription. Runs as a CLI (`chitchat "prompt"`) and as a Claude Code agent (`the-puppeteer`).

Sibling project to [the-musketeer](https://github.com/VeigaPunk/the-musketeer) (same idea, for Grok). Both converged on the same transport: CDP attach to a dedicated Windows Chrome Dev.

## Why

The Puppeteer exists for **one specific reason**: to reach capabilities that can't be accessed through Codex CLI.

Primary use case:
- **GPT-5.4-Pro (extended thinking)** — the Pro-tier model with long internal reasoning runs. Only the `chatgpt.com` web surface (authenticated via OAuth on the Pro subscription) serves it; Codex CLI can't target it.

Secondary use case:
- **GPT-5.4 (thinking) + Deep Research** — the agentic browse-and-synthesize loop exposed inside the web UI. Deep Research is a web-app orchestrator on top of the model; Codex CLI does not have an equivalent mode that reproduces it end-to-end.

For anything else (plain GPT-5.4, Codex-available tools), just use Codex CLI directly — it's more ergonomic and already wired into your workflow than driving a browser. The Puppeteer is specifically the escape hatch for **web-UI-only capabilities**, reusing the existing Pro subscription's OAuth session rather than trying (and failing, same as Grok) to automate Google/Microsoft/Apple SSO.

## What it does

**Fire-and-forget.** Drops a prompt into your logged-in ChatGPT web session and exits. Does not wait for, poll for, or capture the response — GPT-5.4-Pro Extended and Deep Research runs take minutes to hours, so blocking a terminal on them is pointless. You read the answer in `chatgpt.com` later, in your real browser.

```bash
$ chitchat "Write a 40-page research brief on lattice cryptography post-2024"
→ Firing prompt into ChatGPT...
✓ Prompt fired. Read the reply in your ChatGPT Chrome tab.
```

Same shape from a Claude Code session: invoke the `the-puppeteer` agent with a prompt, it shells out to `chitchat`, reports "fired", returns control.

## Architecture

1. **Chrome Dev with CDP** — you launch Windows Chrome Dev with `--user-data-dir=C:\ChromeAutomation --remote-debugging-port=9222`, sign into chatgpt.com once, and leave it running. The isolated user-data-dir is mandatory: Chrome silently disables remote debugging on the default profile as a security measure.
2. **agent-browser `--cdp 9222`** — a native CLI that speaks Chrome DevTools Protocol. `chitchat` attaches to your existing Chrome, finds (or opens) a chatgpt.com tab, and drives it.
3. **`chitchat` CLI** — navigates to chatgpt.com, waits out the (rare, since Chrome is real) Cloudflare Turnstile, types the prompt into `#prompt-textarea`, presses Enter, verifies the user-turn count incremented, exits.
4. **Claude agent** — `the-puppeteer.md` is a user-level agent spec. Installed to `~/.claude/agents/`, it becomes callable via the Agent tool from any Claude Code session.

## Install

```bash
git clone git@github.com:VeigaPunk/the-puppeteer.git ~/projects/the-puppeteer
cd ~/projects/the-puppeteer
./install.sh
```

The installer:
- Installs `agent-browser` globally via npm (if missing)
- Symlinks `chitchat` into `~/.local/bin/`
- Symlinks the Claude agent into `~/.claude/agents/`

## Launch Chrome Dev with CDP (one-time)

`chitchat` attaches to a Chrome Dev instance running with CDP exposed. This must be a **dedicated Chrome Dev install** (not your everyday Chrome) because Chrome refuses to enable `--remote-debugging-port` on the default, sync-signed-in profile.

1. Close any running Chrome Dev instance — including tray-resident background processes. Check Task Manager or right-click any Chrome Dev tray icon and Exit. (If the previous instance was launched without CDP flags, new launches inherit its empty flag set.)
2. Relaunch Chrome Dev with the flags below. On Windows, edit a shortcut's target to:
   ```
   "C:\Program Files\Google\Chrome Dev\Application\chrome.exe" --user-data-dir=C:\ChromeAutomation --remote-debugging-port=9222 --no-first-run --no-default-browser-check
   ```
3. Sign into `chatgpt.com` with your Plus/Pro account. Pick your default model (e.g. GPT-5.4-Pro extended thinking, or GPT-5.4 thinking + Deep Research) in web-UI settings — `chitchat` never touches the model picker.
4. From WSL, verify the port is reachable:
   ```bash
   curl -s http://localhost:9222/json/version
   ```
   You should see JSON with `"Browser": "Chrome/..."`. If not, check `netstat -ano | findstr :9222` on Windows — if nothing is listening, Chrome refused to enable CDP (usually because `--user-data-dir` was omitted).
5. Test: `chitchat "hello"` — should print `✓ Prompt fired.` and exit immediately.

This Chrome Dev install is dedicated to automation — sign into any other web services you want programmatic access to (grok.com for the-musketeer, notebooklm.google.com, etc.) in the same profile.

## Files

- `chitchat` — the CLI executable.
- `the-puppeteer.md` — Claude Code agent spec.
- `install.sh` — idempotent installer.

## Known limits

- **No response retrieval.** By design. You read answers in `chatgpt.com`, not the terminal.
- **Shares a tab with your live browsing.** Each `chitchat` call reuses whatever chatgpt.com tab is open (or opens one if absent). Agent prompts and your manual chats land in the same conversation. For a fresh thread, hit the "New chat" button in the web UI first, or pin a dedicated chatgpt.com tab for agent use.
- **Model is whatever the web UI default is.** `chitchat` never touches the model picker. Change it in `chatgpt.com` settings first.
- **Fragile to DOM changes.** Selectors (`#prompt-textarea`, `[data-message-author-role="user"]`) are ChatGPT-UI-specific. If OpenAI ships a redesign, the script may need updating.
- **One Chrome, one port.** CDP on 9222 is a singleton — if you use the port for another tool (e.g. the-musketeer), they share the same Chrome instance (which is the intended setup).

## Security

Your dedicated Chrome Dev profile at `C:\ChromeAutomation` holds your ChatGPT session (plus any other services you've signed into). Running Chrome with `--remote-debugging-port=9222` exposes CDP to anything that can reach `localhost:9222` on your Windows box — don't enable this port on a shared or exposed machine. On WSL the port is reachable from the Linux side only (same machine); that's fine. If you ever expose the port outside localhost, treat it as granting full control over your browser, including any signed-in session.
