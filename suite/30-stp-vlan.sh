# Basic VLAN forwarding test. Two access ports in separate VLANS and one
# trunk port.  Inject frames on both access ports and verify blocking on
# one VLAN on the trunk.
basic_stp_vlan()
{
    require3loops

    create_br $br0 "vlan_filtering 1" $xports

    bridge vlan add vid 2 dev $bx pvid untagged
    bridge vlan del vid 1 dev $bx

    bridge vlan add vid 2 dev $cx
    bridge vlan add vid 1 dev $cx

    capture $cy

    step "Injecting broadcast on $ay and $by"
    eth -b | { cat; echo from $ay; } | inject $ay
    eth -b | { cat; echo from $by; } | inject $by

    step "Verifying broadcast on $cy"
    report $cy | grep -q "from $ay" || fail
    report $cy | grep -q "from $by" || fail

    step "Setting VLAN 1 on $cx in blocking state"
    bridge vlan set vid 1 dev $cx state blocking

    step "Injecting broadcast on $ax and $bx"
    capture $cy

    eth -b | { cat; echo from $ay; } | inject $ay
    eth -b | { cat; echo from $by; } | inject $by

    step "Verifying broadcast on $cy, now only from $bx (VLAN 2)"
    report $cy | grep -q "from $ay" && fail
    report $cy | grep -q "from $by" || fail

    pass
}
alltests="$alltests basic_stp_vlan"
