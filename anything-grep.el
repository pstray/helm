;;; anything-grep.el --- search refinement of grep result with anything
;; $Id: anything-grep.el,v 1.12 2008-12-29 09:40:23 rubikitch Exp $

;; Copyright (C) 2008  rubikitch

;; Author: rubikitch <rubikitch@ruby-lang.org>
;; Keywords: convenience, unix
;; URL: http://www.emacswiki.org/cgi-bin/wiki/download/anything-grep.el

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Do grep in anything buffer. When we search information with grep,
;; we often narrow the candidates. Let's use `anything' to do it.

;; `anything-grep' is simple interface to grep a query. It asks
;; directory to grep. The grep process is synchronous process. You may
;; have to wait when you grep the target for the first time. But once
;; the target is on the disk cache, queries are grepped at lightning
;; speed. Even if older Pentium4 computer, grepping from 180MB takes
;; only 0.2s! GNU grep is amazingly fast.

;; `anything-grep-by-name' asks query and predefined location. It is
;; good idea to have ack (ack-grep), grep implemented in Perl, to
;; exclude unneeded files. Such as RCS, .svn and so on.

;; ack -- better than grep, a power search tool for programmers
;;  http://petdance.com/ack/


   
;;; History:

;; $Log: anything-grep.el,v $
;; Revision 1.12  2008-12-29 09:40:23  rubikitch
;; document
;;
;; Revision 1.11  2008/12/29 07:58:37  rubikitch
;; refactoring
;;
;; Revision 1.10  2008/10/21 18:02:02  rubikitch
;; use *anything grep* buffer instead.
;;
;; Revision 1.9  2008/10/12 17:17:23  rubikitch
;; `anything-grep-by-name': swapped query order
;;
;; Revision 1.8  2008/10/09 00:33:40  rubikitch
;; New variable: `anything-grep-save-buffers-before-grep'
;;
;; Revision 1.7  2008/10/09 00:26:00  rubikitch
;; `anything-grep-by-name': nil argument
;;
;; Revision 1.6  2008/10/05 15:43:09  rubikitch
;; changed spec: `anything-grep-alist'
;;
;; Revision 1.5  2008/10/02 18:27:55  rubikitch
;; Use original fontify code instead of font-lock.
;; New variable: `agrep-find-file-function'
;;
;; Revision 1.4  2008/10/01 18:18:18  rubikitch
;; use ack-grep command to select files for search.
;;
;; Revision 1.3  2008/10/01 17:18:59  rubikitch
;; silence byte compiler
;;
;; Revision 1.2  2008/10/01 17:17:59  rubikitch
;; many bug fix
;; New command: `anything-grep-by-name'
;;
;; Revision 1.1  2008/10/01 10:58:59  rubikitch
;; Initial revision
;;

;;; Code:

(defvar anything-grep-version "$Id: anything-grep.el,v 1.12 2008-12-29 09:40:23 rubikitch Exp $")
(require 'anything)
(require 'grep)

(defvar anything-grep-save-buffers-before-grep nil
  "Do `save-some-buffers' before performing `anything-grep'.")

(defvar agrep-goto-hook nil
  "List of functions to be called after `agrep-goto' opens file.")

(defvar agrep-find-file-function 'find-file
  "Function to visit a file with.
It takes one argument, a file name to visit.")

(defvar anything-grep-alist
  "Mapping of location and command/pwd used by `anything-grep-by-name'.
The command is grep command line. Note that %s is replaced by query.
The command is typically \"ack-grep -af | xargs egrep -Hin %s\", which means
regexp/case-insensitive search for all files (including subdirectories)
except unneeded files.

The pwd is current directory to grep.

The format is:

  ((LOCATION1
     (COMMAND1-1 PWD1-1)
     (COMMAND1-2 PWD1-2)
     ...)
   (LOCATION2
     (COMMAND2-1 PWD2-1)
     (COMMAND2-2 PWD2-2)
     ...)
   ...)
"
  '(("memo" ("ack-grep -af | xargs egrep -Hin %s" "~/memo"))
    ("PostgreSQL" ("egrep -Hin %s *.txt" "~/doc/postgresql-74/"))
    ("~/bin and ~/ruby"
     ("ack-grep -afG 'rb$' | xargs egrep -Hin %s" "~/ruby")
     ("ack-grep -af | xargs egrep -Hin %s" "~/bin"))))

;; (@* "core")
(defun anything-grep-base (sources)
  "Invoke `anything' for `anything-grep'."
  (and anything-grep-save-buffers-before-grep
       (save-some-buffers (not compilation-ask-about-save) nil))
  (anything sources nil nil nil nil "*anything grep*"))

;; (anything (list (agrep-source "grep -Hin agrep anything-grep.el" default-directory) (agrep-source "grep -Hin pwd anything-grep.el" default-directory)))

(defun agrep-source (command pwd)
  "Anything Source of `anything-grep'."
  `((name . ,(format "%s [%s]" command pwd))
    (command . ,command)
    (pwd . ,pwd)
    (init . agrep-init)
    (candidates-in-buffer)
    (action . agrep-goto)
    (candidate-number-limit . 9999)
    (migemo)
    ;; to inherit faces
    (get-line . buffer-substring)))

(defun agrep-init ()
  (agrep-create-buffer (anything-attr 'command)  (anything-attr 'pwd)))

(defun agrep-do-grep (command pwd)
  "Insert result of COMMAND. The current directory is PWD.
GNU grep is expected for COMMAND. The grep result is colorized."
  (let ((process-environment process-environment))
    (when (eq grep-highlight-matches t)
      ;; Modify `process-environment' locally bound in `call-process-shell-command'.
      (setenv "GREP_OPTIONS" (concat (getenv "GREP_OPTIONS") " --color=always"))
      ;; for GNU grep 2.5.1
      (setenv "GREP_COLOR" "01;31")
      ;; for GNU grep 2.5.1-cvs
      (setenv "GREP_COLORS" "mt=01;31:fn=:ln=:bn=:se=:ml=:cx=:ne"))
    (call-process-shell-command (format "cd %s; %s" pwd command)
                                nil (current-buffer))))

