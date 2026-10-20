# Third-party skills in this folder (installed 2026-10-12, owner-approved)

Location: the repository root, shared by MonCook and 금칙어 게임 (Banned words). Claude Code loads `.claude/skills/`
from the start folder and every parent up to the repo/worktree root, so sessions started in `MonCook/` or
`Banned words/` see them too. Copied here on 2026-10-20 (owner's choice) from `moncook-claude/MonCook/.claude/skills/`,
where they were never committed; the files are unchanged. Delete that copy once this commit reaches its branch or the
main checkout (a worktree without root skills reads the main checkout's), or the same skills load twice
(`/roblox-x` from here, `/MonCook:roblox-x` from there). Newer upstream versions exist (roblox-brain v2.3.1,
roblox-dev-skill v2.18.1) and are NOT applied: they are new third-party code, so review + owner approval first.

- roblox-brain (TabooHarmony, MIT, commit 38826be): roblox-networking, roblox-security, roblox-performance,
  roblox-publish-checklist, roblox-gui, roblox-animation-vfx, roblox-audio, roblox-localization,
  roblox-analytics, roblox-monetization. License: ROBLOX_BRAIN_LICENSE.
  Left out after review: collaboration-mode (overrides our ask/approval rules), studio-mcp (wrong about our MCP,
  says restart Studio), player-psychology/growth/game-design (aggressive F2P tactics vs MonCook/docs/design/v3
  economy #58-60, #64), lighting, physics, cloud, luau-core/patterns, tooling.
- roblox-dev-skill (MSayib, MIT, commit ce85296, verified vs Studio 0.742): SKILL.md + references only
  (no installers/tools).

Precedence: the owner's rules (`~/.claude/CLAUDE.md`, project memory) and our design docs (MonCook/docs/design/v3,
Banned words/docs/DESIGN_V2.md) win over these skills - ask when unsure, approval before paid credits/publishing,
never close or restart the QA Studio, performance target 30 fps low-end.
Known caveats: roblox-performance's 45 fps mobile target (ours: 30 low-end / 60 S23+); localization's
country-pricing sample (don't); audio skips asset permissions; some DataStore limits to check against docs;
roblox-dev-skill `references/mcp-integration.md` also says to restart Studio - ignore it (same reason studio-mcp
was left out: never close or restart the owner's QA Studio).
