
basic_broadcast_host()
{
    create_br $br0 "" $xports

    capture $yports

    step Inject broadcast on $br0
    eth -b | { cat; echo from $br0; } | inject $br0

    for y in $yports; do
	step Verify broadcast on $y
	report $y | grep -q "from $br0" || fail
    done

    pass
}
alltests="$alltests basic_broadcast_host"

basic_broadcast_port()
{
    require2loops

    create_br $br0 "" $xports

    capture $(cdr $yports)

    step Inject broadcast on $ay
    eth -b | { cat; echo from $ay; } | inject $ay

    for y in $(cdr $yports); do
	step Verify broadcast on $y
	report $y | grep -q "from $ay" || fail
    done

    pass
}
alltests="$alltests basic_broadcast_port"

basic_learning_host()
{
    require2loops

    create_br $br0 "vlan_default_pvid 0" $xports

    step Inject learning frame on $br0
    eth -b -i $br0 | { cat; echo from $br0; } | inject $br0

    capture $br0 $(cdr $yports)

    step Inject return traffic towards $br0 from $ay
    eth -I $br0 -i $ay | { cat; echo reply from $ay; } | inject $ay

    step Verify reply on $br0
    report $br0 | grep -q "reply from $ay" || fail

    for y in $(cdr $yports); do
	step Verify absence of reply on $y
	report $y | grep -q "reply from $ay" && fail
    done

    pass
}
alltests="$alltests basic_learning_host"

basic_learning_port()
{
    require3loops

    create_br $br0 "" $xports

    step Inject learning frame on $by
    eth -b -i $by | { cat; echo from $by; } | inject $by

    capture $br0 $(cdr $yports)

    step Inject return traffic towards $by from $ay
    eth -I $by -i $ay | { cat; echo reply from $ay; } | inject $ay

    for y in $br0 $(cdr $yports); do
	if [ "$y" = "$by" ]; then
	    step Verify reply on $y
	    report $y | grep -q "reply from $ay" || fail
	else
	    step Verify absence of reply on $y
	    report $y | grep -q "reply from $ay" && fail
	fi
    done

    pass
}
alltests="$alltests basic_learning_port"
