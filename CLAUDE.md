@AGENTS.md

## Claude Code notes

- This dashboard can see the Claude Code session you're running in (its card is titled after your conversation). Don't close it from the UI.
- To check the UI, use the Chrome tools on `http://127.0.0.1:8765` in a new tab, then close the tab. Toggling grouping or collapsing groups changes the user's saved `csd:*` preferences in that browser, so put them back afterwards.
- To restart the server, run `python3 server.py --no-open` as a background command after killing the old one; the previous background task then reports exit 143, which is expected.
- When adding a field to a session, update `load_sessions()` (server) and the card rendering (`chips` / `context` / `card` in `index.html`) together, and add it to the search filter in `render()` if it's text worth searching.

## Mac app (`mac-app/`)

- `./mac-app/build.sh` builds `build/Claude Sessions Dashboard.app` (git-ignored): a Swift/WKWebView wrapper, no Xcode project.
- On launch it copies the bundled `server.py`, `index.html`, `demo/` to `~/Library/Application Support/Claude Sessions Dashboard/` and runs them with `/usr/bin/python3` on a free port, so it never clashes with a manual server on 8765 and never writes `attach-tabs.json` inside the signed bundle.
- External links (Jira, PRs) open in the default browser. Quitting the app terminates the server.
- Icon: `mac-app/icon.png`, drawn in code by `swift mac-app/make-icon.swift b mac-app/icon.png` from `mac-app/claude-logo.png` (option B: dark tile, green/amber/red half gauge, the original Claude icon as a corner badge). Options A (burst as gauge hub) and C (burst bleeding off the corner) were rejected; the first try (thin drawn burst inside a 270° tick ring) was too subtle. Keep everything inside the 824px tile: anything sticking out (the first B had the badge overhang) makes macOS wrap the icon in a grey frame. `build.sh` turns the PNG into `AppIcon.icns`.
- After changing `server.py` or `index.html`, rerun `build.sh` — the app holds its own copy.

## Grouping

- Age groups (`AGE` in `index.html`) bucket by time since `updatedAt` (else `startedAt`): 0–12 h, 12–24 h, 1–3 days, 3+ days. Ended sessions are bucketed by age too, not split out.
- Switching to Age always starts oldest-first; clicking Age while active flips the order (`csd:ageOldestFirst`).
