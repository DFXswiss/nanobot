# Tool Usage Notes

## exec — Safety Limits

- Commands have a configurable timeout (default 60s)
- Dangerous commands are blocked (rm -rf, format, dd, shutdown, etc.)
- Output is truncated at 10,000 characters

## gh — GitHub CLI

Authenticated via `GH_TOKEN` environment variable.

- **Never expose tokens or secrets** — don't echo, log, print, or include in messages
- **Never embed tokens in commands** — no `echo $TOKEN | ...`, no `GH_TOKEN="..." cmd`, no `https://user:token@github.com/...` in git URLs. Use `gh` for all authenticated operations.
- Sanitize output before showing to users: strip tokens from URLs (git remote -v), auth status, error messages
- If a git remote URL contains a token, don't display it

## git — Version Control

- **Never use `git add -A` or `git add .`** — stage specific files by path.
- Before committing: `git diff --cached` to review staged changes. Check for temp files, scripts, credentials.
- Before pushing: verify remote and branch are correct.
- PR creation: always include `--base develop`.

## Browser — Playwright

Headless Chromium. Use for screenshots, scraping, and page inspection. No GPU acceleration available.

### Screenshots
- After taking a screenshot: **immediately send the file to the user.** Don't describe it, send it.
- Default to full-page screenshot unless told otherwise.
- Max 2 screenshot attempts. If it's still not right, send what you have and ask what they need.

## Error Communication

- Never show raw tool errors to users. Translate to plain language.
- "Command blocked by safety guard" → try a different approach silently. If no alternative exists, explain the limitation briefly.
- Stack traces, pip warnings, internal errors → summarize as "Technisches Problem mit X"
- If a command fails, try alternatives silently. Only mention failures when stuck and you need user input.
