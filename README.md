brist - BRIdge Self Test
========================

> *brist* (Swedish), (English meaning) *deficiency* : the quality or
> state of being defective or of lacking some necessary quality or
> element ... : a shortage of substances necessary to health, e.g.,
> a vitamin C deficiency

Brist is a standalone, easy to use, *portable* framework to verify
capabilities of the Linux bridge.  Emphasis on *portable*.  I.e., it
should be possible to run on a full-blown Linux distribution, but it
must be possible to run on limited embedded systems, e.g [NetBox][].

Dependencies:

  - dash, or BusyBox ash
  - [socat][]
  - ping
  - [nemesis][]
  - tcpdump
  - iproute2 tools (ip, bridge, ...)

Additional dependencies for developing and running on a PC:

  - unshare
  - fakeroot
  - tshark
  - make

> **Note:** currently `tshark` is used from `make check` to capture
> traffic, because `tcpdump` does not work inside an `unshare -rn`.
> This is also reason for `fakeroot`. On target only tcpdump is used.


Running the Test Suite
----------------------

From your PC, with the kernel you are currently running:

```sh
$ git clone https://github.com/westermo/brist.git
$ cd brist/
$ make check
```

When installed on a target system, change to the install directory:

```sh
$ ./brist.sh
```


Running a Single Test
---------------------

```sh
$ make check BRIST_TEST=basic_stp_vlan
```


Adding a Test
-------------

The `suite/` directory holds all test cases.  There are a few things to
know when adding a new test case:

  - Tests must be possible to run with VETH pairs and on a target device
  - Logical port names are `hN <--> bN`, where:
    - `hN` is a numbered host port, and
    - `bN` is the other end of that pair/cable attached to the bridge
  - Similarly, the fallback VETH topology have names `vhN` and `vbN`


Origin
------

Invented, developed, and maintained by Westermo Network Technologies.  
Please use GitHub for issues and discussions.

[nemesis]: https://github.com/libnet/nemesis/
[NetBox]:  https://github.com/westermo/netbox/
[socat]:   http://www.dest-unreach.org/socat/
