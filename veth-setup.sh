# shellcheck disable=SC2034

conf_capture_delay=1
conf_inject_delay=1
loops="1 2 3"

for i in $loops; do
    ip link del dev "vh$i" type veth >/dev/null 2>&1
done

for i in 1 2 3; do
    if ! ip link add dev "vb$i" type veth peer name "vh$i"; then
	echo "unable to create veth pair $i" >&2
	exit 1
    fi
done

b1=vb1
h1=vh1
b2=vb2
h2=vh2
b3=vb3
h3=vh3
