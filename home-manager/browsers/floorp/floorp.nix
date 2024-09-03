{ ... }: {
      home-manager.thinkpad.programs.floorp = {
        enable = true;
        profiles = {
          thinkpad = {
            id = 0;
            name = "thinkpad";
            search = {
              force = true;
              default = "Google";
              engines = {
                "Nix Packages" = {
                    urls = [{
                        template = "https://search.nixos.org/packages";
                        params = [
                            { name = "type"; value = "packages"; }
                            { name = "query"; value = "{searchTerms}"; }
                        ];
                    }];
                    icon = "/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                    definedAliases = [ "@np" ];
                };

                "NixOS Wiki" = {
                    urls = [{ template = "https://wiki.nixos.org/index.php?search={searchTerms}"; }];
                    iconUpdateURL = "https://wiki.nixos.org/favicon.png";
                    updateInterval = 24 * 60 * 60 * 1000;
                    definedAliases = [ "@nw" ];
                };

                "Wikipedia (en)".metaData.alias = "@wiki";
                "Google".metaData.hidden = true;
                "Amazon.com".metaData.hidden = true;
                "Bing".metaData.hidden = true;
                "eBay".metaData.hidden = true;
              };
            };

            settings = {
              #"browser.startup.homepage" = "https://start.duckduckgo.com";
              "browser.places.importBookmarksHTML" = true;
              "general.smoothScroll" = true;
              # Re-bind ctrl to super (would interfere with tridactyl otherwise)
              #"ui.key.accelKey" = 91; # Commented otherwise cannot use shortcuts using CTRL
              # Hide the "sharing indicator", it's especially annoying
              # with tiling WMs on wayland
              "privacy.webrtc.legacyGlobalIndicator" = false;
              # Actual settings
              "app.shield.optoutstudies.enabled" = false;
              "app.update.auto" = true;
              "browser.bookmarks.restore_default_bookmarks" = false;
              "browser.contentblocking.category" = "strict";
              "browser.ctrlTab.recentlyUsedOrder" = false;
              "browser.discovery.enabled" = false;
              "browser.laterrun.enabled" = false;
              "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" =
                false;
              "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" =
                false;
              "browser.newtabpage.activity-stream.feeds.snippets" = false;
              "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
              "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
              "browser.newtabpage.activity-stream.section.highlights.includePocket" =
                false;
              "browser.newtabpage.activity-stream.showSponsored" = false;
              "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
              "browser.newtabpage.pinned" = false;
              "browser.protections_panel.infoMessage.seen" = true;
              "browser.quitShortcut.disabled" = true;
              "browser.shell.checkDefaultBrowser" = false;
              "browser.ssb.enabled" = true;
              "browser.toolbars.bookmarks.visibility" = "always";
              #"browser.urlbar.placeholderName" = "DuckDuckGo";
              "browser.urlbar.suggest.openpage" = false;
              "datareporting.policy.dataSubmissionEnable" = false;
              "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;
              "dom.security.https_only_mode" = true;
              "dom.security.https_only_mode_ever_enabled" = true;
              "extensions.getAddons.showPane" = false;
              "extensions.htmlaboutaddons.recommendations.enabled" = false;
              "extensions.pocket.enabled" = false;
              "identity.fxaccounts.enabled" = false;
              "privacy.trackingprotection.enabled" = true;
              "privacy.trackingprotection.socialtracking.enabled" = true;
            };

            extraConfig = ''
              user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
              user_pref("full-screen-api.ignore-widgets", true);
              user_pref("media.ffmpeg.vaapi.enabled", true);
              user_pref("media.rdd-vpx.enabled", true);
            '';
          };
        };
        # Here the list of all Firefox policies: https://mozilla.github.io/policy-templates/
        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          EnableTrackingProtection = {
            Value= true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };

          CaptivePortal = false;
          #NoDefaultBookmarks = false; # This policy must be removed or set to false, otherwise bookmarks cannot be added or removed by Nix
          OfferToSaveLogins = false;
          OfferToSaveLoginsDefault = false;
          PasswordManagerEnabled = false;
          FirefoxHome = {
              Search = true;
              Pocket = false;
              Snippets = false;
              TopSites = false;
              Highlights = false;
          };

          UserMessaging = {
              ExtensionRecommendations = false;
              SkipOnboarding = true;
          };

          DisablePocket = true;
          DisableFirefoxAccounts = false;
          DisableAccounts = false;
          DisableFirefoxScreenshots = true;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DontCheckDefaultBrowser = true;
          DisplayBookmarksToolbar = "always"; # alternatives: "never" or "newtab"
          DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
          SearchBar = "unified"; # alternative: "separate"
          ExtensionSettings = {
            "*".installation_mode = "blocked";
            # uBlock Origin:
            "uBlock0@raymondhill.net" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              installation_mode = "force_installed";
            };
            # Sponsorblock
            "Sponsorblock" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
              installation_mode = "force_installed";
            };
            # Bitwarden
            "Bitwarden" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden/latest.xpi";
              installation_mode = "force_installed";
            };
            # Xbrowsersync
            #"xbrowsersync" = {
            #  install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            #  installation_mode = "force_installed";
            #};
            # Return Youtube Dislike
            "returnyoutubedislike" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
              installation_mode = "force_installed";
            };
          };
        };
      };
}
