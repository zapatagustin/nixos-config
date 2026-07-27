;;; init.el -*- lexical-binding: t; -*-
;; Doom module selection. After changing this file: rebuild, then `doom sync`.

(doom! :completion
       (corfu +orderless)     ; in-buffer completion
       (vertico +icons)       ; minibuffer completion (telescope-ish)

       :ui
       doom                   ; doom themes + faces
       dashboard
       hl-todo                ; highlight TODO/FIXME/NOTE
       modeline
       ophints                ; highlight the region an operation acts on
       (popup +defaults)
       (vc-gutter +pretty)    ; git diff markers in the fringe
       vi-tilde-fringe
       workspaces

       :editor
       (evil +everywhere)     ; vim everywhere
       file-templates
       fold
       (format +onsave)       ; apheleia; per-lang formatters in modules/lang.el
       snippets

       :emacs
       dired
       electric
       undo
       vc

       :term
       vterm                  ; module binary comes prebuilt from nix (default.nix)

       :checkers
       syntax
       (spell +hunspell)      ; en_US + es_AR dicts via nix (hunspellWithDicts)

       :tools
       (eval +overlay)
       lookup
       lsp                    ; servers come from nix, never from doom
       magit

       :os
       tty

       :lang
       emacs-lisp
       json
       markdown
       (nix +lsp)             ; nixd
       (org +pretty)
       (sh +lsp)              ; bash-language-server
       yaml
       ;; disabled until needed (add the LSP server to default.nix when enabling)
       ;; (python +lsp)
       ;; (rust +lsp)
       ;; lua

       :config
       (default +bindings +smartparens))
