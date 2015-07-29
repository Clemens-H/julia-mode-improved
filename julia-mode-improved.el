;;;; Time-stamp: <julia-mode-improved.el  Clemens  2015-07-29 16:32 CEST>

;;;; julia-mode-improved.el --- Improvements for the Julia Emacs mode

;;;; Copyright (C) 2014-2015 Clemens Heitzinger
;;;; URL: http://Clemens.Heitzinger.name
;;;; Version: 0.1
;;;; Keywords: languages, Julia


;;; Usage:

;; As of 28 July 2015, it is recommended to use the Julia mode in the
;; Julia github repository or the one in melpa, since it is much more
;; current than the Julia mode in melpa-stable.

;; First, to use the official Julia mode, you may need to put the
;; following code in your .emacs, site-load.el, or other relevant
;; file:

;; (autoload 'julia-mode "$HOME/src/julia-dev/contrib/julia-mode" "Julia mode" t)
;; (add-to-list 'auto-mode-alist '("\\.jl\\'" . julia-mode))

;; Second, to use the present file, put the following code in your
;; .emacs, site-load.el, or other relevant file:

;; (eval-after-load "julia-mode"
;;   '(require 'julia-mode-improved))

;; Finally, after visiting a Julia buffer, you can type C-h m to see a
;; list of the new commands and key bindings.


;;; Commentary:

;; This file contains improvements to the official Emacs mode for
;; editing Julia programs.  It includes commands for searching and
;; viewing documentation, default key bindings for commonly used
;; commands in the mode specific key map, and commands for loading and
;; evaluating Julia code in Mac OS X terminals (which is much faster
;; than comint).


;;; License:

;; GPL v2: https://www.gnu.org/licenses/gpl-2.0.html

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


;;; Code:

;; (unless (member 'julia-mode (mapcar #'cdr auto-mode-alist))
;;   (add-to-list 'auto-mode-alist '("\\.jl\\'" . julia-mode)))

;;; Retrieve documentation

;; The following two functions are from on ESS's Julia mode.
(defvar julia-manual-topics nil)

(defun julia-retrieve-topics (url)
  (require 'url)
  (with-current-buffer (url-retrieve-synchronously url)
    (goto-char (point-min))
    (let ((out '()))
      (while (re-search-forward "toctree.*href=\"\\(.+\\)\">\\(.+\\)</a" nil t)
        (push (propertize (match-string 2)
                          :manual (concat url (match-string 1)))
              out))
      (kill-buffer)
      (nreverse out))))

(defun julia-documentation ()
  "Look up topics at http://docs.julialang.org/en/latest/manual/"
  (interactive)
  (when (null julia-manual-topics)
    (setq julia-manual-topics
          (julia-retrieve-topics "http://docs.julialang.org/en/latest/manual/")))
  (let* ((completion-ignore-case t)
         (page (completing-read "Lookup: " julia-manual-topics nil t)))
    (browse-url (get-text-property 0 :manual
                                   (find page julia-manual-topics :test #'string=)))))

;;; Define keys

(define-key julia-mode-map (kbd "TAB") 'julia-latexsub-or-indent)
(define-key julia-mode-map "\C-cd" 'julia-documentation)
(define-key julia-mode-map "\C-c!" 'julia-execute-buffer-as-script)

(when (eq system-type 'darwin)
  (define-key julia-mode-map "\C-ca" 'julia-apropos)
  (define-key julia-mode-map "\C-ce" 'julia-eval)
  (define-key julia-mode-map "\C-ch" 'julia-help)
  (define-key julia-mode-map "\C-cl" 'julia-load)
  (define-key julia-mode-map "\C-cm" 'julia-methods)
  (define-key julia-mode-map "\C-cq" 'julia-quit)
  (define-key julia-mode-map "\C-cs" 'julia-shell)
  (define-key julia-mode-map "\C-cw" 'julia-whos))

;;; How to evaluate and load Julia code (also in Mac OS X Terminal.app terminals)

(defvar julia-program-name "julia")

(defun julia-execute-buffer-as-script ()
  (interactive)
  (shell-command (format "%s --no-history-file --quiet --load \"%s\""
                         julia-program-name (buffer-file-name))))

(defun julia-escape-double-quotes (string)
  "Return STRING with every double quote escaped by a backslash."
  (save-match-data
    (replace-regexp-in-string "\"" "\\\\\"" string)))

(defun julia-send (string)
  "Execute Julia code in STRING in a Terminal.app process running
Julia, starting a Julia process if necessary."
  (do-applescript
   (concat "tell application \"Terminal\"
              set found to false
              repeat with w in (get windows)
                repeat with t in (get tabs of w)
                  if (not found) and (processes of t contains \"julia\") then
                    set found to true
                    set win to w
                    set selected of t to true
                  end if
                end repeat
              end repeat

              if (not found) then
                set win to front window
                do script \"cd \\\"" (file-name-directory (buffer-file-name)) "\\\" && " julia-program-name "\" in win
              end if

              do script \"" (julia-escape-double-quotes string) "\" in win
            end tell")))

(defun julia-apropos (string)
  (interactive "sApropos: ")
  (julia-send (concat "apropos(\"" string "\")")))

(defun julia-eval (string)
  (interactive "sEvaluate: ")
  (julia-send string))

(defun julia-help (string)
  (interactive (list (read-string "help?> " (current-word))))
  (julia-send (concat "?" string)))

(defvar julia-load-prefix ""
  "Prefix used when loading Julia files.  For example,
\"@time \" will show how long it took to load a file.")

(defun julia-load ()
  "Load the current buffer using Julia's include."
  (interactive)
  (save-buffer)
  (save-some-buffers)
  (julia-eval (concat julia-load-prefix "@everywhere include(\"" (buffer-file-name) "\")")))

(defun julia-methods (string)
  (interactive (list (read-string "Show methods of: " (current-word))))
  (julia-send (concat "methods(" string ")")))

(defun julia-quit ()
  "Quit Julia."
  (interactive)
  (julia-send "quit()"))

(defun julia-shell (string)
  (interactive "sshell> ")
  (julia-send (concat ";" string)))

(defun julia-whos ()
  "Run whos() in Julia."
  (interactive)
  (julia-send "whos()"))

;;; Provide feature

(provide 'julia-mode-improved)

;;;; local variables:
;;;; coding: utf-8
;;;; end:
