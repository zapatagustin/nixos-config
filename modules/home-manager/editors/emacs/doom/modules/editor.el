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

;; Spellcheck backend is hunspell (see init.el +hunspell). es_AR ships Argentine
;; idioms; code/comments keep the en_US default, prose buffers switch to es_AR.
(after! ispell
  (setq ispell-dictionary "en_US"))
(add-hook! '(org-mode-hook markdown-mode-hook gfm-mode-hook)
  (ispell-change-dictionary "es_AR"))
