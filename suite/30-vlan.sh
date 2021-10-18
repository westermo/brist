# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

vlan_transparency()
{
    require3loops

    create_br $br0 "vlan_filtering 0" $bports

    step "Inject traffic on non-filtering bridge"
    capture $(cdr $hports) $br0
    eth -b -i $h1 | { cat; echo untagged from $h1; } | inject $h1
    eth -b -i $h1 -q 1 | { cat; echo vlan 1 tagged from $h1; } | inject $h1
    eth -b -i $h1 -q 2 | { cat; echo vlan 2 tagged from $h1; } | inject $h1

    step "Verify that all flows are forwarded"
    for hp in $(cdr $hports) $br0; do
	report $hp | grep -q "untagged from $h1" || fail
	report $hp | grep -q "vlan 1 tagged from $h1" || fail
	report $hp | grep -q "vlan 2 tagged from $h1" || fail
    done

    pass
}
alltests="$alltests vlan_transparency"

vlan_filtering()
{
    require3loops

    create_br $br0 "vlan_filtering 1 vlan_default_pvid 0" $bports

    step "Setup VLANs"
    bridge vlan add dev $b1 vid 1 pvid
    bridge vlan add dev $b1 vid 2

    bridge vlan add dev $b2 vid 1 pvid untagged
    bridge vlan add dev $b3 vid 2 pvid untagged

    bridge vlan add dev $br0 vid 1 self
    bridge vlan add dev $br0 vid 2 self

    step "Inject traffic on filtering bridge"
    capture $h2 $h3 $br0
    eth -b -i $h1 | { cat; echo untagged from $h1; } | inject $h1
    eth -b -i $h1 -q 1 | { cat; echo vlan 1 tagged from $h1; } | inject $h1
    eth -b -i $h1 -q 2 | { cat; echo vlan 2 tagged from $h1; } | inject $h1

    step "Verify that all $h2 only sees 1st and 2nd flow"
    report $h2 | grep -q "untagged from $h1" || fail
    report $h2 | grep -q "vlan 1 tagged from $h1" || fail
    report $h2 | grep -q "vlan 2 tagged from $h1" && fail

    step "Verify that all $h3 only sees 3rd flow"
    report $h3 | grep -q "untagged from $h1" && fail
    report $h3 | grep -q "vlan 1 tagged from $h1" && fail
    report $h3 | grep -q "vlan 2 tagged from $h1" || fail

    step "Verify that all $br0 sees all flows"
    report $br0 | grep -q "untagged from $h1" || fail
    report $br0 | grep -q "vlan 1 tagged from $h1" || fail
    report $br0 | grep -q "vlan 2 tagged from $h1" || fail

    pass
}
alltests="$alltests vlan_filtering"
