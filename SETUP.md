# the-puppeteer — CDP + Puppeteer Setup Guide

A reusable, Claude-readable setup doc for bringing a fresh **WSL2 + Windows 10/11** box to the point where `chitchat` can drive ChatGPT end-to-end. Covers the full CDP stack (Windows Chrome Dev + `--remote-debugging-port=9222` + isolated profile), the WSL-side `agent-browser` transport, and an optional Puppeteer-core Node API integration for downstream automation.

---

## TL;DR — the whole stack in one breath

```
Windows Chrome Dev (with --user-data-dir + --remote-debugging-port=9222)
        ↓ CDP on port 9222
  WSL2 localhost:9222  (WSL2 forwards Windows loopback automatically in mirrored mode)
        ↓
  agent-browser CLI (node-based)   ← OR → puppeteer-core (connect({browserURL}))
        ↓
  chitchat (fire-and-forget ChatGPT prompts, optional model + tool selection)
```

Why isolated `--user-data-dir`? Chrome 136+ **silently refuses `--remote-debugging-port` on the default sync-signed-in profile** as a security measure. A non-default profile directory lifts the restriction. This is the #1 silent failure.

---

## Prerequisites

- **Windows 10/11** with WSL2 installed
- **Chrome Dev channel** (separate from Stable — they coexist): https://www.google.com/chrome/dev/
- **Node.js 20+** on WSL (Node 24 LTS recommended). Install via `fnm` (below) if missing
- **Git** on WSL

Confirm baseline:
```bash
wsl --version    # from PowerShell — confirms WSL2
node --version   # from WSL — if missing, Phase E installs it
```

---

## Phase A — Windows Chrome Dev + isolated profile

1. **Install Chrome Dev** from the link above. Leave your everyday Chrome alone — Dev is a separate channel and coexists.
2. **Close every Chrome Dev process first** — including tray-resident background processes. From PowerShell:
   ```powershell
   Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*Chrome Dev*" } | Stop-Process -Force
   ```
   If Chrome Dev is mid-launch with stale flags, new launches attach to the surviving daemon and CDP never binds. This is silent-failure #2.
3. **Create the isolated profile dir**: `C:\ChromeAutomation` (empty dir, Chrome populates it on first run).
4. **Create a shortcut** (right-click → New → Shortcut). Target field (paste verbatim):
   ```
   "C:\Program Files\Google\Chrome Dev\Application\chrome.exe" --user-data-dir=C:\ChromeAutomation --remote-debugging-port=9222 --no-first-run --no-default-browser-check
   ```
   Name it `Chrome Dev (CDP)` or similar. The four flags in order:
   - `--user-data-dir=C:\ChromeAutomation` — **mandatory**, isolates from default profile
   - `--remote-debugging-port=9222` — CDP entry point; any free port works, 9222 is convention
   - `--no-first-run` — suppresses welcome UI
   - `--no-default-browser-check` — suppresses default-browser nag
5. **Launch via the shortcut.** A window opens. You're now running a CDP-enabled Chrome.

---

## Phase B — Sign in to ChatGPT (one-time)

The isolated profile starts empty. In the CDP Chrome Dev window:

1. Go to `https://chatgpt.com` → sign in with your **Plus/Pro** account.
2. (Optional) Pick a default model in the web-UI settings — `chitchat` can override per-call via `--model`.
3. While you're there, sign into any other services you'll automate (`grok.com` for the-musketeer, `notebooklm.google.com` for the-almanacker). The dedicated profile stores cookies persistently in `C:\ChromeAutomation`; you only do this once.

**Leave the window open.** Every subsequent `chitchat` call attaches to this running Chrome over CDP.

---

## Phase C — Verify CDP is reachable from WSL

This is the single most useful diagnostic in the whole stack:

```bash
curl -s http://localhost:9222/json/version | head -20
```

Expected:
```json
{
  "Browser": "Chrome/149.0.7795.2",
  "Protocol-Version": "1.3",
  "webSocketDebuggerUrl": "ws://localhost:9222/devtools/browser/<uuid>",
  ...
}
```

**If `curl` hangs or returns nothing:**
- **Diagnostic 1** — check Windows-side whether anything is listening on 9222. From PowerShell:
  ```powershell
  netstat -ano | Select-String ":9222"
  ```
  If nothing, Chrome refused to enable CDP. Usually means `--user-data-dir` was omitted from the shortcut.
- **Diagnostic 2** — verify WSL→Windows loopback works. On Windows 11 you can enable full mirrored networking (simpler):
  ```ini
  # %UserProfile%\.wslconfig
  [wsl2]
  networkingMode=mirrored
  ```
  Then `wsl --shutdown` and restart WSL. Without mirrored mode, `localhost:9222` usually still works thanks to WSL's standard loopback forwarding, but `127.0.0.1` may behave differently.
