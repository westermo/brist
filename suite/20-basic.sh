
basic_broadcast_host()
{
    create_br $br0 "" $bports

    capture $hports

    step Inject broadcast on $br0
    eth -b | { cat; echo from $br0; } | inject $br0

    for y in $hports; do
	step Verify broadcast on $y
	report $y | grep -q "from $br0" || fail
    done

    pass
}
alltests="$alltests basic_broadcast_host"

basic_broadcast_port()
{
    require2loops

    create_br $br0 "" $bports

    capture $(cdr $hports)

    step Inject broadcast on $h1
    eth -b | { cat; echo from $h1; } | inject $h1

    for y in $(cdr $hports); do
	step Verify broadcast on $y
	report $y | grep -q "from $h1" || fail
    done

    pass
}
alltests="$alltests basic_broadcast_port"

basic_learning_host()
{
    require2loops

    create_br $br0 "vlan_default_pvid 0" $bports

    step Inject learning frame on $br0
    eth -b -i $br0 | { cat; echo from $br0; } | inject $br0

    capture $br0 $(cdr $hports)

    step Inject return traffic towards $br0 from $h1
    eth -I $br0 -i $h1 | { cat; echo reply from $h1; } | inject $h1

    step Verify reply on $br0
    report $br0 | grep -q "reply from $h1" || fail

    for y in $(cdr $hports); do
	step Verify absence of reply on $y
	report $y | grep -q "reply from $h1" && fail
    done

    pass
}
alltests="$alltests basic_learning_host"

basic_learning_port()
{
    require3loops

    create_br $br0 "" $bports

    step Inject learning frame on $h2
    eth -b -i $h2 | { cat; echo from $h2; } | inject $h2

    capture $br0 $(cdr $hports)

    step Inject return traffic towards $h2 from $h1
    eth -I $h2 -i $h1 | { cat; echo reply from $h1; } | inject $h1

    for y in $br0 $(cdr $hports); do
	if [ "$y" = "$h2" ]; then
	    step Verify reply on $y
	    report $y | grep -q "reply from $h1" || fail
	else
	    step Verify absence of reply on $y
	    report $y | grep -q "reply from $h1" && fail
	fi
    done

    pass
}
alltests="$alltests basic_learning_port"
