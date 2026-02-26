# Tool Usage Notes

## exec — Safety Limits

- Commands have a configurable timeout (default 60s)
- Dangerous commands are blocked (rm -rf, format, dd, shutdown, etc.)
- Output is truncated at 10,000 characters

## gh — GitHub CLI

Authenticated via `GH_TOKEN` environment variable. **Do not expose this token** — never echo it, log it, or include it in files.

## Browser — Playwright

Headless Chromium. Use for screenshots, scraping, and page inspection. No GPU acceleration available.
