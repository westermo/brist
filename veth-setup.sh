conf_capture_delay=1
conf_inject_delay=1

for port in vax vay vbx vby vcx vcy; do
    ip link del dev $port type veth >/dev/null 2>&1
done

ip link add dev vax type veth peer name vay && \
ip link add dev vbx type veth peer name vby && \
ip link add dev vcx type veth peer name vcy || \
	{ echo unable to create veth pairs >&2; exit 1; }

ax=vax
ay=vay
bx=vbx
by=vby
cx=vcx
cy=vcy

loops="a b c"
