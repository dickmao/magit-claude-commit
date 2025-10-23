SHELL := /bin/bash
EMACS ?= emacs
ELSRC := $(shell git ls-files magit-claude-commit*.el)
TESTSRC := $(shell git ls-files test*.el)
INSTALLDIR ?= package-user-dir
.PHONY: compile
compile: deps/archives/gnu/archive-contents
	$(EMACS) -batch \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  --eval "(setq package-user-dir (expand-file-name \"deps\"))" \
	  -f package-initialize \
	  -L . \
	  -f batch-byte-compile $(ELSRC) $(TESTSRC); \
	  (ret=$$? ; rm -f $(ELSRC:.el=.elc) $(TESTSRC:.el=.elc) && exit $$ret)

.PHONY: test
test: compile
	$(EMACS) --batch --eval "(setq package-user-dir (expand-file-name \"deps\"))" \
	  -f package-initialize \
	  -L . $(patsubst %.el,-l %,$(notdir $(TESTSRC))) \
	  -f ert-run-tests-batch

.PHONY: dist-clean
dist-clean:
	( \
	set -e; \
	PKG_NAME=`$(EMACS) -batch -L . -l magit-claude-commit-package --eval "(princ (magit-claude-commit-package-name))"`; \
	rm -rf $${PKG_NAME}; \
	rm -rf $${PKG_NAME}.tar; \
	)

.PHONY: dist
dist: dist-clean
	$(EMACS) -batch -L . -l magit-claude-commit-package -f magit-claude-commit-package-inception
	( \
	set -e; \
	PKG_NAME=`$(EMACS) -batch -L . -l magit-claude-commit-package --eval "(princ (magit-claude-commit-package-name))"`; \
	rsync -R $(ELSRC) $${PKG_NAME} && \
	tar cf $${PKG_NAME}.tar $${PKG_NAME}; \
	)

define install-recipe
	$(MAKE) dist
	( \
	set -e; \
	INSTALL_PATH=$(1); \
	if [[ "$${INSTALL_PATH}" == /* ]]; then INSTALL_PATH=\"$${INSTALL_PATH}\"; fi; \
	PKG_NAME=`$(EMACS) -batch -L . -l magit-claude-commit-package --eval "(princ (magit-claude-commit-package-name))"`; \
	$(EMACS) --batch -l package --eval "(setq package-user-dir (expand-file-name $${INSTALL_PATH}))" \
	  -f package-initialize \
	  --eval "(ignore-errors (apply (function package-delete) (alist-get (quote magit-claude-commit) package-alist)))" \
	  -f package-refresh-contents \
	  --eval "(package-install-file \"$${PKG_NAME}.tar\")"; \
	PKG_DIR=`$(EMACS) -batch -l package --eval "(setq package-user-dir (expand-file-name $${INSTALL_PATH}))" -f package-initialize --eval "(princ (package-desc-dir (car (alist-get 'magit-claude-commit package-alist))))"`; \
	)
	$(MAKE) dist-clean
endef

project-claude/project-claude.el:
	git clone --depth 1 https://github.com/commercial-emacs/project-claude.git

project-claude/deps/archives/gnu/archive-contents: project-claude/project-claude.el
	rm -rf deps
	$(MAKE) -C project-claude INSTALLDIR="$(CURDIR)/deps" install

deps/archives/gnu/archive-contents: project-claude/deps/archives/gnu/archive-contents
	$(call install-recipe,$(CURDIR)/deps)
	rm -rf deps/magit-claude-commit* # just keep deps

.PHONY: clean
clean: dist-clean
	git clean -dffX # ff because emacs-libvterm has a git subdir

.PHONY: install-project-claude
install-project-claude: project-claude/project-claude.el
	$(MAKE) -C project-claude INSTALLDIR=$(INSTALLDIR) install

.PHONY: install
install:
	2>/dev/null @$(EMACS) --batch -f package-initialize -l project-claude \
	  --eval "(or (version-list-<= '(0 0 1) \
	   (package-desc-version (car (alist-get 'project-claude package-alist)))) \
	   (error))" || $(MAKE) INSTALLDIR=$(INSTALLDIR) install-project-claude
	$(call install-recipe,$(INSTALLDIR))