- **Diagnostic 3** — `DevToolsActivePort` file inside the profile dir (`C:\ChromeAutomation\DevToolsActivePort`) exists only while Chrome is running WITH CDP. Its presence confirms CDP bound successfully.

**Never launch Linux Chrome in WSL** as a workaround. `agent-browser` will auto-detect and use it, which conflicts with the Windows CDP target. This repo's canonical transport is Windows Chrome Dev only.

---

## Phase D — Node / fnm (skip if Node 20+ already installed)

```bash
curl -fsSL https://fnm.vercel.app/install | bash
# restart shell or `source ~/.bashrc`
fnm install --lts
fnm default lts-latest
node --version   # confirms fnm resolves node binary
```

Ensure `~/.local/bin` is on `PATH` (fnm installs may drop binaries here):
```bash
echo $PATH | tr : '\n' | grep -E '(\.local/bin|fnm)'
```

---

## Phase E — agent-browser (the CDP transport for `chitchat`)

```bash
npm install -g agent-browser
agent-browser install       # post-install step — installs supporting browser driver
agent-browser --version     # confirm; expect 0.26.0 or newer
which agent-browser          # confirms PATH resolution
```

Smoke test against the running Chrome:
```bash
agent-browser --cdp 9222 tab list
```
Expected output: a numbered list of open tabs with format `[t0] <title> - <url>`. The `tN` format is what `chitchat` parses — it's not decimal integer.

---

## Phase F — Install `chitchat`

```bash
git clone git@github.com:VeigaPunk/the-puppeteer.git ~/projects/the-puppeteer
cd ~/projects/the-puppeteer
./install.sh
```

The installer symlinks:
- `chitchat` → `~/.local/bin/chitchat`
- `the-puppeteer.md` → `~/.claude/agents/the-puppeteer.md` (available as a Claude Code subagent)

---

## Phase G — Smoke tests

### G1 — Basic fire

```bash
chitchat "Reply with one word: ping"
```

Expected:
```
→ Firing prompt into ChatGPT...
✓ Prompt fired. Read the reply in your ChatGPT Chrome tab.
```

Check the Chrome window — a new conversation with your prompt and ChatGPT's reply.

### G2 — Model selection

```bash
chitchat --model pro "Outline three interpretations of the Riemann hypothesis in one sentence each"
chitchat --model thinking "What's 17 × 23 computed from first principles"
chitchat --model instant "Summarize quicksort in one line"
```

