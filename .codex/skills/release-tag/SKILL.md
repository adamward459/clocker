---
name: release-tag
description: Create annotated Git release tags, publish the matching GitHub Release, and push everything to the remote for the current workspace. Use when the user asks to create, update, describe, or publish a release tag from the active repo, especially after building Clocker.app.
---

# Release Tag

## Workflow

1. Inspect the current branch, HEAD commit, and existing tags.
2. Choose a semantic version tag when the repo already uses versioned releases.
3. Confirm the built `Clocker.app` exists from the latest build and include it in the release context.
4. Write an annotated tag message with a short title and a concise feature summary.
5. Create or update the tag on the current commit.
6. Push the tag to `origin` and verify the remote reference.
7. Publish the matching GitHub Release immediately after tag creation, using `gh release create` or `gh release upload` to attach a `.zip` built from `Clocker.app`.
8. Verify the release archive has `Clocker.app/` at the zip root before uploading and confirm the uploaded asset name matches `Clocker-X.Y.Z.zip`.
9. For signed release builds, build the app with signing disabled, then code-sign the final `Clocker.app` bundle directly before zipping and uploading.

## Tag Message

- Format the message as:

  - one short release title on the first line
  - one blank line
  - 2-4 concise bullets with user-visible changes

- Keep bullets short and scannable.
- Summarize user-visible behavior, not internal implementation details.
- Mention the built `Clocker.app` bundle when the release follows a successful build.
- Avoid long paragraphs, wrapped prose, and implementation detail dumps.
- Always publish the GitHub Release after the tag is created and pushed, unless the user explicitly asks to skip release publication.
- For GitHub Releases, prefer a `.zip` built from `Clocker.app`, uploaded with `gh release create` or `gh release upload`.
- Build the archive from inside the directory that contains `Clocker.app` so the zip root is the app bundle itself, for example:

  ```sh
  cd DerivedData/Build/Build/Products/Debug
  ditto -c -k --sequesterRsrc --keepParent Clocker.app /tmp/Clocker-X.Y.Z.zip
  unzip -l /tmp/Clocker-X.Y.Z.zip | head
  ```

- The uploaded asset should be named `Clocker-X.Y.Z.zip` for release version `X.Y.Z`; do not upload a zip whose name or internal folder structure still includes `DerivedData/...`.
- If a direct archive build conflicts with SwiftPM package signing, prefer building unsigned and then signing the final app bundle with `codesign` before packaging.
- If the tag already exists and needs a better message, update it with `git tag -fa`.

## Defaults

- Use annotated tags by default.
- Use semantic version names like `vX.Y.Z` unless the user asks for another pattern.
- Verify the tag points at `HEAD` before finishing.
- Prefer GitHub Releases when the user wants the app bundle attached for download, and prefer `.zip` over `.dmg`.
