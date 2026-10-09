#!/bin/bash

if [[ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]]; then
  TESTFLIGHT_DIR_PATH=../TestFlight
  mkdir $TESTFLIGHT_DIR_PATH
  git fetch --deepen 3 && git log -3 --pretty=format:"%s" >! $TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt
fi

set -euo pipefail

# Configuration
: "${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"
: "${GITHUB_REPOSITORY:?Missing GITHUB_REPOSITORY}"
: "${APP_NAME:?Missing APP_NAME}"

# Only run after a successful macOS archive
[[ "${CI_XCODEBUILD_ACTION:-}" == "archive" ]] || exit 0
[[ "${CI_XCODEBUILD_EXIT_CODE:-1}" == "0" ]] || exit 0
[[ "${CI_PRODUCT_PLATFORM:-}" == "macOS" ]] || exit 0

# Use Xcode Cloud's Developer ID export
EXPORT="${CI_DEVELOPER_ID_SIGNED_APP_PATH:?Missing signed app export}"

APP="$EXPORT/$APP_NAME.app"
[[ -d "$APP" ]] || {
    echo "App not found: $APP"
    exit 1
}

# Get version from app metadata
VERSION=$(/usr/libexec/PlistBuddy \
    -c "Print CFBundleShortVersionString" \
    "$APP/Contents/Info.plist")

TAG="${CI_TAG:-v$VERSION}"
ZIP_NAME="${APP_NAME}-${TAG}-macOS.zip"

# Only publish builds started from a Git tag
[[ -n "${CI_TAG:-}" ]] || {
    echo "Not a tagged build; skipping release."
    exit 0
}

[[ "$TAG" == "v$VERSION" ]] || {
    echo "Tag does not match app version"
    exit 1
}

# Create ZIP without modifying the signed app
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ditto -c -k --keepParent "$APP" "$WORK/$ZIP_NAME"

# GitHub API helper
API="https://api.github.com/repos/$GITHUB_REPOSITORY"

github_api() {
    curl --fail-with-body -sS \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2026-03-10" \
        "$@"
}

# Create a draft release
RELEASE_JSON=$(github_api \
    -X POST "$API/releases" \
    -H "Content-Type: application/json" \
    -d "$(/usr/bin/plutil -convert json -o - - <<EOF
{
    tag_name = "$TAG";
    name = "$TAG";
    draft = YES;
    prerelease = NO;
    generate_release_notes = YES;
}
EOF
)")

RELEASE_ID=$(printf '%s' "$RELEASE_JSON" |
    /usr/bin/plutil -extract id raw -)

[[ -n "$RELEASE_ID" ]] || {
    echo "Failed to create GitHub release"
    exit 1
}

# Upload ZIP
UPLOAD_URL="https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$RELEASE_ID/assets"

github_api \
    -X POST \
    -H "Content-Type: application/zip" \
    --data-binary "@$WORK/$ZIP_NAME" \
    "$UPLOAD_URL?name=$ZIP_NAME" >/dev/null

# Publish release after successful upload
github_api \
    -X PATCH "$API/releases/$RELEASE_ID" \
    -H "Content-Type: application/json" \
    -d '{"draft":false}' >/dev/null

echo "Published GitHub Release: $TAG"
echo "https://github.com/$GITHUB_REPOSITORY/releases/tag/$TAG"
