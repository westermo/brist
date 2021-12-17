basic_locked_port()
{
    require2loops

    create_br $br0 "vlan_default_pvid 0" $bports

    step "Inject learning frame on $br0 and start capture"
    eth -b -i $br0 | { cat; echo from $br0; } | inject $br0

    sleep 1

    step "Start capture and inject packet to $h2 from host $h1"
    capture $h2
    eth -I $h2 -i $h1 | { cat; echo message from $h1; } | inject $h1

    step "Verify packet on $h2"
    report $h2 | grep -q "message from $h1" || fail

    step "Lock port on $b1"
    bridge fdb del `ifaddr $h1` dev $b1 master
    bridge link set dev $b1 locked on

    sleep 1

    step "Start capture and inject packet to $h2 from port $b1"
    capture $h2
    eth -I $h2 -i $h1 | { cat; echo message from $h1; } | inject $h1

    step "Verify that packet does not pass through"
    report $h2 | grep -q "message from $h1" && fail

    sleep 1

    step "Start capture and inject packet to $h2 from rnd host"
    capture $h2
    eth -I $h2 -s 100 | { cat; echo packet from nonauth host; } | inject $h1

    step "Verify that packet from rnd host does not pass through"
    report $h2 | grep -q "packet from nonauth host" && fail

    step "Add '8021X authenticated' host MAC to the bridge FDB"
    bridge fdb add `ifaddr $h1` dev $b1 master static

    sleep 1

    step "Start capture and inject packet to $h2 from host $h1"
    capture $h2
    eth -I $h2 -i $h1 | { cat; echo message from $h1; } | inject $h1

    step "Verify authed host packet passed through locked port $b1 with fdb entry"
    report $h2 | grep -q "message from $h1" || fail

    sleep 1

    step "Start capture and inject packet to $h2 from rnd host"
    capture $h2
    eth -I $h2 -s 100 | { cat; echo packet from nonauth host; } | inject $h1

    step "Verify that packet from non-auth host does not pass"
    report $h2 | grep -q "packet from nonauth host" && fail

    step "Unlock port $b1"
    bridge link set dev $b1 locked off

    sleep 1

    step "Start capture and inject packet to $h2 from host $h1"
    capture $h2
    eth -I $h2 -i $h1 | { cat; echo message from $h1; } | inject $h1

    step "Verify that packet passes through unlocked port"
    report $h2 | grep -q "message from $h1" || fail

    sleep 1

    step "Start capture and inject packet to $h2 from rnd host through port $b1"
    capture $h2
    eth -I $h2 -s 100 | { cat; echo packet from nonauth host; } | inject $h1

    step "Verify that packet from rnd host passes through"
    report $h2 | grep -q "packet from nonauth host" || fail

    pass
}
alltests="$alltests basic_locked_port"

locked_port_vlan()
{
    vlan="2050"
    bropts="vlan_filtering 1 mcast_snooping 0 mcast_querier 0 vlan_default_pvid 1"

    require2loops

    create_br $br0 "$bropts" $bports

    step "Add vlans to bridge ports"
    bridge vlan add vid "$vlan" dev $b1 tagged
    bridge vlan add vid "$vlan" dev $b2 tagged

    step "Inject learning frame on $br0"
    eth -b -i $br0 | { cat; echo from $br0; } | inject $br0

    sleep 1

    step "Capture and inject packet to $h2 from host $h1"
    capture $h2
    eth -I $h2 -i $h1 -q "$vlan" | { cat; echo message from $h1; } | inject $h1

    step "Verify packets on $h2"
    report $h2 | grep -q "message from $h1" || fail

    step "Lock port on $b1"
    bridge fdb del `ifaddr $h1` dev $b1 vlan "$vlan" master
    bridge link set dev $b1 locked on

    sleep 1

    step "Capture and inject packet to $h2 from host $h1"
    capture $h2
    eth -I $h2 -i $h1 -q "$vlan" | { cat; echo message from $h1; } | inject $h1

    step "Verify that packet does not pass through"
    report $h2 | grep -q "message from $h1" && fail

    sleep 1

    step "Capture and inject packet from rnd host to $h2 through port $b1"
    capture $h2
    eth -I $h2 -s 100 -q "$vlan" | { cat; echo packet from nonauth host; } | inject $h1

    step "Verify that packet from rnd host does not pass through"
    report $h2 | grep -q "packet from nonauth host" && fail

    step "Add '8021X authenticated' host MAC to the bridge FDB and start capture"
    bridge fdb add `ifaddr $h1` dev $b1 master static

    sleep 1

    step "Capture and inject packet from authed host $h1 to $h2 through port $b1"
    capture $h2
    eth -I $h2 -i $h1 -q "$vlan" | { cat; echo message from $h1; } | inject $h1

    step "Verify that packet from authed host with fdb entry passes through locked port"
    report $h2 | grep -q "message from $h1" || fail

    sleep 1

    step "Capture and inject packet from rnd host to $h2 through port $b1"
    capture $h2
    eth -I $h2 -s 100 -q "$vlan" | { cat; echo packet from nonauth host; } | inject $h1

    step "Verify that packet from rnd host does not pass through locked port"
    report $h2 | grep -q "packet from nonauth host" && fail

    step "Unlock port $b1"
    bridge link set dev $b1 locked off

    sleep 1

    step "Capture and inject packet to $h2 from host $h1"
    capture $h2
    eth -I $h2 -i $h1 -q "$vlan" | { cat; echo message from $h1; } | inject $h1

    step "Verify that packet from host $h1 passes through"
    report $h2 | grep -q "message from $h1" || fail

    sleep 1

    step "Capture and inject packet from rnd host to $h2 through port $b1"
    capture $h2
    eth -I $h2 -s 100 -q "$vlan" | { cat; echo packet from nonauth host; } | inject $h1

    step "Verify that packet from rnd host passes through"
    report $h2 | grep -q "packet from nonauth host" || fail

    pass
}
alltests="$alltests locked_port_vlan"

locked_port_spoofing()
{
    require3loops

    create_br $br0 "vlan_default_pvid 0" $bports

    step "Start capture and inject packet to $h3 from host $h1"
    capture $h3
    eth -I $h3 -i $h1 | { cat; echo message from $h1; } | inject $h1

    step "Verify packet on $h3"
    report $h3 | grep -q "message from $h1" || fail

    step "Lock ports on $b1 and $b2 and open for host $h1 on port $b1"
    bridge fdb del `ifaddr $h1` dev $b2 master
    bridge fdb add `ifaddr $h1` dev $b1 master static
    bridge link set dev $b1 locked on
    bridge link set dev $b2 locked on

    step "Start capture and inject packet to $h3 from host $h1"
    capture $h3
    eth -I $h3 -i $h1 | { cat; echo message from $h1; } | inject $h1

    step "Verify packet on $h3"
    report $h3 | grep -q "message from $h1" || fail

    step "Start capture and inject packet to $h3 from host $h2 spoofing as $h1"
    capture $h3
    eth -I $h3 -i $h1 | { cat; echo message from spoofer; } | inject $h2

    step "Verify that package from spoofer does not pass through"
    report $h3 | grep -q "message from spoofer" && fail

    pass
}
alltests="$alltests locked_port_spoofing"
