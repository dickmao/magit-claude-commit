;;; magit-claude-commit.el --- Generate commit messages with Claude Code -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Generated with Claude Code
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (magit "3.0.0") (project-claude "0.0.1"))
;; Keywords: vc, tools, git, ai
;; URL: https://github.com/yourusername/magit-claude-commit

;; This file is not part of GNU Emacs.

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This package integrates project-claude with Magit to automatically
;; generate commit messages based on staged changes.
;;
;; When you initiate a commit in Magit, this package will:
;; 1. Gather the staged diff and recent commit history
;; 2. Send this context to Claude Code via project-claude
;; 3. Insert the generated commit message into the commit buffer
;;
;; You can then edit, accept, or delete the generated message as desired.
;;
;; Setup:
;;   (require 'magit-claude-commit)
;;   (magit-claude-commit-mode 1)
;;
;; Customization:
;;   M-x customize-group RET magit-claude-commit RET

;;; Code:

(require 'magit-git)
(require 'git-commit)
(require 'project-claude)

;;; Customization

(defgroup magit-claude-commit nil
  "Generate commit messages with Claude Code."
  :group 'magit-extensions
  :prefix "magit-claude-commit-")

(defcustom magit-claude-commit-timeout 30
  "Timeout in seconds for Claude Code responses."
  :type 'integer
  :group 'magit-claude-commit)

(defcustom magit-claude-commit-context-lines 10
  "Number of recent commit messages to include for style context."
  :type 'integer
  :group 'magit-claude-commit)

(defcustom magit-claude-commit-additional-instructions ""
  "Additional instructions to include in the prompt to Claude.
This can be used to customize the style or content of generated messages."
  :type 'string
  :group 'magit-claude-commit)

(defcustom magit-claude-commit-verbose nil
  "If non-nil, show debugging information in messages buffer."
  :type 'boolean
  :group 'magit-claude-commit)

(defun magit-claude-commit--log-message (format-string &rest args)
  "Log a message if `magit-claude-commit-verbose' is non-nil."
  (when magit-claude-commit-verbose
    (apply #'message (concat "[magit-claude-commit] " format-string) args)))

(defun magit-claude-commit--get-staged-diff ()
  "Get the diff of staged changes."
  (magit-git-string "diff" "--staged"))

(defun magit-claude-commit--get-recent-commits ()
  "Get recent commit messages for style context."
  (magit-git-lines "log"
                   (format "-%d" magit-claude-commit-context-lines)
                   "--pretty=format:%s"))

(defun magit-claude-commit--build-prompt (diff recent-commits)
  "Build the prompt for Claude Code CLI.
DIFF is the staged changes, RECENT-COMMITS is a list of recent commit messages."
  (concat
   "Generate a concise git commit message for the following staged changes. "
   "Follow conventional commit format and best practices. "
   "The message should have a clear, imperative mood summary line (50-72 chars), "
   "followed by a blank line and then a more detailed explanation if needed.\n\n"
   (when (and recent-commits (> (length recent-commits) 0))
     (concat "Here are some recent commit messages from this repository for style reference:\n"
             (mapconcat (lambda (msg) (concat "- " msg)) recent-commits "\n")
             "\n\n"))
   (when (and magit-claude-commit-additional-instructions
              (not (string-empty-p magit-claude-commit-additional-instructions)))
     (concat "Additional instructions: " magit-claude-commit-additional-instructions "\n\n"))
   "Staged changes:\n"
   diff
   "\n\n"
   "Please provide ONLY the commit message, without any additional commentary or explanation."))

(defun magit-claude-commit--call-claude (prompt)
  "Send PROMPT to Claude Code via project-claude and return the response.
Returns nil if the call fails or times out."
  (condition-case err
      (let ((claude-buf (project-claude :no-solicit t))
            (response-marker nil))
        (unless claude-buf
          (error "Failed to get project-claude buffer"))

        (magit-claude-commit--log-message "Sending prompt to Claude Code...")

        (with-current-buffer claude-buf
          ;; Mark current position to detect response
          (setq response-marker (project-claude/cursor-pos))

          ;; Send the prompt
          (project-claude/issue-this prompt)

          ;; Wait for response with timeout
          (let ((start-time (current-time))
                (response nil))
            (while (and (not response)
                        (< (float-time (time-since start-time))
                           magit-claude-commit-timeout))
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

            (if response
                (progn
                  (magit-claude-commit--log-message "Received response")
                  response)
              (magit-claude-commit--log-message "Timed out waiting for response")
              nil))))
    (error
     (magit-claude-commit--log-message "Error calling Claude: %s" (error-message-string err))
     nil)))

(defun magit-claude-commit--insert-message ()
  "Generate and insert a commit message using Claude Code CLI.
This function is designed to be added to `git-commit-setup-hook'."
  ;; Only run if buffer is empty (except for comments)
  (when (save-excursion
          (goto-char (point-min))
          (while (and (not (eobp))
                      (or (looking-at "^$")
                          (looking-at (concat "^" comment-start))))
            (forward-line 1))
          (eobp))

    (magit-claude-commit--log-message "Starting commit message generation...")

    (let* ((diff (magit-claude-commit--get-staged-diff))
           (recent-commits (magit-claude-commit--get-recent-commits))
           (prompt (magit-claude-commit--build-prompt diff recent-commits))
           (response (magit-claude-commit--call-claude prompt)))

      (if response
          (progn
            (magit-claude-commit--log-message "Generated commit message")
            ;; Insert at the beginning of the buffer
            (save-excursion
              (goto-char (point-min))
              (insert response)
              ;; Ensure there's a blank line between message and comments
              (unless (looking-at "\n\n")
                (insert "\n"))))
        (magit-claude-commit--log-message "Failed to generate commit message")))))

;;;###autoload
(define-minor-mode magit-claude-commit-mode
  "Toggle automatic commit message generation with Claude Code.

When enabled, this mode adds a hook to `git-commit-setup-hook' that
automatically generates commit messages using Claude Code CLI based on
staged changes."
  :global t
  :group 'magit-claude-commit
  :lighter " Claude"
  (if magit-claude-commit-mode
      (progn
        (add-hook 'git-commit-setup-hook #'magit-claude-commit--insert-message)
        (magit-claude-commit--log-message "Mode enabled"))
    (remove-hook 'git-commit-setup-hook #'magit-claude-commit--insert-message)
    (magit-claude-commit--log-message "Mode disabled")))

;;; Interactive commands

;;;###autoload
(defun magit-claude-commit-generate ()
  "Manually generate and insert a commit message at point.
This can be used to regenerate a message or generate one if the
automatic generation was skipped."
  (interactive)
  (unless (derived-mode-p 'git-commit-mode)
    (user-error "Not in a git commit buffer"))
  (let* ((diff (magit-claude-commit--get-staged-diff))
         (recent-commits (magit-claude-commit--get-recent-commits))
         (prompt (magit-claude-commit--build-prompt diff recent-commits))
         (response (magit-claude-commit--call-claude prompt)))
    (if (not response)
	(user-error "Failed to generate commit message")
      (insert response))))

(provide 'magit-claude-commit)

;;; magit-claude-commit.el ends here
