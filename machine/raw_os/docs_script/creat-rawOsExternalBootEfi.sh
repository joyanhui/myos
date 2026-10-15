#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [-o output.efi]" >&2
  exit 2
}

output="$(pwd)/nixos-img.efi"
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      [ "$#" -ge 2 ] || usage
      output=$2
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

case "$output" in
  ''|*/)
    echo "error: output must be a file path: $output" >&2
    exit 1
    ;;
esac
case "$output" in
  /*) ;;
  *) output="$(pwd)/$output" ;;
esac

repo_dir="${REPO_DIR:?REPO_DIR must point to the repository}"

source_efi=$(
  cd "$repo_dir"
  nix build --no-link --print-out-paths \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.rawOsExternalBootEfi
)

[ -n "$source_efi" ] || {
  echo "error: rawOsExternalBootEfi output was empty" >&2
  exit 1
}
output_dir=$(dirname "$output")
mkdir -p "$output_dir"
temporary=$(mktemp "$output_dir/.raw-os-external-boot.XXXXXX")
cleanup() {
  rm -f "$temporary"
}
trap cleanup EXIT

cp --reflink=auto "$source_efi" "$temporary"
chmod 0644 "$temporary"
mv -f "$temporary" "$output"
temporary=""

printf 'created: %s\n' "$output"
printf 'source: %s\n' "$source_efi"
