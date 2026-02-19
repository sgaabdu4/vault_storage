#!/bin/bash
# Usage: ./release.sh [patch|minor|major] "Description of changes"
# Example: ./release.sh patch "Upgraded all dependencies"
# Example: ./release.sh minor "Added custom box support"

set -e

BUMP_TYPE=${1:-patch}
DESCRIPTION=${2:-"Maintenance update"}

if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
  echo "❌ Invalid bump type: $BUMP_TYPE (use patch, minor, or major)"
  exit 1
fi

# Parse current version
CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d '\r')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
DATE=$(date +%Y-%m-%d)

echo "📦 Bumping $CURRENT → $NEW_VERSION ($BUMP_TYPE)"

# Update pubspec.yaml
sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

# Prepend CHANGELOG entry
CHANGELOG_ENTRY="## [$NEW_VERSION] - $DATE\n### Changes\n- $DESCRIPTION\n"
# Use a temp file for portable sed
{
  echo -e "$CHANGELOG_ENTRY"
  cat CHANGELOG.md
} > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md

echo "✅ Version bumped to $NEW_VERSION"
echo "✅ CHANGELOG.md updated"
echo ""
echo "Next steps:"
echo "  git add pubspec.yaml CHANGELOG.md"
echo "  git commit -m 'chore(release): bump version to $NEW_VERSION'"
echo "  git push"
echo ""
echo "After merge, tag + publish happen automatically."
