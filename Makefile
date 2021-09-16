# When installed, on target systems, we assume we have tcpdump
# (brist.sh), but from host systems that run from `make check`
# we use tshark since it works better in an unshare/nsenter.
export BRIST_TCPDUMP = tshark
export BRIST_CAPREAD = fakeroot tcpdump

all: check

check:
	@unshare -r -n ./brist.sh

shell:
	@unshare -r -n bash

install:
	cp -a . $(PREFIX)/lib/brist
