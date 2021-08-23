
topology()
{
    capture $yports

    step Inject packets on $xports
    for x in $xports; do
	eth | { cat; echo from $x; } | inject $x
    done

    for loop in $loops; do
	x=$(phys $loop x)
	y=$(phys $loop y)
	step Verify connection between $x and $y
	report $y | grep -q "from $x" || fail
    done

    pass
}
alltests="$alltests topology"
