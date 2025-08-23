#!/bin/bash -eu
set -o pipefail
shopt -s inherit_errexit

# This script may run inside a Docker build context where .git has been
# excluded by .dockerignore. In that case, git commands will fail. We fall back
# to placeholder values so the build never breaks on missing metadata.

{
  echo "versions:"
  if git rev-parse HEAD >/dev/null 2>&1; then
    commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    tag=$(git describe --tags 2>/dev/null || echo "v0.0.0")
    echo "$commit ($tag)"
    # Enumerate submodules if any are present (will be silent otherwise)
    git submodule foreach --quiet --recursive \
      'commit=$(git rev-parse HEAD 2>/dev/null || echo unknown); \
       tag=$(git describe --tags 2>/dev/null || echo v0.0.0); \
       printf " %s %s (%s)\n" "$commit" "$path" "$tag"' || true
  else
    echo "unknown (no-git)"
  fi
} > /tmp/version.txt

echo "[write-version] generated /tmp/version.txt:" >&2
cat /tmp/version.txt >&2
