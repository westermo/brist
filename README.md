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
  - socat
  - ping
  - tcpdump
  - iproute2 tools (ip, bridge, ...)
  - unshare
  - make


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


Origin
------

Invented, developed, and maintained by Westermo Network Technologies.
Please use GitHub for issues and discussions.
