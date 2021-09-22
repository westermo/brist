brist - BRIdge Self Test
========================

> *brist* (Swedish), (English meaning) *deficiency* : the quality or
> state of being defective or of lacking some necessary quality or
> element ... : a shortage of substances necessary to health, e.g.,
> a vitamin C deficiency

This project is an effort to create a standalone, easy to use, portable
framework to test capabilities of the Linux bridge.  The most important
aspect is *portable*, i.e., it should be possible to run on a full dist,
but also on a limited embedded system.

Dependencies, in order of importance:

  - dash, or BusyBox ash
  - fakeroot
  - socat
  - ping
  - nemesis
  - tcpdump
  - tshark
  - iproute2 tools (ip, bridge, ...)
  - unshare
  - make

> Currently `tshark` is used from `make check` to capture traffic,
> because `tcpdump` does not work properly inside an `unshare -rn`.


Running the Test Suite
----------------------

```sh
$ git clone https://github.com/westermo/brist.git
$ cd brist/
$ make check
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
