#!/bin/bash
# The Puppeteer installer — sets up the chitchat CLI + Claude agent.
# Idempotent: safe to re-run.

set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ The Puppeteer installer"

# 1. Install agent-browser if missing
if ! command -v agent-browser >/dev/null 2>&1; then
  echo "→ Installing agent-browser..."
  npm install -g agent-browser
  agent-browser install
fi
echo "✓ agent-browser present ($(agent-browser --version))"

# 2. Symlink chitchat CLI into PATH
mkdir -p ~/.local/bin
ln -sf "$HERE/chitchat" ~/.local/bin/chitchat
chmod +x "$HERE/chitchat"
echo "✓ chitchat CLI at ~/.local/bin/chitchat"

# 3. Deploy Claude agent (user-level, available in any session)
mkdir -p ~/.claude/agents
ln -sf "$HERE/the-puppeteer.md" ~/.claude/agents/the-puppeteer.md
echo "✓ Claude agent at ~/.claude/agents/the-puppeteer.md"

# 4. Verify PATH contains ~/.local/bin
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "✓ ~/.local/bin is in PATH";;
  *) echo "⚠ ~/.local/bin is NOT in PATH — add to your shell rc: export PATH=\"\$HOME/.local/bin:\$PATH\"";;
esac

echo ""
echo "Next step: launch your Windows Chrome Dev with CDP enabled."
echo ""
echo "  1. Close any running Chrome Dev instance (including tray background processes)."
echo "  2. Relaunch Chrome Dev with remote-debugging + isolated user-data-dir. Example shortcut target:"
echo "       \"C:\\Program Files\\Google\\Chrome Dev\\Application\\chrome.exe\" --user-data-dir=C:\\ChromeAutomation --remote-debugging-port=9222 --no-first-run --no-default-browser-check"
echo "     (The --user-data-dir flag is mandatory — Chrome silently disables CDP on the default profile.)"
echo "  3. Sign into chatgpt.com in that Chrome with your Plus/Pro account. Pick your default model"
echo "     (e.g. GPT-5.4-Pro extended thinking, or GPT-5.4 thinking + Deep Research) in web-UI settings."
echo "  4. From WSL, verify: curl -s http://localhost:9222/json/version"
echo "  5. Test: chitchat \"hello\"  (should print '✓ Prompt fired.' and exit immediately)"
echo ""
echo "Auth is handled by your real Chrome session — no cookie export, no session JSON."
echo "Remember: chitchat is fire-and-forget. Read the answer in chatgpt.com, not the terminal."
