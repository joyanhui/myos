{
  lib,
  global_settings,
  pkgs ? null,
}:
let
  data = builtins.fromJSON (builtins.readFile ./pkg_locks_versions.json);

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
in
{
  inherit
    entries
    getEntry
    sourceUrl
    fetchSource
    withGithubProxy
    ;
}
