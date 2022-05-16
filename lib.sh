# shellcheck disable=SC1004 disable=SC2154

tcpdump="${BRIST_TCPDUMP:-tcpdump -qU}"
capread="${BRIST_CAPREAD:-tcpdump}"

socat="${BRIST_SOCAT:-socat}"
PATH=$PATH:/usr/sbin

die()
{
    echo "error: $*" >&2
    exit 1
}

# Not all sleep(1) implentations accept non-integer numbers. Below we
# monkey-patch sleep to use usleep(1) in enviroments where it's needed, ie.
# Busybox.
sleep 0.1 2> /dev/null
if [ "$?" -ne 0 ]; then
    command -v usleep > /dev/null || \
        die 'usleep(1) required when sleep(1) with fractions is not available'
    sleep()
    {
        usleep $(echo | awk "{print $1 * 1000000}")
    }
fi

alias fail='{ t_status=2; return 0; }'
alias skip='{ t_status=1; return 0; }'
alias pass='{ t_status=0; return 0; }'

alias require2loops='{ \
      if [ $(echo $loops | wc -w) -lt 2 ]; then \
         step "Require at least 2 loops"; \
	 skip; \
      fi \
}'

alias require3loops='{ \
      if [ $(echo $loops | wc -w) -lt 3 ]; then \
         step "Require at least 3 loops"; \
	 skip; \
      fi \
}'

alias require4loops='{ \
      if [ $(echo $loops | wc -w) -lt 4 ]; then \
         step "Require at least 4 loops"; \
	 skip; \
      fi \
}'

genshuf()
{
    local loop

    : >$work/shufdata

    for loop in $(shuf -e $loops); do
	echo $loop $(shuf -en1 0 1) >>$work/shufdata
    done
}

setshuf()
{
    local to
    local from
    local invert

    set $(cat $work/shufdata)
    for to in $loops; do
	from=$1;
	invert=$2
	shift 2

	if [ $invert -eq 0 ]; then
	    eval 'sb'$to'=$b'$from
	    eval 'sh'$to'=$h'$from
	else
	    eval 'sb'$to'=$h'$from
	    eval 'sh'$to'=$b'$from
	fi
    done

    for to in $(shuf -e $loops); do
	eval 'b'$to'=$sb'$to
	eval 'h'$to'=$sh'$to
    done
}

printtopology()
{
    [ $V -gt 0 ] || return

    local l="$loops"
    local bp="$bports"
    local hp="$hports"

    while [ $(car $l) ]; do
	printf "(b%u) %s <--> %s (h%u)\n" \
	       $(car $l) $(car $bp) $(car $hp) $(car $l)

	l="$(cdr $l)"
	bp="$(cdr $bp)"
	hp="$(cdr $hp)"
    done
}

step()
{
    t_step="$*"
    printf "\e[1m%s:\e[0m %s\n" "$t_current" "$t_step"

    [ -n "$single_step" ] && read -p "Single-stepping, press enter to continue"
}

depcheck()
{
    "$@" -h >/dev/null 2>&1 && return

    die "\"$*\" is missing"
}

# shellcheck disable=SC2086
phys()
{
    eval echo '$'${1}${2}
}

car()
{
    echo "$1"
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

# shellcheck disable=SC2183 disable=SC2086
addrfmt()
{
    bytes=$(echo 0x$* | sed -e 's/:/ 0x/g')
    printf '\\%3.3o\\%3.3o\\%3.3o\\%3.3o\\%3.3o\\%3.3o' $bytes
}

# shellcheck disable=SC2183 disable=SC2046
rndaddr()
{
    printf '%2.2x:%2.2x:%2.2x:%2.2x:%2.2x:%2.2x' \
	   $((($(shuf -i 0-255 -n 1) & 0xfe) | 2)) $(shuf -i 0-255 -n 5)
}

ifaddr()
{
    ip -br link show dev "$1" | awk '{ print($3); }'
}

ipaddr()
{
    ip -br addr show dev "$1" | awk '{ split($3,a,"/"); print a[1]; }'
}

# Generate low-level Ethernet frames for basic layer-2 tests.
# For layer-3 and upwards, use ping, nemesis or other tools.
#
# Legend:
#   b: broadcast dest addr
#   d: local dest addr from arg
#   g: global dest addr from arg (multicast)
#   i: source addr from interface arg
#   I: dest addr from interface arg
#   q: 802.1Q VLAN tag with VID arg
#   s: local source addr from arg
#   t: ether type/len from arg
#
# shellcheck disable=SC2046 disable=SC2059 disable=SC2086
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

_kill_capture()
{
    local pid=$(eval echo '$'"${1}_capture")
    if [ -n "$pid" ]; then
	kill -1 "$pid" && wait "$pid"
	eval "unset ${1}_capture"
    fi
}

_capture()
{
    local pcap="${t_work}/${1}.pcap"
    local filter="${2}"

    rm -f "$pcap"
    # Note: arguments must be compatible with tshark as well!
    $tcpdump -q -lnp -i "$1" -w "$pcap" -s 128 "$filter" 2>/dev/null &
    eval "${1}_capture=$!"

    #shellcheck disable=SC2034
    for i in $(seq 50); do
	[ -f "$pcap" ] && return 0
	sleep 0.1
    done

    die "unable to start capture on $1"
}

capture()
{
    local filter="ether proto 0xbbbb"

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
    step "$*: capturing $filter ..."

    while [ $# -gt 0 ]; do
	_capture "$1" "$filter"
	shift
    done

    [ "$conf_capture_delay" ] && sleep "$conf_capture_delay"
}

# shellcheck disable=SC2086
report()
{
    opts="-n -A"

    while getopts "o:" opt; do
	case $opt in
	    o)
		opts="$OPTARG"
		;;
	    *)
		exit 1
		;;
	esac
    done
    shift $((OPTIND - 1))

    _kill_capture "${1}"
    $capread $opts -r "$t_work/${1}.pcap" 2>/dev/null
}

