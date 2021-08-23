
multi_learning_port()
{
    require3loops

    create_br $br0 "vlan_default_pvid 0" $ax
    create_br $br1 "vlan_default_pvid 0" $(cdr $xports)

    step Inject learning frame on $by
    eth -b -i $by | { cat; echo from $by; } | inject $by

    step Inject learning frame on $ay, re-using ${by}s address
    eth -b -i $by | { cat; echo from $by; } | inject $by

    capifs="$br0 $br1 $ay $(cdr $(cdr $yports))"
    capture $capifs

    step Inject return traffic towards $by from $cy
    eth -I $by -i $cy | { cat; echo reply from $cy; } | inject $cy

    for y in $capifs; do
	case $y in
	    ${br0}|${br1}|${ay})
		step Verify absence of reply on $y
		report $y | grep -q "reply from $cy" && fail
		;;
	    *)
		step Verify reply on $y
		report $y | grep -q "reply from $cy" || fail
		;;
	esac
    done

    pass
}
alltests="$alltests multi_learning_port"
