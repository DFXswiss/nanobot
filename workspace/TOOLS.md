# Tool Usage Notes

## exec — Safety Limits

- Commands have a 300s (5 min) timeout
- Dangerous commands are blocked (rm -rf, format, dd, shutdown, etc.)
- Output is truncated at 10,000 characters

## gh — GitHub CLI

If `GH_TOKEN` is set, `gh` is authenticated automatically. Never inline the
token in commands, URLs, or output.

## git — Version Control

- Stage files by path, not with `-A` or `.`.
- Review `git diff --cached` before committing.
- Verify remote and branch before pushing.

## Browser — Playwright

Headless Chromium. Use for screenshots, scraping, and page inspection. No GPU
acceleration.

## Error Communication

- Never echo raw tool errors or stack traces to end users.
- On failure, try a different approach; surface a short plain-language note
  only when stuck and user input is needed.
