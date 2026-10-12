{ pkgs
, lib
, username
, moduleTags
, ...
}:
{

  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        #keepassxc
      ];
      programs.firefox = {
        #      package = pkgs.unstable.librewolf;
        # package = pkgs.firefox-bin;
        enable = true;
        configPath = "/home/${username}/.config/mozilla/firefox";
        # nativeMessagingHosts.packages = [ pkgs.firefoxpwa ];
        policies = {
          DisablePocket = true;
          DisplayBookmarksToolbar = true;
          DontCheckDefaultBrowser = true;
          OfferToSaveLogins = false;
          NoDefaultBookmarks = true;
          PasswordManagerEnable = false;
          #DNSOverHTTPS = {
          #  Enabled = true;
          #};
          InstallAddonsPermission.Default = true;
          ExtensionSettings = {
            "uBlock0@raymondhill.net" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              installation_mode = "force_installed";
            };
            "floccus@handmadeideas.org" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/floccus/latest.xpi";
              #install_url = "https://addons.mozilla.org/firefox/downloads/file/4620792/floccus-5.8.0.xpi";
              installation_mode = "force_installed";
            };
            "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
              #install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
              install_url = "https://addons.mozilla.org/firefox/downloads/file/4619294/bitwarden_password_manager-2025.11.0.xpi";
              installation_mode = "force_installed";
            };
            "sponsorBlocker@ajay.app" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/file/4608179/sponsorblock-6.1.0.xpi";
              installation_mode = "force_installed";
            };

            "foxyproxy@eric.h.jung" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/foxyproxy-standard/latest.xpi";
              installation_mode = "force_installed";
            };
            "{60f82f00-9ad5-4de5-b31c-b16a47c51558}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/cookie-quick-manager/latest.xpi";
              installation_mode = "force_installed";
            };
            "{a6c4a591-f1b2-4f03-b3ff-767e5bedf4e7}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/user-agent-string-switcher/latest.xpi";
              installation_mode = "force_installed";
            };
            "darkreader" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
              installation_mode = "force_installed";
            };
            "gesturefy" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/gesturefy/latest.xpi";
              installation_mode = "force_installed";
            };
            #"raindropio" = {
            #  install_url = "https://addons.mozilla.org/firefox/downloads/latest/raindropio/latest.xpi";
            #  installation_mode = "force_installed";
            #};
          };
          #Extensions = {
          #  Install = [
          #    "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/"
          #    "https://addons.mozilla.org/firefox/downloads/latest/screenshot-capture-annotate/"
          #    "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/"
          #    "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/"
          #  ];
          #};
        };
        profiles.nixos = {
          id = 0;
          isDefault = true;
          name = "nixos";
          settings = {
            "browser.search.separatePrivateDefault" = false;
            "browser.search.separatePrivateDefault.ui.enabled" = true;
            #"browser.startup.homepage" = "http://dashboard.internal.flake.sh/";
            "network.trr.mode" = 5;
            "dom.security.https_first" = true;
            #"dom.security.https_only_mode" = true;
            #"dom.security.https_only_mode_ever_enabled" = true;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

            "browser.cache.memory.enable" = true;
            "browser.cache.memory.capacity" = -1;
            "browser.cache.memory.max_entry_size" = 51200;
            "browser.cache.disk.enable" = false;

            "browser.display.background_color.dark" = "#1e1e2e";
            "browser.discovery.enabled" = false;
            "browser.startup.homepage" = "about:blank";
            "general.smoothScroll" = true;
            "signon.autofillForms" = false;
            "widget.non-native-theme.scrollbar.style" = 3;
            "browser.uidensity" = 0;
            "browser.compactmode.show" = true;
            "breakpad.reportURL" = "";
            "browser.urlbar.trimHttps" = true;
            "browser.urlbar.trimURLs" = true;
            "browser.urlbar.suggest.calculator" = true;
            "extensions.htmlaboutaddons.recommendations.enabled" = false;
            "extensions.getAddons.showPane" = false;
            "extensions.postDownloadThirdPartyPrompt" = false;
            "browser.preferences.moreFromMozilla" = false;
            "browser.tabs.tabmanager.enabled" = false;

            "browser.tabs.groups.enable" = true;
            "browser.tabs.groups.smart.enabled" = true;
            "extensions.pocket.enable" = false;
            # "sidebar.visibility" = "expand-on-hover"; #"always-show";
            "sidebar.visibility" = "always-show";
            "sidebar.main.tools" = "aichat,history,bookmarks";
            "sidebar.expandOnHover" = true;
            "sidebar.verticalTabs" = true;
            "browser.toolbars.bookmarks.visibility" = "always";

            "browser.aboutwelcome.enabled" = false;
            "extensions.formautofill.addresses.enabled" = false;
            "gfx.webrenderer.compositor.force-enabled" = true;
            "security.sandbox.gpu.level" = if lib.elem "wsl" moduleTags then 0 else 1;
            "accessibility.browsewithcaret.enabled" = false;
            "accessibility.browsewithcaret_shortcut.enabled" = false;

          };
          # userChrome = builtins.readFile ../../../static_file/firefox/userChrome.css;
          #extraConfig = builtins.readFile ./user.js/betterfox.js;
          search = {
            default = "cnbing";
            force = true;
            engines = {
              "cnbing" = {
                urls = [
                  {
                    template = "https://cn.bing.com";
                    params = [
                      {
                        name = "q";
                        value = "{searchTerms}";
                      }
                    ];
                  }
                ];
                definedAliases = [
                  "@c"
                  "@b"
                  "@bing"
                ];
              };
              "SearXNG xlei.eu.org" = {
                urls = [
                  {
                    #template = "https://opnxng.com/";
                    template = "https://s.xlei.eu.org/";
                    params = [
                      {
                        name = "q";
                        value = "{searchTerms}";
                      }
                    ];
                  }
                ];
                icon = "https://s.xlei.eu.org/static/themes/simple/img/favicon.png";
                definedAliases = [
                  "@sx"
                  "@xl"
                ];
              };
              "Nix Packages" = {
                urls = [
                  {
                    template = "https://search.nixos.org/packages";
                    params = [
                      {
                        name = "type";
                        value = "packages";
                      }
                      {
                        name = "query";
                        value = "{searchTerms}";
                      }
                    ];
                  }
                ];
                #icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                icon = "https://search.nixos.org/favicon.ico";
                definedAliases = [
                  "@np"
                  "@nix"
                  "@nixos"
                ];
              };
              "github" = {
                urls = [
                  {
                    template = "https://github.com/search";
                    params = [
                      {
                        name = "q";
                        value = "{searchTerms}";
                      }
                    ];
                  }
                ];
                icon = "https://github.com/favicon.ico";
                definedAliases = [
                  "@git"
                  "@gh"
                  "@github"
                ];
              };
              #"bing".metaData.hidden = true;
              #"google".metaData.hidden = true;
              "google".metaData.alias = "@g";
              "amazondotcom-us".metaData.hidden = true;
              "ebay".metaData.hidden = true;
              "ddg".metaData.hidden = false;
            };

          };

          #  extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          #    # https://nur.nix-community.org/repos/rycee/
          #    bitwarden
          #    floccus
          #    gesturefy
          #    firefox-color
          #    user-agent-string-switcher
          #  ];

        };
      };

    };
  };

}
