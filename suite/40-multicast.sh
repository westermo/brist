# Multicast forwarding tests, IPv4 and IPv6, with and without IGMP/MLD
# filtering, as well as with and without VLAN filtering.
# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

# no filtering, verify multicast is flooded like broadcast
multicast_basic_fwd()
{
    bropts="vlan_filtering 0 mcast_snooping 0 mcast_querier 0"

    require3loops

    create_br $br0 "$bropts" $bports
    ip addr add 10.0.1.10/24 dev $h1

    capture -f "icmp" $b1 $h2 $h3
    mcast_gen $h1

    report $h2 | grep -q "225.1.2.3: ICMP echo request" || fail
    report $h3 | grep -q "225.1.2.3: ICMP echo request" || fail

    pass
}
alltests="$alltests multicast_basic_fwd"

# multicast filtering, verify only subscribers receive multicast
multicast_basic_filtering()
{
    bropts="vlan_filtering 0 mcast_snooping 1 mcast_querier 1"
    sender="$t_work/sender"
    touch $sender

    require3loops

    create_br $br0 "$bropts" $bports
    bridge link set dev $b1 mcast_flood off
    bridge link set dev $b2 mcast_flood off
    bridge link set dev $b3 mcast_flood off

    ip addr add 10.0.1.10/24 dev $h1
    ip addr add 10.0.2.10/24 dev $h2
    ip addr add 10.0.3.10/24 dev $h3

    capture -f "icmp or igmp" $h2 $h3

    # Only join stream on $h3
    mcast_join $h3

    # Bridge currently has a "grace time" at creation time before it
    # forwards multicast according to the mdb.  Since we disable the
    # mcast_flood setting per port
    sleep 10

    mcast_gen $h1
    mcast_leave $h3

    step "$h2: analyzing, no multicast expected ..."
    report $h2 | grep -q "225.1.2.3: ICMP echo request" && fail
    step "$h3: analyzing, multicast expected ..."
    report $h3 | grep -q "225.1.2.3: ICMP echo request" || fail

    pass
}
alltests="$alltests multicast_basic_filtering"

# multicast filtering, check for gaps in multicast reception when
# using an external querier.
#
# Note: currently the bridge has an initial delay of 10 seconds when
#       mcast_flood is disabled.  Ignore that for now.
# 
multicast_check_gaps()
{
    bropts="vlan_filtering 0 mcast_snooping 1 mcast_querier 0"

    require3loops

    create_br $br0 "$bropts" $bports
    bridge link set dev $b1 mcast_flood off
    bridge link set dev $b2 mcast_flood off
    bridge link set dev $b3 mcast_flood off

    ip addr add 10.0.1.10/24 dev $h1
    ip addr add 10.0.2.10/24 dev $h2
    ip addr add 10.0.3.10/24 dev $h3

    capture -f "icmp or igmp" $h3
    mcast_query_start $h2
    mcast_join $h3

    mcast_gen -c 30 $h1

    mcast_leave $h3
    mcast_query_stop $h2

    mcast_analyze_gaps $h3

    pass
}
alltests="$alltests multicast_check_gaps"

# basic multicast forwarding with VLANs and snooping enabled
multicast_basic_vlans()
{
    bropts="vlan_filtering 1 mcast_snooping 1 mcast_vlan_snooping 1 mcast_querier 1"

    require3loops

    if ! ip link add type bridge help 2>&1 |grep -q "mcast_vlan_snooping"; then
	step "Multicast snooping per VLAN not supported, skipping."
	skip
    fi

    create_br $br0 "$bropts" $bports
    bridge link set dev $b1 mcast_flood off
    bridge link set dev $b2 mcast_flood off
    bridge link set dev $b3 mcast_flood off

    bridge vlan add vid 2 dev $b2 pvid untagged
    bridge vlan del vid 1 dev $b2

    ip addr add 10.0.1.10/24 dev $h1
    ip addr add 10.0.2.10/24 dev $h2
    ip addr add 10.0.3.10/24 dev $h3

    capture -f "icmp or igmp" $h2 $h3

    # Inject query on VLAN 1, not on receive port!, to allow fwd
    # of multicast on this VLAN.  Current limitation of bridge.
    mcast_query_start $h1

    # Only join stream on $h3
    mcast_join $h3

    # Bridge currently has a "grace time" at creation time before it
    # forwards multicast according to the mdb.  Since we disable the
    # mcast_flood setting per port
    sleep 10

    mcast_gen $h1
    mcast_leave $h3

    step "$h2: analyzing, no multicast expected ..."
    report $h2 | grep -q "225.1.2.3: ICMP echo request" && fail
    step "$h3: analyzing, multicast expected ..."
    report $h3 | grep -q "225.1.2.3: ICMP echo request" || fail

    pass
}
alltests="$alltests multicast_basic_vlans"
