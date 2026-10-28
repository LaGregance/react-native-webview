#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is dirty. Commit or stash changes before publishing." >&2
  exit 1
fi

if ! npm whoami >/dev/null 2>&1; then
  echo "Error: not logged in to npm. Run 'npm login' first." >&2
  exit 1
fi

VERSION=$(node -p "require('./package.json').version")
NAME=$(node -p "require('./package.json').name")

echo "About to publish ${NAME}@${VERSION}"
read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

bun install --frozen-lockfile
bun run lint
bun run prepare

npm publish

git tag "v${VERSION}"
git push origin "v${VERSION}"

echo "Published ${NAME}@${VERSION}"
