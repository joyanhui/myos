{ lib, moduleTags }:
let
  knownTags = [
    "common"
    "ai"
    "inputKeyd"
    "desktop"
    "gui"
    "dev"
    "editor"
    "input-method"
    "dailyPC"
    "services"
    "wsl"
    "amd"
    "intel"
  ];

  unknownTags = lib.subtractLists knownTags moduleTags;
in
assert lib.assertMsg (unknownTags == [ ])
  "未知 module tag: ${lib.concatStringsSep ", " unknownTags}（合法: ${lib.concatStringsSep ", " knownTags}）";
{
  importIf = condition: module: if condition then [ module ] else [ ];
  hasTag = tag: lib.elem tag moduleTags;
}
