;;; modules/dvorak.el -*- lexical-binding: t; -*-
;; dvorak: evil commands land on QWERTY physical positions; insert mode and
;; the minibuffer (vertico, / searches) stay dvorak. Same idea as neovim's
;; langmap (editors/neovim/lua/options.lua) — translation table is identical.

(defconst +dvorak-qwerty-alist
  ;; row 1: ' , . p y f g c r l / =  ->  q w e r t y u i o p [ ]
  '(("'" . "q") ("," . "w") ("." . "e") ("p" . "r") ("y" . "t") ("f" . "y")
    ("g" . "u") ("c" . "i") ("r" . "o") ("l" . "p") ("/" . "[") ("=" . "]")
    ("\"" . "Q") ("<" . "W") (">" . "E") ("P" . "R") ("Y" . "T") ("F" . "Y")
    ("G" . "U") ("C" . "I") ("R" . "O") ("L" . "P") ("?" . "{") ("+" . "}")
    ;; row 2: o e u i d h t n s -  ->  s d f g h j k l ; '
    ("o" . "s") ("e" . "d") ("u" . "f") ("i" . "g") ("d" . "h") ("h" . "j")
    ("t" . "k") ("n" . "l") ("s" . ";") ("-" . "'")
    ("O" . "S") ("E" . "D") ("U" . "F") ("I" . "G") ("D" . "H") ("H" . "J")
    ("T" . "K") ("N" . "L") ("S" . ":") ("_" . "\"")
    ;; row 3: ; q j k x b w v z  ->  z x c v b n , . /
    (";" . "z") ("q" . "x") ("j" . "c") ("k" . "v") ("x" . "b") ("b" . "n")
    ("w" . ",") ("v" . ".") ("z" . "/")
    (":" . "Z") ("Q" . "X") ("J" . "C") ("K" . "V") ("X" . "B") ("B" . "N")
    ("W" . "<") ("V" . ">") ("Z" . "?")
    ;; number row tail: [ ] -> - =
    ("[" . "-") ("]" . "=") ("{" . "_") ("}" . "+")))

(defun +dvorak--command-state-p ()
  "Non-nil when keys should act as commands (translate), not text (don't)."
  (and (bound-and-true-p evil-local-mode)
       (not (minibufferp))
       (memq evil-state '(normal visual motion operator))))

(dolist (pair +dvorak-qwerty-alist)
  (let ((from (car pair))
        (to (cdr pair)))
    (define-key key-translation-map (kbd from)
      (lambda (_prompt)
        (kbd (if (+dvorak--command-state-p) to from))))))
