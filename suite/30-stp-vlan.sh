# Basic VLAN forwarding test. Two access ports in separate VLANS and one
# trunk port.  Inject frames on both access ports and verify blocking on
# one VLAN on the trunk.
# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

basic_stp_vlan()
{
    require3loops

    create_br $br0 "vlan_default_pvid 0 vlan_filtering 1" $bports
    if ! bridge -d vlan show | grep -q "state forwarding"; then
        step "STP per VLAN not supported, skipping."
        skip
    fi

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
