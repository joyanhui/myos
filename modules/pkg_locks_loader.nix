{
  lib,
  global_settings,
  pkgs ? null,
}:
let
  data = builtins.fromJSON (builtins.readFile ./pkg_locks_versions.json);

  jsonPath = "${global_settings.repoDir}/modules/pkg_locks_versions.json";

  githubPrefix = "https://github.com/";

  fillTemplate =
    entry: source: text:
    let
      replacements = [
        {
          name = "{version}";
          value = entry.version;
        }
        {
          name = "{rev}";
          value = source.rev or "";
        }
        {
          name = "{source_version}";
          value = source.version or "";
        }
      ];
    in
    builtins.foldl' (
      acc: replacement: builtins.replaceStrings [ replacement.name ] [ replacement.value ] acc
    ) text replacements;

  isGitArchive = source: (source.type or "url") == "git-archive";

  normalizeSource =
    name: sourceName: entry: source:
    let
      label = "${name}.${sourceName}";
      hasUrl = source ? url;
      hasHash = source ? hash;
    in
    assert lib.assertMsg hasUrl "pkg_locks_versions.json 中 ${label} 缺少 url";
    assert lib.assertMsg (isGitArchive source -> source ? rev) "pkg_locks_versions.json 中 ${label} 缺少 rev";
    assert lib.assertMsg hasHash "pkg_locks_versions.json 中 ${label} 缺少 hash";
    {
      url = fillTemplate entry source source.url;
      inherit (source) hash;
      unpack = source.unpack or (isGitArchive source);
      pinned = source.pinned or false;
    }
    // lib.optionalAttrs (source ? rev) {
      inherit (source) rev;
    }
    // lib.optionalAttrs (source ? version) {
      inherit (source) version;
    };

  normalizeEntry =
    name: entry:
    assert lib.assertMsg (entry ? version) "pkg_locks_versions.json 中 ${name} 缺少 version";
    assert lib.assertMsg (entry ? sources && entry.sources != { })
      "pkg_locks_versions.json 中 ${name} 缺少 sources";
    {
      inherit (entry) version;
      version_check = entry.version_check or { type = "manual"; };
      sources = lib.mapAttrs (sourceName: normalizeSource name sourceName entry) entry.sources;
      derivations = entry.derivations or { };
    };

  entries = builtins.mapAttrs normalizeEntry data.packages;

  getEntry =
    name:
    if entries ? ${name} then
      entries.${name}
    else
      throw "pkg_locks_versions.json 中不存在 ${name}";

  withGithubProxy =
    url:
    if lib.hasPrefix githubPrefix url then
      "${global_settings.ghProxy}/${url}"
    else
      url;

  sourceUrl =
    name: sourceName:
    let
      entry = getEntry name;
    in
    if entry.sources ? ${sourceName} then
      withGithubProxy entry.sources.${sourceName}.url
    else
      throw "${name} 中不存在 source ${sourceName}";

  fetchSource =
    name: sourceName:
    let
      entry = getEntry name;
      source =
        entry.sources.${sourceName} or (throw "${name} 中不存在 source ${sourceName}");
      url = withGithubProxy source.url;
    in
    assert lib.assertMsg (pkgs != null) "fetchSource 需要传入 pkgs";
    if source.unpack then
      pkgs.fetchzip {
        inherit url;
        inherit (source) hash;
      }
    else
      pkgs.fetchurl {
        inherit url;
        inherit (source) hash;
      };

  updater =
    assert lib.assertMsg (pkgs != null) "updater 需要传入 pkgs";
    pkgs.writers.writePython3Bin "pkg-locks-update" {
      flakeIgnore = [
        "E501"
        "W503"
        "E203"
      ];
    }
  ''
    import argparse
    import base64
    import json
    import os
    import re
    import subprocess
    import sys

    REPO_DIR_ENV = "REPO_DIR"
    DEFAULT_JSON = "${jsonPath}"
    GITHUB = "https://github.com/"
    NIX32 = "0123456789abcdfghijklmnpqrsvwxyz"
    MARKERS = [
        (b"!<arch>\n", "deb"),
        (b"\x7fELF", "elf"),
        (b"PK\x03\x04", "zip"),
        (b"\x1f\x8b", "gzip"),
        (b"MZ", "exe"),
    ]


    def fail(message):
        print("error: " + message, file=sys.stderr)
        sys.exit(2)


    def run(command, check=True):
        result = subprocess.run([part for part in command if part is not None], capture_output=True, text=True)
        if check and result.returncode != 0:
            fail("命令失败: %s\n%s" % (" ".join(command), result.stderr.strip()))
        return result


    def nix32_to_sri(value):
        size = len(value) * 5 // 8
        out = bytearray(size)
        for index, char in enumerate(reversed(value)):
            digit = NIX32.index(char)
            base = index * 5
            byte, shift = divmod(base, 8)
            out[byte] = (out[byte] | ((digit << shift) & 0xFF)) & 0xFF
            if byte + 1 < size:
                out[byte + 1] = (out[byte + 1] | (digit >> (8 - shift))) & 0xFF
        return "sha256-" + base64.b64encode(bytes(out)).decode()


    def gh_json(path, jq):
        return run(["gh", "api", path, "--jq", jq]).stdout.strip()


    def github_proxy(repo_dir):
        if not repo_dir:
            return ""
        result = run(
            ["nix", "eval", "--raw", "--file", os.path.join(repo_dir, "global_setting_vars.nix"), "ghProxy"],
            check=False,
        )
        return result.stdout.strip() if result.returncode == 0 else ""


    def request_url(url, proxy):
        return proxy + "/" + url if proxy and url.startswith(GITHUB) else url


    def check_marker(path, url):
        with open(path, "rb") as handle:
            head = handle.read(8)
        if any(head.startswith(marker) for marker, _ in MARKERS):
            return
        print("warning: 下载内容格式未知，请人工确认: " + url, file=sys.stderr)


    def prefetch(url, unpack):
        command = ["nix-prefetch-url"]
        if unpack:
            command.append("--unpack")
        command += ["--type", "sha256", url]
        result = run(command)
        digest = [line for line in result.stdout.strip().splitlines() if line][-1]
        path = None
        for line in result.stderr.splitlines():
            match = re.search(r"(/nix/store/[^'\s]+)", line)
            if match:
                path = match.group(1)
        return path, nix32_to_sri(digest)


    def fill(entry, source, text):
        for key, value in (
            ("{version}", entry.get("version", "")),
            ("{rev}", source.get("rev", "")),
            ("{source_version}", source.get("version", "")),
        ):
            text = text.replace(key, value)
        return text


    def detect_version(entry):
        check = entry.get("version_check", {"type": "manual"})
        kind = check.get("type", "manual")
        if kind == "github-release-latest":
            tag = gh_json("repos/%s/%s/releases/latest" % (check["owner"], check["repo"]), ".tag_name")
            return tag[1:] if tag.startswith("v") else tag, None
        if kind == "github-tag-latest":
            pattern = re.compile(check["match"]) if check.get("match") else None
            tags = gh_json("repos/%s/%s/tags?per_page=100" % (check["owner"], check["repo"]), ".[].name")
            for tag in tags.splitlines():
                if pattern is None or pattern.match(tag):
                    return tag, None
            return entry.get("version", ""), None
        if kind == "github-commit-latest":
            sha = gh_json("repos/%s/%s/commits/HEAD" % (check["owner"], check["repo"]), ".sha")
            date = gh_json(
                "repos/%s/%s/commits/%s" % (check["owner"], check["repo"], sha), ".commit.committer.date"
            )
            return date[:10], sha
        return entry.get("version", ""), None


    def deb_version(path):
        result = run(["dpkg-deb", "-f", path, "Version"], check=False)
        return result.stdout.strip() if result.returncode == 0 else ""


    def main():
        parser = argparse.ArgumentParser(description="更新 pkg_locks_versions.json 的版本号与 hash")
        parser.add_argument("--file", help="JSON 路径，默认 ${jsonPath}")
        parser.add_argument("--only", help="仅处理指定条目，逗号分隔")
        parser.add_argument("--check", action="store_true", help="只报告差异，返回码 1 表示有差异")
        parser.add_argument("--force", action="store_true", help="同时刷新 pinned 源")
        parser.add_argument("--no-proxy", action="store_true", help="不使用 ghProxy 前缀下载")
        args = parser.parse_args()

        repo_dir = os.environ.get(REPO_DIR_ENV, "")
        target = args.file or DEFAULT_JSON
        if not os.path.exists(target):
            fail("找不到文件: " + target)

        with open(target, encoding="utf-8") as handle:
            data = json.load(handle)

        proxy = "" if args.no_proxy else github_proxy(repo_dir)
        selected = set(args.only.split(",")) if args.only else None
        changes = []
        skipped = []

        for name, entry in data["packages"].items():
            if selected is not None and name not in selected:
                continue
            version, rev = detect_version(entry)
            if version and version != entry.get("version"):
                changes.append("%s version %s -> %s" % (name, entry.get("version"), version))
                entry["version"] = version
            primary = entry.get("sources", {}).get("src", {})
            if rev and primary.get("rev") != rev:
                changes.append("%s rev %s -> %s" % (name, primary.get("rev"), rev))
                primary["rev"] = rev

            for source_name, source in entry.get("sources", {}).items():
                if source.get("pinned") and not args.force:
                    skipped.append("%s.%s" % (name, source_name))
                    continue
                url = request_url(fill(entry, source, source["url"]), proxy)
                unpack = source.get("unpack", source.get("type") == "git-archive")
                path, sri = prefetch(url, unpack)
                if not unpack and path:
                    check_marker(path, url)
                if sri != source.get("hash"):
                    changes.append("%s.%s hash %s -> %s" % (name, source_name, source.get("hash"), sri))
                    source["hash"] = sri
                if entry.get("version_check", {}).get("version_from") == "deb-version" and path:
                    version = deb_version(path)
                    if version and version != entry.get("version"):
                        changes.append("%s version %s -> %s" % (name, entry.get("version"), version))
                        entry["version"] = version

            for derivation_name, derivation in entry.get("derivations", {}).items():
                skipped.append("%s.%s outputHash 需手动更新" % (name, derivation_name))
                if derivation.get("outputHash") is None:
                    fail("%s.%s 缺少 outputHash" % (name, derivation_name))

        for line in changes:
            print("changed: " + line)
        for line in skipped:
            print("skipped: " + line)
        if not changes:
            print("no changes")
            return 0
        if args.check:
            return 1
        with open(target, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        print("updated: " + target)
        return 0


    if __name__ == "__main__":
        sys.exit(main())
  '';

  updaterModule =
    { hmStandalone ? false, ... }:
    if hmStandalone then
      {
        home.packages = [ updater ];
      }
    else
      {
        environment.systemPackages = [ updater ];
      };
in
{
  inherit
    entries
    getEntry
    sourceUrl
    fetchSource
    withGithubProxy
    updater
    updaterModule
    ;
}