Model flag → data-testid mapping:
| `--model` | ChatGPT `data-testid` | Use case |
|---|---|---|
| `pro` / `p` | `model-switcher-gpt-5-4-pro` | Research-grade (user's primary target — GPT-5.4-Pro extended thinking) |
| `thinking` / `t` | `model-switcher-gpt-5-4-thinking` | Complex reasoning + Deep Research compatible |
| `instant` / `i` | `model-switcher-gpt-5-3` | Everyday chats |

Omitting `--model` leaves the tab on whatever model was last selected in the UI.

### G3 — Tool selection (image / deep research / web search)

```bash
chitchat --image "A minimalist red circle centered on white, flat 2D, no text"
chitchat --deep-research "Comprehensive state of post-quantum lattice cryptography, 2024-2026"
chitchat --web-search "Latest Chrome Dev channel version"
```

Tool modes are mutually exclusive. They toggle via the composer's `+` menu (`composer-plus-btn`) and apply to the single next prompt. ChatGPT's DOM exposes them as `role="menuitemradio"`; `chitchat` marks the target element and real-clicks it via CDP mouse (synthetic `.click()` does NOT trigger Radix state — critical gotcha).

### G4 — End-to-end via Claude Code subagent

From a Claude Code session (e.g. `claude` CLI), invoke:
```
Agent(subagent_type="the-puppeteer", prompt="Fire a Deep Research run: 'Survey of active-inference agent memory architectures, 2022-2026'")
```

The agent shells out to `chitchat`, reports "prompt fired", and returns. You read the Deep Research result in Chrome hours later (Deep Research is the flagship long-run mode; it's exactly why `chitchat` is fire-and-forget).

---

## Alternative: Puppeteer-core (Node API instead of CLI)

If you want a Node API over the same Chrome+CDP target (for deeper automation, scraping, custom flows beyond what `chitchat` exposes):

```bash
npm install puppeteer-core
```

Minimal connect script:
```javascript
// connect.js
const puppeteer = require('puppeteer-core');

(async () => {
  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222',
    defaultViewport: null,          // preserve native window size
    protocolTimeout: 0,             // disable for heavy CDP ops across WSL2 boundary
  });

  const pages = await browser.pages();
  console.log('open tabs:', pages.length);
  for (const p of pages) console.log('  -', await p.title(), await p.url());

  await browser.disconnect();       // disconnect; do NOT close() — that would kill Chrome
})();
```

`browserURL` makes Puppeteer fetch `/json/version` automatically and upgrade to the WebSocket endpoint. Use `browserWSEndpoint` only if you're attaching to a remote/cloud browser that hands you a fully-qualified `ws://` URL directly.

Docs: https://pptr.dev/api/puppeteer.connectoptions

---

## Gotchas (the silent-failure list)

1. **Default Chrome profile blocks CDP (Chrome 136+).** `--user-data-dir` is MANDATORY, not optional. If `curl localhost:9222/json/version` fails, this is the first thing to check.
2. **Background Chrome daemon.** A prior Chrome Dev launched without CDP flags will survive "close" and cause new launches to inherit its empty flag set. Kill all `chrome.exe` processes before relaunching from the CDP shortcut.
3. **Linux Chrome anti-pattern.** Do NOT install or launch Linux Chrome inside WSL for automation. `agent-browser` auto-detects and may pick it up, which creates conflicts with the Windows CDP target on the same port. Windows Chrome Dev is the canonical transport.
4. **Synthetic `.click()` vs real CDP mouse.** Radix UI components (ChatGPT's model picker, composer `+` menu) do NOT respond to JavaScript `element.click()` — their state machine is wired to real pointer events. Use `agent-browser click <selector>` (CDP mouse event) not `eval "element.click()"`.
5. **Tab IDs are `tN`, not integers.** `agent-browser tab list` shows `[t0]`, `[t1]`. Passing integer `0` where `t0` is expected silently falls through to "open new tab" — this bug existed in an earlier `chitchat` version.
6. **WSL localhost forwarding.** Windows 11 `.wslconfig` `networkingMode=mirrored` unifies WSL and Windows loopback. Without it, `127.0.0.1` in WSL may hit the Linux VM loopback instead of Windows. Prefer `localhost` over `127.0.0.1` in scripts.
7. **Cloudflare Turnstile.** Real Chrome passes CF's browser-integrity checks natively, so the stealth/UA hacks needed for headless puppeteer don't apply here. If CF gets stricter (JS-challenge requiring session age), the fix is "use the Chrome Dev profile for a while," NOT add stealth plugins.
8. **Singleton port.** One Chrome Dev instance = one CDP port 9222 = shared across all tools (the-puppeteer, the-musketeer, the-almanacker). This is intentional, not a limit.

---

## Reference — file layout after install

| Path | Role |
|---|---|
| `~/projects/the-puppeteer/chitchat` | CLI source (Bash) |
| `~/projects/the-puppeteer/README.md` | User-facing overview |
| `~/projects/the-puppeteer/SETUP.md` | This doc |
| `~/projects/the-puppeteer/the-puppeteer.md` | Claude Code subagent spec |
| `~/projects/the-puppeteer/install.sh` | Idempotent installer |
| `~/.local/bin/chitchat` → `~/projects/the-puppeteer/chitchat` | Shell symlink |
| `~/.claude/agents/the-puppeteer.md` → `~/projects/the-puppeteer/the-puppeteer.md` | Agent symlink |
| `C:\Program Files\Google\Chrome Dev\Application\chrome.exe` | Windows Chrome Dev binary |
| `C:\ChromeAutomation\` | Isolated Chrome profile |
| `C:\Users\<you>\Desktop\Chrome Dev (CDP).lnk` | CDP launch shortcut |

---

## Security note

The dedicated profile at `C:\ChromeAutomation` holds your ChatGPT / Grok / NotebookLM sessions. Exposing port 9222 outside `localhost` is equivalent to handing full browser control — including signed-in sessions — to anything on the network. Keep Windows Firewall blocking 9222 inbound from non-localhost. `chitchat` and agent-browser both assume localhost-only.

---

## Troubleshooting quick reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `curl localhost:9222/json/version` empty | Chrome not launched with CDP flags OR port closed | Relaunch from the shortcut; verify shortcut target has all 4 flags |
| `chitchat` → "Cannot reach Chrome at http://localhost:9222" | Same as above; OR WSL loopback broken | Try `.wslconfig networkingMode=mirrored` + `wsl --shutdown`; verify from Windows with `netstat -ano \| Select-String :9222` |
| `chitchat --image` → "Tool 'Create image' not found" | ChatGPT DOM drifted OR account tier doesn't expose image-gen | Check `chitchat` selectors against current DOM: `agent-browser --cdp 9222 eval "Array.from(document.querySelectorAll('[role=menuitemradio]')).map(e=>e.innerText)"` |
| Prompt posts but to wrong model | Tab was on a different model; `--model` flag omitted | Add `--model pro` (or other) explicitly |
| Tab stuck on CF challenge | New profile or long-idle session | Open Chrome manually, click the tab, pass the challenge once — session-age increases, future fires pass automatically |
| `agent-browser` not found | fnm not resolving / PATH issue | `which agent-browser`; check `~/.local/bin` and fnm's shim dir are on PATH |
