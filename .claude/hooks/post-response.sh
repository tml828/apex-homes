#!/bin/bash
# Remind Claude to keep CLAUDE.md up to date after every response that touches index.html

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Check if index.html was modified in the last git commit or is currently staged/modified
if git -C "$CLAUDE_PROJECT_DIR" diff --name-only HEAD 2>/dev/null | grep -q "index.html"; then
  echo "REMINDER: index.html was modified. Review CLAUDE.md and update it if the change introduced new functions, patterns, rules, or architectural decisions worth documenting."
fi

exit 0
