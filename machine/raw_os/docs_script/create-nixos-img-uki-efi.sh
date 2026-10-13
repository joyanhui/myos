#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <uki-file-or-directory> [-o output.efi]" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage
uki_source=$1
shift
output=nixos-img.efi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      [ "$#" -ge 2 ] || usage
      output=$2
      shift 2
      ;;
    -*)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -d "$uki_source" ]; then
  uki_source="$uki_source/nixos-img.efi"
fi

[ -f "$uki_source" ] || {
  echo "error: UKI file not found: $uki_source" >&2
  exit 1
}

case "$output" in
  ''|*/)
    echo "error: output must be a file path: $output" >&2
    exit 1
    ;;
esac

output_dir=$(dirname "$output")
mkdir -p "$output_dir"
tmp=$(mktemp "$output_dir/.nixos-img.efi.XXXXXX")
trap 'rm -f "$tmp"' EXIT
cp --reflink=auto "$uki_source" "$tmp"
chmod 0644 "$tmp"
mv -f "$tmp" "$output"
trap - EXIT

echo "created: $output"
echo "source: $uki_source"
