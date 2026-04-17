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
echo "Next step: authenticate."
echo ""
echo "  1. Log into chatgpt.com in your regular browser and set your default model"
echo "     (e.g. GPT-5.4-Pro extended thinking, or GPT-5.4 thinking + Deep Research)."
echo "  2. Install the Cookie-Editor extension:"
echo "     https://chromewebstore.google.com/detail/cookie-editor/hlkenndednhfkekhgcdicdfddnkalmdm"
echo "  3. On chatgpt.com: Cookie-Editor → Export → Export as JSON → save to /tmp/chatgpt-cookies.json"
echo "  4. Run: python3 $HERE/merge-cookies.py /tmp/chatgpt-cookies.json"
echo "  5. Test: chitchat \"hello\"  (should print '✓ Prompt fired.' and exit immediately)"
echo "  6. Delete /tmp/chatgpt-cookies.json (it contains your session tokens)."
echo ""
echo "Remember: chitchat is fire-and-forget. Read the answer in chatgpt.com, not the terminal."
