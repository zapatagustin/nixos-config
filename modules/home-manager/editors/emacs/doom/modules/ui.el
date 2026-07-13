;;; modules/ui.el -*- lexical-binding: t; -*-
;; Theme, fonts, frame.

;; stylix doesn't manage doom; theme is set here.
(setq doom-theme 'doom-one)

;; same mono font stylix uses everywhere else (Terminess Nerd Font)
(setq doom-font (font-spec :family "Terminess Nerd Font Mono" :size 16)
      doom-variable-pitch-font (font-spec :family "Terminess Nerd Font Mono" :size 16))

;; relative line numbers, like neovim
(setq display-line-numbers-type 'relative)

;; slightly less aggressive dashboard
(setq fancy-splash-image nil)
