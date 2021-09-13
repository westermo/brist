#!/bin/sh
root=$(dirname $(readlink -f "$0"))
work=/tmp/brist-$(date +%F-%T | tr ' :' '--')

[ -f /etc/.brist-setup.sh ] && setup=/etc/.brist-setup.sh
[ -f ~/.brist-setup.sh ] && setup=~/.brist-setup.sh
[ ! "$setup" ] && setup=${root}/veth-setup.sh

. $root/lib.sh

waitlink()
{
	for i in $(seq 10); do
	    link="$(ip -br link show dev $1 | awk '{ print($2); }')"

	    [ "$link" = "UP" ] && return 0;

	    sleep 0.5
	done

	return 1
}

origo()
{
    ip link del dev $br0 type bridge >/dev/null 2>&1
    ip link del dev $br1 type bridge >/dev/null 2>&1

    for port in $ports; do
	ip link set dev $port nomaster
	ip link set dev $port up
    done

    for port in $ports; do
	waitlink $port || die No link on $port
    done
}

mkdir -p $work || die unable to create $work

[ -f $setup ] && . $setup || die Missing setup $setup
br0=${br0:-brist0}
br1=${br1:-brist1}

ports="$h1 $b1 $h2 $b2 $h3 $b3 $h4 $b5"
bports="$b1 $b2 $b3 $b4"
hports="$h1 $h2 $h3 $h4"

echo Setup OK >&2

for suite in $root/suite/*.sh; do
    . $suite
done

sum_pass=0
sum_skip=0
sum_fail=0

for t in $(echo $alltests | tr ' ' '\n' | grep -E "$BRIST_TEST"); do
    t_work=$work/$t
    t_current=$t
    t_step=Setup
    t_status=2

    mkdir -p $t_work
    origo

    printf "\e[7m$t: start ($(date))\e[0m\n"
    $t || { step explicit return; t_status=2; }
    case $t_status in
	0)
	    sum_pass=$(($sum_pass + 1))
	    printf "\e[7m$t: pass\e[0m\n"
	    ;;
	1)
	    sum_skip=$(($sum_skip + 1))
	    printf "\e[7m$t: skip ($t_step)\e[0m\n"
	    ;;
	2)
	    sum_fail=$(($sum_fail + 1))
	    printf "\e[7m$t: FAIL ($t_step)\e[0m\n"
	    ;;
    esac
    echo
done

cat <<EOF
summary:
  pass: $sum_pass
  skip: $sum_skip
  fail: $sum_fail
EOF
