# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

mrouter_ip4_src=169.254.255.254
mrouter_ip6_src=2001:dead::1

mrouter_ip4_grp()
{
    printf 239.255.0.$1
}

mrouter_ip6_grp()
{
    printf ff02::ff0$1
}

mrouter_mac_grp()
{
    printf 01:00:00:00:00:0$1
}

mrouter_register()
{
    local permanent=$([ $1 = $br0 ] || echo permanent)

    bridge mdb add dev $br0 port $1 grp $(mrouter_ip4_grp $2) $permanent
    bridge mdb add dev $br0 port $1 grp $(mrouter_ip6_grp $2) $permanent
    bridge mdb add dev $br0 port $1 grp $(mrouter_mac_grp $2)  permanent
}

mrouter_unregister()
{
    bridge mdb del dev $br0 port $1 grp $(mrouter_ip4_grp $2)
    bridge mdb del dev $br0 port $1 grp $(mrouter_ip6_grp $2)
    bridge mdb del dev $br0 port $1 grp $(mrouter_mac_grp $2)
}

mrouter_mcast_set()
{
    if [ $1 = $br0 ]; then
	local flood=$([ $2 = on ] && echo 1 || echo 0)

	ip link set dev $1 type bridge mcast_flood $flood mcast_router $3
    else
	bridge link set dev $1 mcast_flood $2 mcast_router $3
    fi
}

mdb_is_member()
{
    bridge mdb show dev $br0 | grep -q "port $1 grp $2"
}

mdb_is_registered()
{
    bridge mdb show dev $br0 | grep -q "grp $1"
}

mrouter_report_proto()
{
    local h=$1
    local b=$2
    local proto=$3
    local mrouter=$(br_test $b mcast_router 2 && echo yes || echo no)
    local mcast_flood=$(br_test $b mcast_flood on && echo yes || echo no)

    for g in 1 2 3 4; do
	local grp=
	case $proto in
	    mac)
		grp=$(mrouter_mac_grp $g)
		;;
	    ip4)
		grp=$(mrouter_ip4_grp $g)
		;;
	    ip6)
		grp=$(mrouter_ip6_grp $g)
		;;
	esac

	local registered="$(mdb_is_registered $grp && echo yes || echo no)"
	local member="$(mdb_is_member $b $grp && echo yes || echo no)"

	local rx=
	case $proto in
	    mac)
		rx=$(report $h | grep -q "> $grp" \
			 && echo yes || echo no)
		;;
	    ip4)
		rx=$(report $h | grep -q "$grp: ICMP echo request" \
			 && echo yes || echo no)
		;;
	    ip6)
		rx=$(report $h | grep -q "> $grp: ICMP6, echo request" \
			 && echo yes || echo no)
		;;
	esac

	# First, verify that we receive all registered and/or flooded
	# groups - these are nonnegotiable.
	case $proto in
	    mac)
		if [ $member = yes ] || [ $registered = no -a $mcast_flood = yes ]; then
		    step "  Verify that $h received group $grp"
		    [ $rx = yes ] && continue || return 1
		fi
		;;
	    ip*)
		if [ $member = yes -o $mrouter = yes ]; then
		    step "  Verify that $h received group $grp"
		    [ $rx = yes ] && continue || return 1
		fi
		;;
	esac

	# Nothing more is expected, so if the current group was not
	# received, then we are done.
	step "  Verify that $h did not receive group $grp"
	[ $rx = no ] && continue

	# We received something we did not expect. This can happen
	# because the underlying hardware is not able to separately
	# control flooding of IP and non-IP multicast; settle for a
	# warning in these cases.
	case $proto in
	    mac)
		[ $mrouter = yes ] || return 1
		;;
	    ip*)
		[ $mcast_flood = yes ] || return 1
		;;
	esac

	warn "$b does not discriminate IP from non-IP multicast"
    done

    true
}

mrouter_report_port()
{
    local h=$1
    local b=$2

    mrouter_report_proto $h $b mac || return 1
    mrouter_report_proto $h $b ip4 || return 1

    # TODO: No IPv6 support in the host test, see below
    if [ $mode = host ]; then
	return
    fi

    mrouter_report_proto $h $b ip6 || return 1
}

