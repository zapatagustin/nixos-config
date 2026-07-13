;;; modules/lang.el -*- lexical-binding: t; -*-
;; Per-language settings. LSP servers/formatters live in default.nix.

;; nix: format with nixpkgs-fmt (the flake formatter), not nixfmt
(after! apheleia
  (setf (alist-get 'nixpkgs-fmt apheleia-formatters) '("nixpkgs-fmt"))
  (setf (alist-get 'nix-mode apheleia-mode-alist) 'nixpkgs-fmt))

;; org
(setq org-directory "~/org/")
