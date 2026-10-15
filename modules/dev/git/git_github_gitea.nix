{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      programs.gh = {
        enable = true;
        settings = {
          git_protocol = "https";
        };
        gitCredentialHelper = {
          enable = true;
        };
      };

      programs.git = {
        enable = true;
        lfs = {
          enable = true;
        };
        settings = {
          user = {
            name = "joyanhui";
            email = "leiyanhui@gmail.com";
          };
          init = {
            defaultBranch = "main";
          };
          credential = {
            helper = "store";
          };
        };
      };
      home.packages = with pkgs; [
        gh
        git-crypt
        transcrypt
        git-lfs
        act
        gitui
        subversion
        /*
          export OWNER="joyanhui"
          export REPOSITORY="acme.sh"
          gh auth login

          gh api -X GET "/repos/$OWNER/$REPOSITORY/actions/runs?per_page=300" | jq '.workflow_runs[] | .id' | xargs -I{} sh -c 'echo {} && gh api --silent -X DELETE /repos/$OWNER/$REPOSITORY/actions/runs/{}'
        */
        github-runner
        gitea-actions-runner
      ];

    };
  };

}
