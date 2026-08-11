# Prompt: Initialize the CurlPlan changelog

Use this prompt in a fresh repository task when CurlPlan is ready to adopt a project changelog.

```text
Initialize a durable `CHANGELOG.md` for CurlPlan from verified repository history.

Sources of truth, in order:
1. `CLAUDE.md` and `README.md` for architecture and current product boundaries.
2. `git log --date=short --pretty=format:'%h %ad %s'` for dates and shipped changes.
3. The relevant diffs and verification scripts for any claim that is not explicit in a commit subject.
4. Release tags, if any. Do not invent semantic versions when the repository has no corresponding tag.

Requirements:
- Use `# Changelog` followed by dated sections, newest first.
- State that dates are commit dates and that generated daily content is summarized rather than copied line by line.
- Begin with a `2026-08-10` section covering the credential-free public preview, removal of legacy local password records, browser security policy, metadata/robots/sitemap work, service-worker cache migration, accessibility landmark, workflow hardening, and verified web/iOS parity.
- Preserve the distinction between the public demo, the tested sync API scaffold, and real production account availability. Do not claim that public accounts or cloud sync are live.
- Backfill older history only where commits or existing documentation support the entry.
- Group changes by user-visible outcome. Avoid dumping raw commit subjects.
- Do not include roadmap items, unmerged feature-branch work, or Notion status as shipped work.

Verification before completion:
- Run `node scripts/verify-app.js` and `node scripts/verify-split.js`.
- Run `git diff --check`.
- Confirm every listed release commit is an ancestor of `origin/main`.
- Report any history that could not be classified without inference.
```
