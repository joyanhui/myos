SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +1
sudo nix-env --profile /nix/var/nix/profiles/per-user/root/channels --delete-generations +1
sudo nix-env --profile /nix/var/nix/profiles/per-user/nixos/channels --delete-generations +1
sudo nix-env --profile /nix/var/nix/profiles/per-user/nixos/profile --delete-generations +1
sudo nix-env --profile /nix/var/nix/profiles/per-user/nixos/home-manager --delete-generations +1
if [ -L "${REPO_ROOT:?}/result" ]; then
  echo "删除 ${REPO_ROOT}/result GC root..."
  rm -f "$REPO_ROOT/result"
fi

nix-collect-garbage
nix-collect-garbage -d
echo '=============================== meybe need to run ==============================='
echo 'nix-store --gc --print-roots '
echo 'nix-store --optimise '
echo 'sudo nix-store --verify --check-contents --repair'
