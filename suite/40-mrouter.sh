# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

ip4_src=169.254.255.254
ip6_src=2001:dead::1

ip4_grp()
{
    printf 239.255.0.$1
}

ip6_grp()
{
    printf ff02::ff0$1
}

mac_grp()
{
    printf 01:00:00:00:00:0$1
}

register()
{
    bridge mdb add dev $br0 port $1 grp $(ip4_grp $2) permanent
    bridge mdb add dev $br0 port $1 grp $(ip6_grp $2) permanent
    bridge mdb add dev $br0 port $1 grp $(mac_grp $2) permanent
}

unregister()
{
    bridge mdb del dev $br0 port $1 grp $(ip4_grp $2) permanent
    bridge mdb del dev $br0 port $1 grp $(ip6_grp $2) permanent
    bridge mdb del dev $br0 port $1 grp $(mac_grp $2) permanent
}


mrouter_report_one()
{
    local port=$1
    local mrouter="$2"
    local reg_grps="$3"
    local all_grps="$4"

    for g in $all_grps; do
	if echo $reg_grps | grep -q $g; then
	    step "  Verify that $port received group $g (MAC)"
	    report $port | grep -q "> $(mac_grp $g)" || return 1
	else
	    step "  Verify that $port didn't receive group $g (MAC)"
	    if report $port | grep -q "> $(mac_grp $g)"; then
		if [ "$mrouter" = "yes" ]; then
		    # There's lots of hardware without separate controls for
		    # flooding of IP and non-IP multicast, so settle for a
		    # warning here.
		    warn "$port does not discriminate IP from non-IP multicast"
		else
		    return 1
		fi
	    fi
	fi
    done

    for g in $all_grps; do
	if [ "$mrouter" = "yes" ] || echo $reg_grps | grep -q $g; then
	    step "  Verify that $port received group $g (IPv4/6)"
	    report $port | grep -q "$(ip4_grp $g): ICMP echo request" || return 1
	    report $port | grep -q "$(ip6_grp $g): ICMP6, echo request" || return 1
	else
	    step "  Verify that $port didn't receive group $g (IPv4/6)"
	    report $port | grep -q "$(ip4_grp $g): ICMP echo request" && return 1
	    report $port | grep -q "$(ip6_grp $g): ICMP6, echo request" && return 1
	fi
    done

    true
}

mrouter_inject_and_report()
{
    local all_grps="$1"
    local b2_grps="$2"
    local b3_grps="$3"
    local b3_mrouter=$4

    capture -f "icmp or icmp6 or ether proto 0xbbbb" $h2 $h3

    step "  Inject MAC/IPv4/IPv6 multicast to all groups ($all_grps) on $h1"
    for g in $all_grps; do
	eth -g $g | { cat; echo U from $h1; } | inject $h1
	mcast_gen -c 1 -g $(ip4_grp $g) $ip4_src
	mcast_gen -c 1 -g $(ip6_grp $g)%$h1 $ip6_src
    done

    mrouter_report_one $h2 no "$b2_grps" "$all_grps" || return 1
    mrouter_report_one $h3 $b3_mrouter "$b3_grps" "$all_grps" || return 1
}

mrouter_port()
{
    require3loops

    local in=$b1
    local out=$b2
    local rport=$b3

    local bropts="mcast_snooping 1"
    bropts="$bropts mcast_query_interval 100"
    bropts="$bropts mcast_startup_query_interval 100"
    bropts="$bropts mcast_query_response_interval 100"

    create_br $br0 "$bropts" $in $out $rport

    if ! bridge -d link show | grep -q " mcast_router"; then
        step "Mcast router port feature not supported, skipping."
        skip
    fi

    ip addr add ${ip4_src}/16 dev $h1
    ip addr add ${ip6_src}/64 dev $h1

    bridge link set dev $out mcast_flood off mcast_router 0
    bridge link set dev $rport mcast_flood off mcast_router 0

    ip link set dev $br0 type bridge mcast_querier 1
    step "Wait for $br0 to assume the role of querier"
    sleep 2

    step "Register groups 2 and 3 on $out"
    register $out 2
    register $out 3
    mrouter_inject_and_report "1 2 3" "2 3" "" no || fail

    step "Configure $rport as a multicast router port"
    bridge link set dev $rport mcast_router 2
    mrouter_inject_and_report "1 2 3" "2 3" "" yes || fail

    step "Register group 4 on $out"
    register $out 4
    mrouter_inject_and_report "1 2 3 4" "2 3 4" "" yes || fail

    step "Remove previously registered group 2 from $out"
    unregister $out 2
    mrouter_inject_and_report "1 2 3 4" "3 4" "" yes || fail


    step "Remove all groups from $out, register groups 2 and 3 on $rport"
    unregister $out 3
    unregister $out 4
    register $rport 2
    register $rport 3
    mrouter_inject_and_report "1 2 3 4" "" "2 3" yes || fail

    step "Unset ${rport}'s multicast router port configuration, enable flooding on $out"
    bridge link set dev $rport mcast_router 0
    bridge link set dev $out mcast_flood on
    mrouter_inject_and_report "1 2 3 4" "1 4" "2 3" no || fail

    step "Register group 4 on $rport"
    register $rport 4
    mrouter_inject_and_report "1 2 3 4" "1" "2 3 4" no || fail

    step "Configure $rport as a multicast router port"
    bridge link set dev $rport mcast_router 2
    mrouter_inject_and_report "1 2 3 4" "1" "2 3 4" yes || fail

    step "Remove previously registered group 4 on $rport"
    unregister $rport 4
    mrouter_inject_and_report "1 2 3 4" "1 4" "2 3" yes || fail

    step "Remove previously registered groups 2 and 3 on $rport"
    unregister $rport 2
    unregister $rport 3
    mrouter_inject_and_report "1 2 3 4" "1 2 3 4" "" yes || fail

    step "Unset ${rport}'s multicast router port configuration"
    bridge link set dev $rport mcast_router 0
    mrouter_inject_and_report "1 2 3 4" "1 2 3 4" "" no || fail

    pass
}
alltests="$alltests mrouter_port"
