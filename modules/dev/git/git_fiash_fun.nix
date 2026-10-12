{
  pkgs,
  username,
  lib,
  ...
}:
let
  commitTypes = import ./commit_prefix_list.nix;

  fishTypeLines = lib.concatStringsSep " \\\n        " (
    map (t: ''"${t.prefix} — ${t.description}"'') commitTypes
  );

  switchCases = lib.concatStringsSep "\n" (
    lib.imap1 (i: t: "                case ${toString i};  set prefix \"${t.prefix}\"") commitTypes
  );

  typesCount = builtins.toString (builtins.length commitTypes);
in
{
  home-manager = {
    users.${username} = { ... }: {
      programs.fish.functions = {
        gcp = {
          description = "交互式 Git 提交与推送（Conventional Commits）";
          body = ''
            set -l types \
                ${fishTypeLines}

            if not set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
                echo "当前目录不是 Git 仓库，已取消。"
                return 1
            end

            echo ""
            echo "========== 变更概览 =========="
            git -C $repo_root status --short
            echo "=============================="
            echo ""
            echo "请选择提交类型 (Conventional Commits):"
            echo ""
            for i in (seq (count $types))
                if test $i -lt 10
                    echo "  $i)  "$types[$i]
                else
                    echo "  $i) "$types[$i]
                end
            end

            echo ""
            read -l -P "输入序号 (1-${typesCount}) [默认 1]: " type_idx
            if test -z "$type_idx"
                set type_idx 1
            end

            set -l prefix
            switch $type_idx
                ${switchCases}
                case '*'
                    echo "无效输入，已取消。"
                    return 1
            end

            read -l -P "输入提交描述: " commit_msg
            if test -z "$commit_msg"
                echo "描述不能为空，已取消。"
                return 1
            end

            echo ""
            echo "即将执行: git add . && git commit -m \"$prefix: $commit_msg\" && git push"
            echo ""

            git -C $repo_root add .
            and git -C $repo_root commit -m "$prefix: $commit_msg"
            and git -C $repo_root push
            or echo "提交或推送失败，请检查错误信息。"
          '';
        };
      };
    };
  };
}
