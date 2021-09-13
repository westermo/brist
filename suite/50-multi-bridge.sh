# Verifies FDB isolation in HW offloaded bridges

multi_learning_port()
{
    require3loops

    create_br $br0 "vlan_default_pvid 0" $b1
    create_br $br1 "vlan_default_pvid 0" $(cdr $bports)

    step Inject learning frame on $h2
    eth -b -i $h2 | { cat; echo from $h2; } | inject $h2

    step Inject learning frame on $h1, re-using ${h2}s address
    eth -b -i $h2 | { cat; echo from $h1; } | inject $h1

    capifs="$br0 $br1 $h1 $(cdr $(cdr $hports))"
    capture $capifs

    step Inject return traffic towards $h2 from $h3
    eth -I $h2 -i $h3 | { cat; echo reply from $h3; } | inject $h3

    for y in $capifs; do
	case $y in
	    ${br0}|${br1}|${h1})
		step Verify absence of reply on $y
		report $y | grep -q "reply from $h3" && fail
		;;
	    *)
		step Verify reply on $y
		report $y | grep -q "reply from $h3" || fail
		;;
	esac
    done

    pass
}
alltests="$alltests multi_learning_port"
