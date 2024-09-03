{pkgs, ...}: {
	environment.systemPackages = with pkgs; [
		nix-zsh-completions
		zsh-autosuggestions
		zsh-syntax-highlighting
	];
}
