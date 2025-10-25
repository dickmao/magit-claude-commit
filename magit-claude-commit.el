;;; magit-claude-commit.el --- No one reads commit messages anyway -*- lexical-binding: t; -*-
;; Copyright (C) 2025 dickmao
;;
;; Author: dickmao
;; Version: 0.0.1
;; URL: https://github.com/commercial-emacs/magit-claude-commit
;; Package-Requires: ((magit "4.0.0"))

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

(require 'git-commit)
(require 'project-claude nil t)

(defgroup magit-claude-commit nil
  "Defgroups are bullshit."
  :group 'tools
  :prefix "magit-claude-commit-")

(defcustom magit-claude-commit-invocation
  (or (bound-and-true-p project-claude/invocation)
      "claude")
  "Command line shell invocation."
  :group 'magit-claude-commit
  :type 'string)

(defconst magit-claude-commit-fence "^```")

(defun magit-claude-commit-get ()
  "Return a string."
  (let ((prompt-file (expand-file-name
		      "commit-prompt.txt"
		      (file-name-directory
		       (locate-library "magit-claude-commit")))))
    (with-temp-buffer
      (call-process magit-claude-commit-invocation nil t nil
                    "-p" (with-temp-buffer
                           (insert-file-contents prompt-file)
                           (buffer-string)))
      (goto-char (point-min))
      (if (re-search-forward magit-claude-commit-fence nil t)
	  (progn
            (forward-line 1)
            (let ((start (point)))
              (re-search-forward magit-claude-commit-fence)
	      (beginning-of-line)
	      (buffer-substring start (point))))
	;; print the error
	(buffer-string)))))

(defun magit-claude-commit-insert ()
  (interactive)
  (message "Generating...")
  (insert (magit-claude-commit-get))
  (when (looking-at-p "\n\n")
    (delete-char 1))
  (message "Generating...done"))

(define-key git-commit-mode-map (kbd "C-c C-M-i")
	    #'magit-claude-commit-insert)

(provide 'magit-claude-commit)

;;; magit-claude-commit.el ends here
