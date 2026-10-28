# Publishing this fork

This fork is published to npm as [`@lagregance/react-native-webview`](https://www.npmjs.com/package/@lagregance/react-native-webview) using a manual local script (`scripts/publish.sh`).

## Prerequisites

1. **npm account with access to the `@lagregance` scope.**

   ```sh
   npm login
   npm whoami   # must succeed
   ```

   The scope is created automatically on first publish if your account owns it.

2. **Node + Bun** (the repo's toolchain, see `bun.lock`). Install dependencies once with:

   ```sh
   bun install --frozen-lockfile
   ```

3. **Clean git working tree.** The script refuses to run if `git status` shows any uncommitted change — this guarantees the published tarball matches a real commit.

## Bumping the version

The script does **not** bump the version automatically. Edit the `version` field in `package.json` yourself, then commit it:

```sh
# example: patch bump
npm version patch --no-git-tag-version
git add package.json
git commit -m "chore: release vX.Y.Z"
```

(`--no-git-tag-version` is important — the publish script creates and pushes the tag itself after a successful publish.)

## Publishing

```sh
./scripts/publish.sh
# or
bun run publish:npm
```

The script will:

1. Verify the working tree is clean.
2. Verify you're logged in to npm.
3. Print the package name + version and ask for confirmation.
4. Run `bun install --frozen-lockfile`, `bun run lint`, then `bun run prepare` (emits `.d.ts` types and Babel-compiles `src/` → `lib/`).
5. Run `npm publish`. The `publishConfig.access: public` field in `package.json` makes the scoped package public.
6. Create a `vX.Y.Z` git tag and push it to `origin`.

## Verifying without publishing

To inspect the tarball that would be published without actually uploading anything:

```sh
bun run prepare
npm pack --dry-run
```

This prints every file that will be included and the final filename (`lagregance-react-native-webview-X.Y.Z.tgz`).

## Consuming the package

In another project:

```sh
yarn add @lagregance/react-native-webview
# then
import { WebView } from '@lagregance/react-native-webview';
```

Native autolinking, the iOS podspec, and the `react-native.config.js` entry all work the same as upstream — only the package name changes.
