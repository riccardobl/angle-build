#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-${VERSION:-}}"
INPUT_DIR="${PACKAGE_INPUT_DIR:-angle-artifacts}"
OUTPUT_DIR="${PACKAGE_OUTPUT_DIR:-dist}"
ARTIFACT_ID="${ARTIFACT_ID:-angle-natives}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: VERSION=<version> $0 [version]" >&2
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory not found: $INPUT_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/${ARTIFACT_ID}-${VERSION}.jar"
rm -f "$OUTPUT_DIR/${ARTIFACT_ID}-${VERSION}-"*.jar

BUNDLE_DIR="$(mktemp -d)"
trap 'rm -rf "$BUNDLE_DIR"' EXIT

found_artifacts=0
shopt -s nullglob
for artifact_dir in "$INPUT_DIR"/*; do
  [[ -d "$artifact_dir" ]] || continue
  found_artifacts=1

  classifier="$(basename "$artifact_dir")"
  rsync -a "$artifact_dir/" "$BUNDLE_DIR/"
  jar cf "$OUTPUT_DIR/${ARTIFACT_ID}-${VERSION}-${classifier}.jar" -C "$artifact_dir" .
done
shopt -u nullglob

if [[ "$found_artifacts" -eq 0 ]]; then
  echo "No staged artifacts found in $INPUT_DIR" >&2
  exit 1
fi

jar cf "$OUTPUT_DIR/${ARTIFACT_ID}-${VERSION}.jar" -C "$BUNDLE_DIR" .
