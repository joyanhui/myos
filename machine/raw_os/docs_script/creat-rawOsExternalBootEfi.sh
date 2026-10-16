#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [-o output.efi]" >&2
  exit 2
}

output="nixos-img.efi"
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
script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do
  script_dir="$(cd -P -- "$(dirname -- "$script_path")" && pwd)"
  script_path="$(readlink -- "$script_path")"
  case "$script_path" in
    /*) ;;
    *) script_path="$script_dir/$script_path" ;;
  esac
done
script_dir="$(cd -P -- "$(dirname -- "$script_path")" && pwd)"
if ! repo_dir="$(cd -P -- "$script_dir/../../.." && pwd)"; then
  echo "error: unable to locate the repository root from the script path" >&2
  exit 1
fi
if [ ! -f "$repo_dir/flake.nix" ]; then
  echo "error: repository root does not contain flake.nix: $repo_dir" >&2
  exit 1
fi

source_efi=$(
  cd -- "$repo_dir"
  nix build --no-link --print-out-paths \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.rawOsExternalBootEfi
)

[ -n "$source_efi" ] || {
  echo "error: rawOsExternalBootEfi output was empty" >&2
  exit 1
}
output_dir="$(dirname -- "$output")"
mkdir -p -- "$output_dir"
temporary=$(mktemp -- "$output_dir/.raw-os-external-boot.XXXXXX")
cleanup() {
  rm -f -- "$temporary"
}
trap cleanup EXIT

cp --reflink=auto -- "$source_efi" "$temporary"
chmod 0644 -- "$temporary"
mv -f -- "$temporary" "$output"
temporary=""

printf 'created: %s\n' "$output"
printf 'source: %s\n' "$source_efi"
