# shellcheck disable=SC2154 disable=SC2046 disable=SC2086

lag_setup()
{
    local bond=$1

    ip link add $bond type bond
    ip link set $bond type bond miimon 100 mode balance-xor

    lag_link_setup $@

    ip link set $bond up
}

lag_link_setup()
{
    local bond=$1
    shift
    local links=$@

    for link in $links; do
	ip link set $link down
	ip link set $link master $bond
	ip link set $link up

	waitlink $link
    done
}

lag_basic_connectivity()
{
    require2loops

    step "Setup basic link aggregation"

    lag_setup bond0 $h1
    lag_setup bond1 $b1

    waitlink bond0
    waitlink bond1

    capture bond1

    step "Inject traffic towards bond1 from bond0"
    eth -I bond1 -i bond0 | { cat; echo from bond0; } | inject bond0

    step "Verify traffic on bond1"
    report bond1 | grep -q "from bond0" || fail

    pass
}

alltests="$alltests lag_basic_connectivity"

lag_add_link()
{
    require3loops

    step "Setup aggregation of two links"

    lag_setup bond0 $h1 $h2
    lag_setup bond1 $b1 $b2

    step "Add third link"

    lag_link_setup bond0 $h3
    lag_link_setup bond1 $b3

    waitlink bond0
    waitlink bond1

    capture bond1

    step "Inject traffic from bond0 towards bond1 "
    eth -I bond1 -i bond0 | { cat; echo from bond0; } | inject bond0

    step "Verify traffic on bond1"
    report bond1 | grep -q "from bond0" || fail

    pass
}

alltests="$alltests lag_add_link"

lag_remove_link()
{
    require2loops

    step "Setup aggregation of two links"

    lag_setup bond0 $h1 $h2
    lag_setup bond1 $b1 $b2

    step "Remove link"

    ip link set $h2 nomaster
    ip link set $b2 nomaster

    ip link set bond0 up
    ip link set bond1 up

    waitlink bond0
    waitlink bond1

    capture bond1

    step "Inject traffic from bond0 towards bond1 "
    eth -I bond1 -i bond0 | { cat; echo from bond0; } | inject bond0

    step "Verify traffic on bond1"
    report bond1 | grep -q "from bond0" || fail

    pass
}

alltests="$alltests lag_remove_link"
