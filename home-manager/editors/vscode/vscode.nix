{ ... }:
{
    home-manager.users.thinkpad = { pkgs, ...}: {
      programs.vscode = {
        enable = true;
        package = pkgs.vscode;
        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix
          pkief.material-icon-theme
        ];
        # In case extensions are not loaded, refer to https://github.com/nix-community/home-manager/issues/3507
        userSettings = {
          "workbench.iconTheme" = "material-icon-theme";
          "window.dialogStyle" = "custom";
          "window.titleBarStyle" = "custom";
          "editor.fontFamily" =  "UDEV Gothic, Consolas, 'Courier New', monospace";
          "editor.fontSize" =  12;
          "editor.fontWeight" =  300;
          "editor.lineHeight" =  20;
          "editor.letterSpacing" =  0.5;
          "editor.fontLigatures" =  true;
          "editor.wordWrap" =  "on";
          "editor.formatOnPaste" =  true;
          "editor.cursorBlinking" =  "smooth";
        };
      };
    };
}
