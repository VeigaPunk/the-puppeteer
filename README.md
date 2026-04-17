# The Puppeteer

A headless bridge to ChatGPT's web UI, using your existing OpenAI Plus/Pro subscription. Runs as a CLI (`chitchat "prompt"`) and as a Claude Code agent (`the-puppeteer`).

Sibling project to [the-musketeer](https://github.com/VeigaPunk/the-musketeer) (same idea, for Grok).

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
✓ Prompt fired. Open chatgpt.com to read the reply when it's ready.
```

Same shape from a Claude Code session: invoke the `the-puppeteer` agent with a prompt, it shells out to `chitchat`, reports "fired", returns control.

## Architecture

1. **agent-browser** (a Playwright wrapper) runs a persistent Chromium session keyed by name. First-run opens a blank browser; subsequent runs restore the saved session. Crucially, the persistent session is what keeps the prompt alive after `chitchat` exits — the backgrounded browser stays open and ChatGPT keeps streaming into it.
2. **Cookie injection** — instead of logging in via the automated browser (blocked by Google/Microsoft/Apple OAuth bot detection), you log in once in your real Chrome, export cookies via Cookie-Editor, and merge them into the automated browser's session file. The key cookies are the split pair `__Secure-next-auth.session-token.0` + `.1` on `chatgpt.com`.
3. **Cloudflare UA fix** — the default Playwright user-agent trips `chatgpt.com`'s Cloudflare Turnstile. `chitchat` sets a real Chrome-on-Windows UA before every navigation, which is enough to pass the challenge when combined with valid cookies.
4. **`chitchat` CLI** — navigates to chatgpt.com, dismisses overlays, types into `#prompt-textarea`, presses Enter, exits. No response capture.
5. **Claude agent** — `the-puppeteer.md` is a user-level agent spec. Installed to `~/.claude/agents/`, it becomes callable via the Agent tool from any Claude Code session.

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

## Authenticate (one-time, repeat when cookies expire)

1. In your web UI, pick the model you want to run by default (likely GPT-5.4-Pro extended thinking, or GPT-5.4 thinking with Deep Research toggled on). The automated browser will inherit this via the `oai-last-model-config` cookie.
2. Install [Cookie-Editor](https://chromewebstore.google.com/detail/cookie-editor/hlkenndednhfkekhgcdicdfddnkalmdm) in your real browser.
3. On `chatgpt.com`: Cookie-Editor → Export as JSON → save to `/tmp/chatgpt-cookies.json`.
4. Merge: `python3 merge-cookies.py /tmp/chatgpt-cookies.json`.
5. Test: `chitchat "hello"` — should print `✓ Prompt fired.` then exit.
6. Delete `/tmp/chatgpt-cookies.json` — it contains session tokens equivalent to your login password.

`__Secure-next-auth.session-token.0` / `.1` are the JWT pair that expires; based on the snapshot used during bring-up, expiration was ~90 days out. When you start seeing `⚠ No user turn detected` or a Cloudflare interstitial that won't clear, repeat steps 3–4.

## Files

- `chitchat` — the CLI executable.
- `merge-cookies.py` — Cookie-Editor JSON → agent-browser session-state merger.
- `the-puppeteer.md` — Claude Code agent spec.
- `install.sh` — idempotent installer.

## Known limits

- **No response retrieval.** By design. You read answers in `chatgpt.com`, not the terminal.
- **One chat thread per session file.** `chitchat` always opens `chatgpt.com/` (the landing route), which on your account lands either on the most recent chat or a fresh new chat depending on session state. If you need prompts to live in separate threads, hit the "New chat" button in the web UI between runs.
- **Model is whatever the web UI default is.** `chitchat` never touches the model picker. Change it in `chatgpt.com` settings first.
- **Fragile to DOM changes.** Selectors (`#prompt-textarea`, `button[aria-label="Close"]/[Dismiss]`) are ChatGPT-UI-specific. If OpenAI ships a redesign, the script may need updating.
- **One account.** The session name is hardcoded as `chatgpt-session`. Use multiple installs with different session names if you need multiple accounts.
- **Cloudflare fingerprinting risk.** The UA-header fix is enough today, but if OpenAI tightens Turnstile (e.g. adds JS challenges that check `navigator.webdriver`), you may need to add stealth shims or switch to `agent-browser --profile` (reusing a real Chrome profile).
- **No tool/model selection.** Whatever model + tools are active in your web UI at login time are what the automated browser inherits. Change the default model in chatgpt.com settings if needed.

## Security

The session file at `~/.agent-browser/sessions/chatgpt-session-default.json` contains JWTs equivalent to your login password for that session. `.gitignore` blocks committing anything that looks like cookies. Never paste session JSON in a public channel.
