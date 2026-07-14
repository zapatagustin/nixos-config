;;; modules/keybinds.el -*- lexical-binding: t; -*-
;; Custom keybindings on top of doom's defaults (SPC leader).

(map! :leader
      ;; mirror the muscle memory that matters; doom already covers most
      :desc "Vertical split"   "w /" #'evil-window-vsplit
      :desc "Magit status"     "g g" #'magit-status)

;; jk to escape insert mode would go here if wanted:
;; (setq evil-escape-key-sequence "jk")
