;;; config.el -*- lexical-binding: t; -*-
;; Entry point only: identity + load the modular config from modules/.
;; Same pattern as neovim's lua/ split — one file per concern.

(setq user-full-name "zapatagustin"
      user-mail-address "zapatagustin4@gmail.com")

(load! "modules/dvorak")
(load! "modules/ui")
(load! "modules/editor")
(load! "modules/lang")
(load! "modules/keybinds")
