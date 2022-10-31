#! /bin/bash


# A script to sniff the network adapter for incoming connections
# (if -b is specified) add an iptables rule for all connections
# that don not match the country by regular expression.
#
# tcpgeo.sh '(iran|germany)' -q

CY="\e[1;33m" # yellow
CDY="\e[0;33m" # yellow
CR="\e[1;31m" # red
CB="\e[1;34m" # blue
CC="\e[1;36m" # cyan
CG="\e[1;32m" # green
CDG="\e[0;32m" # green
CDC="\e[0;36m" # cyan
CDR="\e[0;31m" # red
CN="\e[0m"    # none
CW="\e[1;37m" # white
CF="\e[2m"    # faint

BASEDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
PATH="${BASEDIR}:${PATH}"
[[ -z $MMDB_PATH ]] && MMDB_PATH=${BASEDIR}
GEODB="${MMDB_PATH}/GeoLite2-Country.mmdb"
PCAP="tcp[tcpflags] & (tcp-syn|tcp-ack) == tcp-syn or icmp"


ERREXIT()
{
	local code
	code=$1

	shift 1
	echo -e "${CR}ERROR${CN}: $*"
	exit $code
}

usage()
{
	echo -e >&2 "\
Usage:
    tcpgeo.sh [country-regex] [-bq] <tcpdump options> <pcap filter>.
Options:
     -b    Block Class-C of IP if country does NOT matches Regular Expression
     -q    Only display Class-C matches once

The 'pcap filter' is optional and by default all new incoming
TCP & ICMP are monitored.

Example: Block all traffic that is not from germany or iran:
    ${CDC}tcpgeo.sh '(iran|germany)' -b -q ${CN}
Example: Monitor eth0 only and only ICMP. Do not block any traffic.
    ${CDC}tcpgeo.sh iran -i eth0 ICMP${CN}
Example: Monitor all new connections ONCE (dont block):
    ${CDC}tcpgeo.sh iran -q${CN}
"
}

on_exit()
{
	[[ -n $is_with_block ]] && {
		blocks_now=$(iptables -n -L INPUT | wc -l)
		echo -e "New blocks: $((blocks_now - blocks_start)) [${CDC}iptables -n -L${CN}]"
	}
}

init()
{
	trap on_exit EXIT

	REGEX="$1"
	[[ -z "$REGEX" ]] && {
		usage
		exit 255
	}
	command -v tcpdump &>/dev/null || ERREXIT 255 "Not found: tcpdump. Try \`apt install tcpdump\`."
	command -v jq &>/dev/null || ERREXIT 255 "Not found: jq. Try \`apt install jq\`."
	command -v mmdbinspect &>/dev/null || {
		curl -fsSL 'https://github.com/maxmind/mmdbinspect/releases/download/v0.1.1/mmdbinspect_0.1.1_linux_amd64.tar.gz' |tar xfvz - --strip-components=1 --no-anchored -C "${BASEDIR}" mmdbinspect || ERREXIT 255
	}
	[[ ! -d "${MMDB_PATH}" ]] && mkdir -p "${MMDB_PATH}"

	[[ ! -f "${GEODB}" ]] && {
		curl -fsSL 'https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=zNACjsJrHnGPBxgI&suffix=tar.gz' | tar xfvz - --strip-components=1 --no-anchored -C "${MMDB_PATH}" GeoLite2-Country.mmdb || ERREXIT 255 "Downloading GeoLite2 DB"
	}
}



allow_myself()
{
	local src="$1"

	[[ -z $src ]] && return

	iptables -C INPUT -s "${src%.*}.0/24" -j ACCEPT 2>/dev/null && return
	iptables -A  INPUT -s "${src%.*}.0/24" -j ACCEPT
}


block()
{
	local net
	local src
	src="$1"
	net="${src%.*}"


	[[ "${DB_BLOCKED[*]}" == *"b${net}b"* ]] && return
	DB_BLOCKED+=("b${net}b")

	iptables -C INPUT -s "${net}.0/24" -j DROP 2>/dev/null && return
	iptables -A INPUT -s "${net}.0/24" -j DROP
}

seen()
{
	local src
	local net
	src="$1"
	net="${src%.*}"

	[[ "${DB_BLOCKED[*]}" == *"b${net}b"* ]] && return 0
	[[ "${DB_SEEN[*]}" == *"s${net}s"* ]] && return 0
	DB_SEEN+=("s${net}s")
	return 1 # not yet seen
}

tcpdump2ip()
{
	local l
	local ttl
	local src

	IFS='' # Do not strip \s from beginning of each line.
	while read l; do
		# IP (tos 0x10, ttl 64, id 13760, offset 0, flags [DF], proto TCP (6), length 164)
		[[ $l == "IP ("* ]] && {
			ttl="${l#*, ttl }"
			ttl="${ttl%%, id *}"
			TCP_INFO=$l
			unset want_ttl
			unset strip_port
			[[ $l == *"proto TCP "* ]] || [[ $l == *"proto UDP "* ]] && strip_port=1
			continue
		}

		[[ -n $want_ttl ]] && continue
		want_ttl=1

		# 10.0.2.15.22 > 10.0.2.2.52280: Flags [P.], cksum 0x18a7 (incorrect -> 0xfdf6), seq 1000867952:1000868076, ack 3591749171, win 62780, length 124
		src=${l%% > *}
		src=${src// /} # Trim whitespace from beginning of line
		[[ -n $strip_port ]] && src="${src%.*}"
		country=$(mmdbinspect -db "${GEODB}" "${src}" | jq -r '.[0].Records[0].Record.country.names.en | select(. != null)')
		[[ -n $is_quiet ]] && {
			seen "$src" && continue
		}
		if [[ -z $country ]]; then
			country="${src}"
			color="${CDY}"
		elif [[ ${country,,} =~ ^$REGEX ]]; then
			color="${CDG}"
		else
			color="${CDR}"
			[[ -n $is_with_block ]] && block "$src"
		fi
		country+="                       "
		ttl+="  "
		IFS=' ' # Trim's whitespace in $l if "" are not used.
		echo -e "${color}${country:0:12}${CN} TTL ${ttl:0:3}" $l
		IFS=''
	done
}

init "$@"
shift 1

# Collect tcpdump params
while getopts ":hbqi:" opt; do
	case $opt in
	i)
		opts+=("-i" "$OPTARG")
		;;
	b)
		is_with_block=1
		;;
	q)
		is_quiet=1
		;;
	h)
		usage
		exit
		;;
	*)
		break
		;;
	esac
done
shift $(($OPTIND - 1))

[[ -n $* ]] && PCAP="$*"
[[ -n $is_with_block ]] && {
	allow_myself "${SSH_CONNECTION%% *}"
	iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	blocks_start=$(iptables -n -L INPUT | wc -l)
}

tcpdump -l -t -vn -Qin "${opts[@]}" "$PCAP" | tcpdump2ip 

