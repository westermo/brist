# When installed, on target systems, we assume we have tcpdump
# (brist.sh), but from host systems that run from `make check`
# we use tshark since it works better in an unshare/nsenter.
export BRIST_TCPDUMP ?= tshark
export BRIST_CAPREAD ?= fakeroot tcpdump
.ONESHELL:

VERSION := $(shell git describe --always --dirty --tags)
NAME    := brist
PACKAGE := $(NAME)-$(VERSION)
SUFFIX  := tar.gz
ARCHIVE := $(PACKAGE).$(SUFFIX)

prefix  ?= /usr/local
bindir   = $(prefix)/bin
libdir   = $(prefix)/lib/$(NAME)
docdir   = $(prefix)/share/doc/$(NAME)

DOCS    := README.md LICENSE
SCRIPTS := *.sh suite/*.sh

all: check

check:
	@unshare -r -n ./brist.sh

shell:
	@unshare -r -n bash

install:
	install -d $(DESTDIR)$(bindir)
	install -d $(DESTDIR)$(docdir)
	install -d $(DESTDIR)$(libdir)
	install -d $(DESTDIR)$(libdir)/suite
	cat <<- EOF > $(DESTDIR)$(bindir)/$(NAME)
		#!/bin/sh
		cd $(libdir)
		./brist.sh
		cd -
	EOF
	chmod 0755 $(DESTDIR)$(bindir)/$(NAME)
	for file in $(DOCS); do						\
		install -m 0644 $$file $(DESTDIR)$(docdir)/$$file;	\
	done
	for file in $(SCRIPTS); do					\
		install -m 0644 $$file $(DESTDIR)$(libdir)/$$file;	\
	done

uninstall:
	-$(RM)    $(DESTDIR)$(bindir)/$(NAME)
	-$(RM) -r $(DESTDIR)$(docdir)
	-$(RM) -r $(DESTDIR)$(libdir)

install-strip: install

dist:
	git archive --format=$(SUFFIX) --prefix=$(PACKAGE)/ $(VERSION) > $(ARCHIVE)

distcheck: dist
	@tar xf $(ARCHIVE) && cd $(PACKAGE) && make check && cd - && rm -rf $(PACKAGE)

release: distcheck
	sha256sum $(ARCHIVE) > $(ARCHIVE).sha256
