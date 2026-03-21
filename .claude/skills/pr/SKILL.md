---
name: pr
description: Create a pull request body in the team's required Korean format after branch work is complete.
---

When the user asks to create a pull request:

1. Inspect the current branch diff against the base branch.
2. Summarize the overall purpose under "## 📝 Summary".
3. Organize changes under "## 🔍 Changes" by meaningful implementation groups.
4. Mention dependency changes, config/app bootstrap, DI, architecture, models, error handling, tests, and follow-up items when relevant.
5. Use Korean.
6. Preserve the team PR format.
7. Do not invent behavior, issue numbers, or completed work that is not supported by the diff.
8. Separate placeholder methods, TODOs, and future work under "참고사항" when needed.

Use this exact structure:

## 📝 Summary
- ...

## 🔍 Changes
...

## 🧪 Test
- ...   <!-- only if tests exist -->

## 🔗 Related Issues
- ...

Section guidance:

### Summary
- Summarize the core purpose of the PR in 1-2 lines.

### Changes
- Group changes by feature, layer, or logical implementation area.
- Prefer reviewer-friendly grouping over raw file listing.
- Include file paths only when they help understanding.
- Separate incomplete or deferred work under "참고사항".
- Do not write anything that is not supported by the diff.
- Do not describe planned work as if it were already completed.

### Test
- Only include this section if tests are present.
- Do not merely list test file names.
- Describe what was verified and which scenarios were covered.
- Clearly distinguish automated tests from manual verification.
- Do not claim unexecuted tests were run.
- Omit this section entirely if there are no tests.

### Related Issues
- Put related issues at the end.
- Do not guess issue numbers that are not confirmed.

Formatting rules:
- Be precise and non-marketing in tone.
- Preserve tables when useful.
- Use Korean for the final PR body.