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

When installed on a target system, change to the install directory,
`/usr/local` is the default prefix, which you can override at install:

```sh
$ cd /usr/local/lib/brist/
$ ./brist.sh
```


Running a Single Test
---------------------

```sh
$ make check BRIST_TEST=basic_stp_vlan
```

or, when installed:

```sh
$ ./brist.sh -t basic_stp_vlan
```


Running Tests on Hardware
----------------------------

Set up loops between the physical ports. Make sure that there is no
storm when starting Brist.  This can be done by removing a port from the
bridge with `ip link set dev ethX nomaster` on one end of the loop.

Map the variables to the physical ports by creating a file called
`.brist-setup.sh` in either your home directory, `~/.brist-setup.sh`, or
in /etc, `/etc/.brist-setup.sh.`

The file should look something like this:

```
conf_capture_delay=1
conf_inject_delay=1
loops="1 2 3" # 3 loops
b1=eth4 # Maps $b1 to physical port eth4
h1=eth5
b2=eth6
h2=eth7
b3=eth8
h3=eth9
br0=br0
echo loop1 $b1 "<->" $h1
echo loop2 $b2 "<->" $h2
echo loop3 $b3 "<->" $h3
```

If a bridge is not specified Brist will attempt to create one.  This may
cause problems if your hardware only supports a single bridge, if that
bridge already exists.

Now you can run `make check`. If you see the `echo`'s from the setup
file you know it is running on the hardware.


Adding a Test
-------------

The `suite/` directory holds all test cases.  There are a few things to
know when adding a new test case:

  - Tests must be possible to run with VETH pairs and on a target device
  - Logical port names are `hN <--> bN`, where:
    - `hN` is a numbered host port, and
    - `bN` is the other end of that pair/cable attached to the bridge
  - Similarly, the fallback VETH topology have names `vhN` and `vbN`


Installation
------------

The test suite can be installed using `make install`, and by default
`/usr/local` is used as prefix.  To override that:

```sh
$ make install prefix=/usr
```

The install creates a handy wrapper script in `$prefix/bin/brist`.

> The `DESTDIR=` variable is also honored, for .deb and .rpm creators.


Origin
------

Invented, developed, and maintained by Westermo Network Technologies.  
Please use GitHub for issues and discussions.

[nemesis]: https://github.com/libnet/nemesis/
[NetBox]:  https://github.com/westermo/netbox/
[socat]:   http://www.dest-unreach.org/socat/
