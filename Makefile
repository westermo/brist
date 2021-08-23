export BRIST_TCPDUMP = fakeroot tcpdump -Zroot

all: check

check:
	@unshare -r -n ./brist.sh

shell:
	@unshare -r -n bash

install:
	cp -a . $(PREFIX)/lib/brist
