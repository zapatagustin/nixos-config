;;; modules/editor.el -*- lexical-binding: t; -*-
;; Editing behavior.

(setq scroll-margin 8)                 ; like neovim's scrolloff
(setq-default tab-width 2)

;; ask which window when splitting/jumping with >2 windows
(setq evil-split-window-below t
      evil-vsplit-window-right t)

;; don't nag about killing processes on exit
(setq confirm-kill-processes nil)

;; autosave/undo persist across sessions (doom enables undo-fu-session)
(setq auto-save-default t)
