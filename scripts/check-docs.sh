#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(tr -d '[:space:]' < "$ROOT/BUILD_NUMBER")"

fail() {
    echo "DOCS_CHECK=FAIL $1" >&2
    exit 1
}

grep -Fq "public static let current = \"$VERSION\"" \
    "$ROOT/Sources/WatermarkCore/AppVersion.swift" || fail "AppVersion version mismatch"
grep -Fq "public static let build = \"$BUILD_NUMBER\"" \
    "$ROOT/Sources/WatermarkCore/AppVersion.swift" || fail "AppVersion build mismatch"
test "$(plutil -extract CFBundleShortVersionString raw "$ROOT/Resources/Info.plist")" = "$VERSION" \
    || fail "Info.plist version mismatch"
test "$(plutil -extract CFBundleVersion raw "$ROOT/Resources/Info.plist")" = "$BUILD_NUMBER" \
    || fail "Info.plist build mismatch"

versions=("${(@f)$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' "$ROOT/CHANGELOG.md")}")
(( ${#versions[@]} > 0 )) || fail "no version sections in CHANGELOG.md"
changelog_versions="$(printf '%s\n' $versions | sort -V)"
tag_versions="$(git -C "$ROOT" tag --list 'v*' | sed 's/^v//' | sort -V)"
if git -C "$ROOT" rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    test "$changelog_versions" = "$tag_versions" || fail "Git tags and CHANGELOG versions differ"
    VERSION_STATE="tagged"
else
    released_versions="$(printf '%s\n' $versions | grep -Fxv "$VERSION" | sort -V)"
    test "$released_versions" = "$tag_versions" \
        || fail "released CHANGELOG versions and Git tags differ"
    VERSION_STATE="development"
fi

for version in $versions; do
    directory="$ROOT/docs/prd/v$version"
    for name in prd design dev plan; do
        file="$directory/$name.md"
        test -f "$file" || fail "missing docs/prd/v$version/$name.md"
        head -n 1 "$file" | grep -Fq "v$version" || fail "wrong heading in $file"
    done

    report="$ROOT/docs/testing/v$version-test-report.md"
    notes="$ROOT/docs/RELEASE_NOTES_v$version.md"
    test -f "$report" || fail "missing test report for v$version"
    test -f "$notes" || fail "missing release notes for v$version"
    head -n 1 "$report" | grep -Fq "v$version" || fail "wrong heading in $report"
    head -n 1 "$notes" | grep -Fq "v$version" || fail "wrong heading in $notes"
    grep -Fq "[\`v$version\`](./v$version/)" "$ROOT/docs/prd/README.md" \
        || fail "v$version missing from PRD index"
done

grep -Fq "版本：\`$VERSION ($BUILD_NUMBER)\`" \
    "$ROOT/docs/testing/v$VERSION-test-report.md" || fail "current test report version mismatch"
grep -Fq "WatermarkFlow-v$VERSION-macos-universal.zip" \
    "$ROOT/docs/INSTALL.md" || fail "installation archive version mismatch"
grep -Fq "v$VERSION PRD" "$ROOT/README.md" || fail "README current PRD link mismatch"
grep -Fq "25%、50%、75%、100%、125%、150%、200%、300%、400%、500%、750%、1000%" \
    "$ROOT/docs/prd/v0.4.1/prd.md" || fail "documented zoom levels mismatch"
grep -Fq 'private static let canvasZoomLevels = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 5, 7.5, 10]' \
    "$ROOT/Sources/WatermarkFlowApp/EditorViewModel.swift" || fail "implemented zoom levels changed"

broken_links=()
for file in "$ROOT"/**/*.md(.N); do
    while IFS= read -r reference; do
        link="$(printf '%s\n' "$reference" | /usr/bin/sed -E 's/^[^(]*\(([^)]*)\)$/\1/')"
        case "$link" in
            http://*|https://*|mailto:*|\#*) continue ;;
        esac
        target="${link%%#*}"
        test -e "${file:h}/$target" || broken_links+=("${file#$ROOT/}: $link")
    done < <(/usr/bin/grep -Eo '\[[^]]+\]\([^)]+\)' "$file" || true)
done
(( ${#broken_links[@]} == 0 )) || fail "broken Markdown links:\n${(F)broken_links}"
MARKDOWN_COUNT="$(find "$ROOT" -type f -name '*.md' -not -path '*/.build/*' | wc -l | tr -d '[:space:]')"

echo "DOCS_CHECK=PASS"
echo "DOCS_VERSION=$VERSION"
echo "DOCS_BUILD=$BUILD_NUMBER"
echo "DOCS_RELEASE_COUNT=${#versions[@]}"
echo "DOCS_MARKDOWN_COUNT=$MARKDOWN_COUNT"
echo "DOCS_VERSION_STATE=$VERSION_STATE"