(defun agrep-fontify ()
  "Fontify the result of `agrep-do-grep'."
  ;; Color matches.
  (goto-char 1)
  (while (re-search-forward "\\(\033\\[01;31m\\)\\(.*?\\)\\(\033\\[[0-9]*m\\)" nil t)
    (put-text-property (match-beginning 2) (match-end 2) 'face  grep-match-face)
    (replace-match "" t t nil 1)
    (replace-match "" t t nil 3))
  ;; Delete other escape sequences.
  (goto-char 1)
  (while (re-search-forward "\\(\033\\[[0-9;]*[mK]\\)" nil t)
    (replace-match "" t t nil 0)))

(defun agrep-create-buffer (command pwd)
  "Create candidate buffer for `anything-grep'.
Its contents is fontified grep result."
  (with-current-buffer (anything-candidate-buffer 'global)
    (setq default-directory pwd)
    (agrep-do-grep command pwd)
    (agrep-fontify)
    (current-buffer)))
;; (display-buffer (agrep-create-buffer "grep --color=always -Hin agrep anything-grep.el" default-directory))
;; (anything '(((name . "test") (init . (lambda () (anything-candidate-buffer (get-buffer " *anything grep:grep --color=always -Hin agrep anything-grep.el*")) )) (candidates-in-buffer) (get-line . buffer-substring))))

(defun agrep-goto  (file-line-content)
  "Visit the source for the grep result at point."
  (string-match ":\\([0-9]+\\):" file-line-content)
  (save-match-data
    (funcall agrep-find-file-function
             (expand-file-name (substring file-line-content
                                          0 (match-beginning 0))
                               (anything-attr 'pwd))))
  (goto-line (string-to-number (match-string 1 file-line-content)))
  (run-hooks 'agrep-goto-hook))

;; (@* "simple grep interface")
(defun anything-grep (command pwd)
  "Run grep in `anything' buffer to narrow results.
It asks COMMAND for grep command line and PWD for current directory."
  (interactive
   (progn
     (grep-compute-defaults)
     (let ((default (grep-default-command)))
       (list (read-from-minibuffer "Run grep (like this): "
				   (if current-prefix-arg
				       default grep-command)
				   nil nil 'grep-history
				   (if current-prefix-arg nil default))
             (read-directory-name "Directory: " default-directory default-directory t)))))
  (anything-grep-base (list (agrep-source command pwd))))
;; (anything-grep "grep -Hin agrep anything-grep.el" default-directory)

;; (@* "grep in predefined files")
(defvar agbn-last-name nil
  "The last used name by `anything-grep-by-name'.")

(defun anything-grep-by-name (&optional name query)
  "Do `anything-grep' from predefined location.
It asks NAME for location name and QUERY."
  (interactive)
  (setq query (or query (read-string "Grep query: ")))
  (setq name (or name
                 (completing-read "Grep by name: " anything-grep-alist nil t nil nil agbn-last-name)))
  (setq agbn-last-name name)
  (anything-aif (assoc-default name anything-grep-alist)
      (progn
        (grep-compute-defaults)
        (anything-grep-base
         (mapcar (lambda (args)
                   (destructuring-bind (cmd dir) args
                     (agrep-source (format cmd (shell-quote-argument query)) dir)))
                 it)))
    (error "no such name %s" name)))

(provide 'anything-grep)

;; How to save (DO NOT REMOVE!!)
;; (emacswiki-post "anything-grep.el")
;;; anything-grep.el ends here
