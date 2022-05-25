ChangeLog
=========

All notable changes to the project are documented in this file.

[v1.1][] - 2022-05-25
---------------------

### Changes
 - Improved documentation: README now details how to run on HW
 - Lots of option flags added to tweak the behavior of brist
 - Support for randomizing the port mapping, including saving the
   mapping so it can be reused to repeat the exact same test
 - Support for advanced filtering of which tests to run
 - Add support for single-stepping, `brist.sh -S`
 - Add online `brist.sh -h` to show usage
 - New tests:
   - `basic_learning_station_move`
   - `basic_flags_flooding`
   - `vlan_transparency`
   - `vlan_filtering`
   - `vlan_ivl`
   - `basic_locked_port`
   - `locked_port_vlan`
   - `locked_port_spoofing`
   - `locked_port_mac_auth`
   - `lag_basic_connectivity`
   - `lag_add_link`
   - `lag_remove_link`

### Fixes
 - Ensure `brist.sh` is installed with executable perms
 - Only use zero exit code when no tests failed
 - Fix port list, no port `$b5` exists, only `$b4`
 - Flush addresses and routes from interfaces between tests.
   Otherwise lingering addresses interfere with new ones
 - Fix `multi_learning_ports` with >3 pairs


v1.0 - 2021-09-22
------------------

Initial version.  Includes basic forwarding tests for layer-2 traffic,
STP per-VLAN forwarding/blocking test, basic IP multicast forwarding,
and a per-VLAN multicast forwarding test.  Both of which focus on IGMP.


[UNRELEASED]: https://github.com/troglobit/mping/compare/1.0...HEAD
[v1.1]:       https://github.com/troglobit/mping/compare/1.0...1.1
