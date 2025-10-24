;;; magit-claude-commit.el --- No one reads commit messages anyway -*- lexical-binding: t; -*-
;; Copyright (C) 2025 dickmao
;;
;; Author: dickmao
;; Version: 0.0.1
;; URL: https://github.com/commercial-emacs/magit-claude-commit
;; Package-Requires: ((magit "4.0.0") (project-claude "0.0.1"))

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
(require 'project-claude)

(defconst magit-claude-commit//fence "^```")

(defun magit-claude-commit//get ()
  "Return a string."
  (let ((prompt-file (expand-file-name
		      "commit-prompt.txt"
		      (file-name-directory
		       (locate-library "magit-claude-commit")))))
    (with-temp-buffer
      (call-process project-claude/invocation nil t nil
                    "-p" (with-temp-buffer
                           (insert-file-contents prompt-file)
                           (buffer-string)))
      (goto-char (point-min))
      (when (re-search-forward magit-claude-commit//fence nil t)
        (forward-line 1)
        (let ((start (point)))
          (when (re-search-forward magit-claude-commit//fence nil t)
            (beginning-of-line)
            (buffer-substring-no-properties start (point))))))))

(defun magit-claude-commit//insert ()
  (let ((commit-message (magit-claude-commit//get)))
    (save-excursion
      (goto-char (point-min))
      (insert commit-message)
      (unless (looking-at "\n\n")
        (insert "\n")))))

(add-hook 'git-commit-setup-hook #'magit-claude-commit//insert)

(provide 'magit-claude-commit)

;;; magit-claude-commit.el ends here
