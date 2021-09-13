
topology()
{
    capture $hports

    step Inject packets on $bports
    for x in $bports; do
	eth | { cat; echo from $x; } | inject $x
    done

    for loop in $loops; do
	x=$(phys b $loop)
	y=$(phys h $loop)
	step Verify connection between $x and $y
	report $y | grep -q "from $x" || fail
    done

    pass
}
alltests="$alltests topology"