# Inject IGMP v2 query frames on interface $1
mcast_query_start()
{
    nemesis igmp -d "$1" -p 0x11 -r 100 -c 100 -D 224.0.0.1 -i 10 &
    eval "${1}_query=$!"
}

mcast_query_stop()
{
    local pid=$(eval echo '$'"${1}_query")
    if [ "$pid" ]; then
	kill -1 "$pid" && wait "$pid"
	eval "unset ${1}_query"
    fi
}

# Joins group 225.1.2.3 on interface $1
# NOTE: the interface must have an IPv4 address
mcast_join()
{
    local group=225.1.2.3
    local addr=$(ipaddr "$1")
    [ -z "$addr" ] && die "Interface $1 has no address"

    step "$1: joining $group from $addr"
    socat UDP4-RECVFROM:6666,ip-add-membership=$group:$addr,fork EXEC:hostname &
    eval "${1}_join=$!"
}

mcast_leave()
{
    local pid=$(eval echo '$'"${1}_join")
    if [ "$pid" ]; then
	kill -1 "$pid" && wait "$pid"
	eval "unset ${1}_join"
    fi
}

# Blocking multicast generator, sends 3 ICMP messages on interface $1
# to group 225.1.2.3 by default.  Override with -c NUM and -g GROUP.
mcast_gen()
{
    local group="225.1.2.3"
    local cnt=3

    while getopts "c:g:" opt; do
	case $opt in
	    c)
		cnt="$OPTARG"
		;;
	    g)
		group="$OPTARG"
		;;
	    *)
		exit 1
		;;
	esac
    done
    shift $((OPTIND - 1))

    step "$h1: sending multicast to $group ($cnt sec) ..."
    ping -qc "$cnt" -W 1 -I "$1" "$group" >/dev/null
}

# Find gaps in ICMP multicast streams
mcast_analyze_gaps()
{
    step "$h1: analyzing, should be uninterrupted from first to last packet ..."

    _kill_capture "${1}"
    $capread -nr "$t_work/${1}.pcap" icmp 2>/dev/null >"$t_work/${1}.text"

    # Find first and last ICMP sequence number (works with tshark & tcpdump)
    sed 's/.*seq \([0-9]*\),.*/\1/g' <"$t_work/${1}.text" >"$t_work/${1}.seqnos"
    #first=1
    local first=$(head -1 "$t_work/${1}.seqnos")
    local last=$(tail -1 "$t_work/${1}.seqnos")

    seq "$first" "$last" >"$t_work/${1}.seq"
    cmp "$t_work/${1}.seq" "$t_work/${1}.seqnos" || fail
}

inject()
{
    # Collect all data to make sure that we hand it to socat in a
    # single write(1).
    cat >"$t_work/last.bin"

    $socat -u open:"$t_work/last.bin" "interface:$1"

    [ "$conf_inject_delay" ] && sleep "$conf_inject_delay"
}

create_br()
{
    local br="$1"
    local opts="$2"
    shift 2

    # shellcheck disable=SC2086
    ip link add dev "$br" type bridge $opts
    ip link set dev "$br" up

    while [ $# -gt 0 ]; do
	ip link set dev "$1" master "$br"
	shift
    done
}

