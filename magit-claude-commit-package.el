;;; magit-claude-commit-package.el --- because package.el sucks ass  -*- lexical-binding:t -*-

(require 'package)
(require 'project)

(defsubst magit-claude-commit-package-where ()
  (directory-file-name (expand-file-name (project-root (project-current)))))

(defsubst magit-claude-commit-package-desc ()
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "magit-claude-commit.el" (magit-claude-commit-package-where)))
    (package-buffer-info)))

(defun magit-claude-commit-package-name ()
  (concat "magit-claude-commit-" (package-version-join
				  (package-desc-version
				   (magit-claude-commit-package-desc)))))

(defun magit-claude-commit-package-inception ()
  "To get a -pkg.el file, you need to run `package-unpack'.
To run `package-unpack', you need a -pkg.el."
  (let ((pkg-desc (magit-claude-commit-package-desc))
	(pkg-dir (expand-file-name (magit-claude-commit-package-name)
				   (magit-claude-commit-package-where))))
    (ignore-errors (delete-directory pkg-dir t))
    (make-directory pkg-dir t)
    (dolist (el (split-string "magit-claude-commit.el"))
      (copy-file (expand-file-name el (magit-claude-commit-package-where))
		 (expand-file-name el pkg-dir)))
    (package--make-autoloads-and-stuff pkg-desc pkg-dir)))
