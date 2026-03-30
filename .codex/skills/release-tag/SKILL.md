---
name: release-tag
description: Create annotated Git release tags and push them to the remote for the current workspace. Use when the user asks to create, update, describe, or publish a release tag from the active repo, especially after building Clocker.app.
---

# Release Tag

## Workflow

1. Inspect the current branch, HEAD commit, and existing tags.
2. Choose a semantic version tag when the repo already uses versioned releases.
3. Confirm the built `Clocker.app` exists from the latest build and include it in the release context.
4. Write an annotated tag message with a short title and a concise feature summary.
5. Create or update the tag on the current commit.
6. Push the tag to `origin` and verify the remote reference.

## Tag Message

- Prefer a short release title, then a blank line, then a bullet list of notable features.
- Summarize user-visible behavior, not internal implementation details.
- Mention the built `Clocker.app` bundle when the release follows a successful build.
- If the tag already exists and needs a better message, update it with `git tag -fa`.

## Defaults

- Use annotated tags by default.
- Use semantic version names like `vX.Y.Z` unless the user asks for another pattern.
- Verify the tag points at `HEAD` before finishing.
