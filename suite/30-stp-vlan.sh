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

mstp_verify()
{
    capture $h2

    step "  Injecting broadcast in VLAN 10,20,30,40, on $h1"
    for vid in 10 20 30 40; do
	eth -b -q $vid | { cat; echo from $vid; } | inject $h1
    done

    for vid in 10 20 30 40; do
	if echo "$@" | grep -q $vid; then
	    step "  Verifying broadcast in VLAN $vid, on $h2"
	    report $h2 | grep -q "from $vid" || return 1
	else
	    step "  Verifying absense of broadcast in VLAN $vid, on $h2"
	    report $h2 | grep -q "from $vid" && return 1
	fi
    done

    return 0
}

basic_mstp()
{
    require2loops

    if ! bridge vlan help 2>&1 | grep -q msti; then
        step "Mapping of VLANs to MSTIs not supported, skipping."
        skip
    fi

    vlanopts="vlan_filtering 1 vlan_default_pvid 0"
    stpopts="stp_state 2 mst_enable 1"

    create_br $br0 "$vlanopts $stpopts" $bports

    for bport in $b1 $b2; do
	for vid in 10 20 30 40; do
	    bridge vlan add vid $vid dev $bport
	done
    done

    bridge link set dev $b2 state forwarding

    step "All VLANs should start out in CST, which should be blocking"
    mstp_verify || fail

    step "Setting CST(all VLANs) on $b1 in forwarding state"
    bridge link set dev $b1 state forwarding
    mstp_verify 10 20 30 40 || fail

    step "Moving VLAN 20 and 30 to MSTI 100, should start out disabled"
    bridge vlan global set vid 20 dev $br0 msti 100
    bridge vlan global set vid 30 dev $br0 msti 100
    bridge mst set dev $b2 msti 100 state forwarding
    mstp_verify 10 40 || fail

    step "Setting MSTI 100 on $b1 in forwarding state"
    bridge mst set dev $b1 msti 100 state forwarding
    mstp_verify 10 20 30 40 || fail

    step "Setting MSTI 100 on $b1 in blocking state"
    bridge mst set dev $b1 msti 100 state blocking
    mstp_verify 10 40 || fail

    step "Moving VLAN 40 to MSTI 100, should inherit state"
    bridge vlan global set vid 40 dev $br0 msti 100
    mstp_verify 10 || fail

    step "Setting MSTI 100 on $b1 in forwarding state"
    bridge mst set dev $b1 msti 100 state forwarding
    mstp_verify 10 20 30 40 || fail

    step "Setting CST(VLAN 10) on $b1 in blocking state"
    bridge link set dev $b1 state blocking
    mstp_verify 20 30 40 || fail

    pass
}
experimentaltests="$experimentaltests basic_mstp"
