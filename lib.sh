tcpdump="${BRIST_TCPDUMP:-tcpdump}"
socat="${BRIST_SOCAT:-socat}"

die()
{
    echo "error: $@" >&2
    exit 1
}

alias fail='{ t_status=2; return 0; }'
alias skip='{ t_status=1; return 0; }'
alias pass='{ t_status=0; return 0; }'

alias require2loops='{ \
      if [ $(echo $loops | wc -w) -lt 2 ]; then \
         step Require at least 2 loops; \
	 skip; \
      fi \
}'

alias require3loops='{ \
      if [ $(echo $loops | wc -w) -lt 3 ]; then \
         step Require at least 3 loops; \
	 skip; \
      fi \
}'

alias require4loops='{ \
      if [ $(echo $loops | wc -w) -lt 4 ]; then \
         step Require at least 4 loops; \
	 skip; \
      fi \
}'

step()
{
    t_step="$@"
    printf "\e[1m$t_current:\e[0m $t_step\n"
}

depcheck()
{
    $@ -h >/dev/null 2>&1 && return

    die "\"$@\" is missing"
}

phys()
{
    eval echo '$'${1}${2}
}

car()
{
    echo $1
}

cdr()
{
    shift
    echo "$@"
}

u8()
{
    printf '\\%3.3o' $(($1))
}

be16()
{
    printf '\\%3.3o\\%3.3o' $(($1 >> 8)) $(($1 & 0xff))
}

addrfmt()
{
    bytes=$(echo 0x$@ | sed -e 's/:/ 0x/g')
    printf '\\%3.3o\\%3.3o\\%3.3o\\%3.3o\\%3.3o\\%3.3o' $bytes
}

rndaddr()
{
    printf '%2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x' \
	   $((($(shuf -i 0-255 -n 1) & 0xfe) | 2)) $(shuf -i 0-255 -n 5)
}

ifaddr()
{
    ip -br link show dev $1 | awk '{ print($3); }'
}

eth()
{
    da="$(addrfmt $(rndaddr))"
    sa="$(addrfmt $(rndaddr))"
    qtag=""
    et="$(be16 0xbbbb)"

    while getopts "bd:g:i:I:q:s:t:" opt; do
	case $opt in
	    b)
		da="\377\377\377\377\377\377"
		;;
	    d)
		da="\002\000\000\000\000$(u8 $OPTARG)"
		;;
	    g)
		da="\001\000\000\000\000$(u8 $OPTARG)"
		;;
	    i)
		sa="$(addrfmt $(ifaddr $OPTARG))"
		;;
	    I)
		da="$(addrfmt $(ifaddr $OPTARG))"
		;;
	    q)
		qtag="$(be16 0x8100)$(be16 $OPTARG)"
		;;
	    s)
		sa="\002\000\000\000\000$(u8 $OPTARG)"
		;;
	    t)
		et="$(be16 $OPTARG)"
		;;
	    *)
		exit 1
		;;
	esac
    done

    shift $((OPTIND - 1))

    printf "${da}${sa}${qtag}${et}"
}

_capture()
{
    filter="ether proto 0xbbbb"
    pcap=$t_work/${1}.pcap

    while getopts "f:" opt; do
	case $opt in
	    f)
		filter="$OPTARG"
		;;
	    *)
		exit 1
		;;
	esac
    done

    shift $((OPTIND - 1))

    rm -f $pcap
    $tcpdump -pqU -i $1 -w $pcap "$filter"  &
    eval "${1}_capture=$!"

    for i in $(seq 5); do
	[ -f $pcap ] && return 0
	sleep 0.1
    done

    die unable to start capture on $1
}

capture()
{
    step Capture on $yports

    while [ $# -gt 0 ]; do
	_capture $1
	shift
    done

    [ "$conf_capture_delay" ] && sleep $conf_capture_delay
}

report()
{
    pid=$(eval echo '$'"${1}_capture")
    if [ "$pid" ]; then
	kill $pid && wait $pid
	eval "unset ${1}_capture"
    fi

    $tcpdump -A -r $t_work/${1}.pcap
}

inject()
{
    # Collect all data to make sure that we hand it to socat in a
    # single write(1).
    cat >$t_work/last.bin

    $socat -u open:$t_work/last.bin interface:$1

    [ "$conf_inject_delay" ] && sleep $conf_inject_delay
}

create_br()
{
    br=$1
    opts=$2
    shift 2

    ip link add dev $br type bridge $opts
    ip link set dev $br up

    while [ $# -gt 0 ]; do
	ip link set dev $1 master $br
	shift
    done
}