mrouter_inject_and_report()
{
    capture -f "icmp or icmp6 or ether proto 0xbbbb" $oh $rh

    step "  Inject MAC/IP multicast to all groups on $ih"
    for g in 1 2 3 4; do
	eth -g $g | { cat; echo U from $ih; } | inject $ih
	mcast_gen -c 1 -g $(mrouter_ip4_grp $g) $mrouter_ip4_src

	# TODO: Nemesis can't yet generate MLD queries, so we only
	# test IPv6 for the port version of the test, i.e. when the
	# bridge is generating queries internally.
	if [ $mode = port ]; then
	    mcast_gen -c 1 -g $(mrouter_ip6_grp $g)%$ih $mrouter_ip6_src
	fi
    done
    sleep 1

    mrouter_report_port $oh $ob || return 1
    mrouter_report_port $rh $rb || return 1
}

mrouter_test()
{
    require3loops

    if ! brport_has mcast_router; then
        step "Mcast router port feature not supported, skipping."
        skip
    fi

    mode=$1

    # Local port names:
    #
    # b/h suffix refers to either the (b)ridge or the (h)ost side of
    # the loop.
    #
    # - (i)nput:   Where packets are injected
    # - (o)utput:  Non-router reference port
    # - (q)uerier: Where queries are generated/injected
    # - (r)outer:  Port under test
    #
    ib=$b1
    ih=$h1
    ob=$b2
    oh=$h2
    qb=$([ $mode = host ] && echo $b3 || echo $br0)
    qh=$([ $mode = host ] && echo $h3)
    rb=$([ $mode = port ] && echo $b3 || echo $br0)
    rh=$([ $mode = port ] && echo $h3 || echo $br0)

    local bropts="mcast_snooping 1"
    bropts="$bropts mcast_query_interval 100"
    bropts="$bropts mcast_startup_query_interval 100"
    bropts="$bropts mcast_query_response_interval 100"

    create_br $br0 "$bropts" $b1 $b2 $b3

    ip addr add ${mrouter_ip4_src}/16 dev $ih
    ip addr add ${mrouter_ip6_src}/64 dev $ih

    mrouter_mcast_set $ob off 0
    mrouter_mcast_set $rb off 0

    if [ $mode = host ]; then
	mcast_query_start -c 1000 -i 1 $qh
    else
	ip link set dev $br0 type bridge mcast_querier 1
    fi
    step "Wait for $qb to assume the role of querier"
    sleep $([ $mode = host ] && echo 10 || echo 2)

    step "Register groups 2 and 3 on $ob"
    mrouter_register $ob 2
    mrouter_register $ob 3
    mrouter_inject_and_report || fail

    step "Configure $rb as a multicast router port"
    mrouter_mcast_set $rb off 2
    mrouter_inject_and_report || fail

    step "Register group 4 on $ob"
    mrouter_register $ob 4
    mrouter_inject_and_report || fail

    step "Remove previously registered group 2 from $ob"
    mrouter_unregister $ob 2
    mrouter_inject_and_report || fail


    step "Remove all groups from $ob, register groups 2 and 3 on $rb"
    mrouter_unregister $ob 3
    mrouter_unregister $ob 4
    mrouter_register $rb 2
    mrouter_register $rb 3
    mrouter_inject_and_report || fail

    step "Unset ${rb}'s multicast router port configuration, enable flooding on $ob"
    mrouter_mcast_set $rb off 0
    mrouter_mcast_set $ob on 0

    mrouter_inject_and_report || fail

    step "Register group 4 on $rb"
    mrouter_register $rb 4
    mrouter_inject_and_report || fail

    step "Configure $rb as a multicast router port"
    mrouter_mcast_set $rb off 2

    mrouter_inject_and_report || fail

    step "Remove previously registered group 4 on $rb"
    mrouter_unregister $rb 4
    mrouter_inject_and_report || fail

    step "Remove previously registered groups 2 and 3 on $rb"
    mrouter_unregister $rb 2
    mrouter_unregister $rb 3
    mrouter_inject_and_report || fail

    step "Unset ${rb}'s multicast router port configuration"
    mrouter_mcast_set $rb off 0
    mrouter_inject_and_report || fail

    if [ $mode = host ]; then
	mcast_query_stop $qh
    fi

    pass
}

mrouter_port()
{
    mrouter_test port
}
alltests="$alltests mrouter_port"

mrouter_host()
{
    mrouter_test host
}
alltests="$alltests mrouter_host"
