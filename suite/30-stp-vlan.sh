# Basic VLAN forwarding test. Two access ports in separate VLANS and one
# trunk port.  Inject frames on both access ports and verify blocking on
# one VLAN on the trunk.
# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

basic_stp_vlan()
{
    require3loops

    if ! bridge vlan help 2>&1 | grep -q STP_STATE; then
        step "STP per VLAN not supported, skipping."
        skip
    fi

    create_br $br0 "vlan_default_pvid 0 vlan_filtering 1" $bports

    bridge vlan add vid 1 dev $b1 pvid untagged
    bridge vlan add vid 2 dev $b2 pvid untagged

    bridge vlan add vid 2 dev $b3
    bridge vlan add vid 1 dev $b3

    capture $h3

    step "Injecting broadcast on $h1 and $h2"
    eth -b | { cat; echo from $h1; } | inject $h1
    eth -b | { cat; echo from $h2; } | inject $h2

    step "Verifying broadcast on $h3"
    report $h3 | grep -q "from $h1" || fail
    report $h3 | grep -q "from $h2" || fail

    step "Setting VLAN 1 on $b3 in blocking state"
    bridge vlan set vid 1 dev $b3 state blocking
    bridge -d vlan show

    step "Injecting broadcast on $b1 and $b2"
    capture $h3

    eth -b | { cat; echo from $h1; } | inject $h1
    eth -b | { cat; echo from $h2; } | inject $h2

    step "Verifying broadcast on $h3, now only from $b2 (VLAN 2)"
    report $h3 | grep -q "from $h1" && fail
    report $h3 | grep -q "from $h2" || fail

    pass
}
experimentaltests="$experimentaltests basic_stp_vlan"

basic_msti_vlan()
{
    require2loops

    if ! bridge vlan help 2>&1 | grep -q MSTI; then
	step "STP per VLAN not supported, skipping."
	skip
    fi

    create_br $br0 "vlan_default_pvid 0 vlan_filtering 1 mst_enabled 1" $bports

    bridge vlan add vid 1 dev $br0 self
    bridge vlan add vid 2 dev $br0 self

    bridge vlan add vid 1 dev $b1
    bridge vlan add vid 2 dev $b1

    bridge vlan add vid 1 dev $b2
    bridge vlan add vid 2 dev $b2

    step "Set VLAN 2 to use MSTI 1"
    bridge vlan global set vid 2 dev $br0 msti 1

    step "Set MSTI 1 to FORWARDING on all ports"
    # MSTI defaults to DISABLED on all MSTI except 0. Set to FORWARDING
    bridge mst set dev $b1 msti 1 state 3
    bridge mst set dev $b2 msti 1 state 3



    capture $h2
    step "Injecting on $h1 on VLAN 1 and 2"
    eth -q 1 -b | { cat; echo vid 1 from $h1; } | inject $h1
    eth -q 2 -b | { cat; echo vid 2 from $h1; } | inject $h1

    step "Verifying frame on VLAN 1 received"
    report $h2 | grep -q "vid 1 from $h1" || fail
    step "Verifying frame on VLAN 2 received"
    report $h2 | grep -q "vid 2 from $h1" || fail



    step "Blocking $b1 on MSTI 1 (VLAN 2)"
    bridge mst set dev $b1 msti 1 state 4

    capture $h2
    step "Injecting on $h1 on VLAN 1 and 2"
    eth -q 1 -b | { cat; echo vid 1 from $h1; } | inject $h1
    eth -q 2 -b | { cat; echo vid 2 from $h1; } | inject $h1

    step "Verifying frame on VLAN 1 received"
    report $h2 | grep -q "vid 1 from $h1" || fail
    step "Verifying frame on VLAN 2 not received"
    report $h2 | grep -q "vid 2 from $h1" && fail

    pass
}
alltests="$alltests basic_msti_vlan"
