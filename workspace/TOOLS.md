# Tool Usage Notes

## exec — Safety Limits

- Commands have a configurable timeout (default 60s)
- Dangerous commands are blocked (rm -rf, format, dd, shutdown, etc.)
- Output is truncated at 10,000 characters

## gh — GitHub CLI

Authenticated via `GH_TOKEN` environment variable.

- **Never expose tokens or secrets** — don't echo, log, print, or include in messages
- Sanitize output before showing to users: strip tokens from URLs (git remote -v), auth status, error messages
- If a git remote URL contains a token, don't display it

## Browser — Playwright

Headless Chromium. Use for screenshots, scraping, and page inspection. No GPU acceleration available.

## Error Communication

- Never show raw tool errors to users. Translate to plain language.
- "Command blocked by safety guard" → try a different approach silently. If no alternative exists, explain the limitation briefly.
- Stack traces, pip warnings, internal errors → summarize as "Technisches Problem mit X"
- If a command fails, mention what didn't work and what you're trying instead — one sentence, not the error dump
