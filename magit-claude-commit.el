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

(require 'magit-git)
(require 'git-commit)
(require 'project-claude)

(defgroup magit-claude-commit nil
  "Generate commit messages with Claude Code."
  :group 'magit-extensions
  :prefix "magit-claude-commit/")

(defcustom magit-claude-commit/timeout 30
  "Timeout in seconds for Claude Code responses."
  :type 'integer
  :group 'magit-claude-commit)

(how-many "%s" (point-min) (point-max))

(defun magit-claude-commit//prompt ()
  (let ((prompt-file (expand-file-name
		      "commit-prompt.txt"
		      (file-name-directory (or load-file-name
					       buffer-file-name)))))
    (with-temp-buffer
      (insert-file-contents prompt-file)
      (buffer-string)))

(magit-claude-commit//prompt)




(defun magit-claude-commit//get-it ()
  "Return a string."
  (with-current-buffer (or (project-claude/get-buffer :no-solicit t)
			   (error "project-claude/get-buffer failed"))
    (let ((start (project-claude/cursor-pos)))
      (project-claude/say prompt)
      (let ((start-time (current-time))
            (response nil))
	(while (and (not response)
                    (< (float-time (time-since start-time))
		       magit-claude-commit/timeout))
          ;; Wait for new output after our marker
          (when (project-claude//wait-for project-claude/prompt-regex response-marker)
            ;; Extract response between marker and new prompt
            (save-excursion
	      (goto-char response-marker)
	      (when (re-search-forward project-claude/prompt-regex nil t)
		(let ((end (match-beginning 0)))
                  (goto-char response-marker)
                  (when (re-search-forward project-claude/prompt-regex end t)
                    (setq response (string-trim
                                    (buffer-substring-no-properties
                                     (match-end 0) end))))))))
          (unless response
            (accept-process-output vterm--process 0.5 nil t)))
	response))))

(defun magit-claude-commit//insert ()
  (if-let ((commit-message (magit-claude-commit//get-it)))
      (save-excursion
	(goto-char (point-min))
	(insert commit-message)
	(unless (looking-at "\n\n")
          (insert "\n")))
    (error "Could not automate commit message")))

;;;###autoload
(add-hook 'git-commit-setup-hook #'magit-claude-commit//insert)

(provide 'magit-claude-commit)

;;; magit-claude-commit.el ends here
