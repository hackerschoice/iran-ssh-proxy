#!/command/with-contenv bash

# This script is executed on the exit point. It connects to the
# bridge (inside Iran) and creates tunnels.
#
# CONFIG=USER:PASSWORD@IP:22:SXPORT

ERREXIT()
{
	local code
	code=$1
	shift 1

	echo >&2 "$@"
	exit "$code"
}

SOPTS=("-oStrictHostKeyChecking=no")
SOPTS+=("-oServerAliveInterval=30")
SOPTS+=("-oServerAliveCountMax=3")
SOPTS+=("-oExitOnForwardFailure=yes")

[[ -n $1 ]] && CONFIG=$1
[[ -z $CONFIG ]] && { echo "ERROR: No CONFIG= set and no parameters. Dropping into shell"; exec /bin/bash -il; }
suser="${CONFIG%%:*}"
str="${CONFIG#*:}"
spass="${str%@*}"
sipport="${str##*@}"
sip="${sipport%:*}"
sport=${sipport##*:}
[[ -z $sport ]] && sport=22
[[ -z $EXIT_NAME ]] && EXIT_NAME="THC-${sip//./-}"

[[ -f "${spass}" ]] && { skey="${spass}"; unset spass; }
[[ -z $skey ]] && [[ -z spass ]] && { echo "Bad CONFIG="; exit 255; }

echo "USER: ${suser}"
echo "HOST: ${sip}:${sport}"

[[ -n $FP_SSH ]] && FP_SSH=("$FP_SSH")
[[ -n $FP_SX ]] && FP_SX=("$FP_SX")
[[ -n $FP_HTTP ]] && FP_HTTP=("$FP_HTTP")
[[ -n $FP_SS ]] && FP_SS=("$FP_SS")

# [[ -z $FP_SS ]] && FP_SS+=("8388" "18388")
[[ -z $FP_SS ]] && FP_SS+=("18388")

if [[ "${suser}" == "root" ]]; then
	[[ -z $FP_SSH ]] && FP_SSH+=("443" "1443")
	[[ -z $FP_SX ]] && FP_SX+=("993" "1993")
	[[ -z $FP_HTTP ]] && FP_HTTP+=("80" "8080")
else 
	[[ -z $FP_SSH ]] && FP_SSH+=("1443")
	[[ -z $FP_SX ]] && FP_SX+=("1993")
	[[ -z $FP_HTTP ]] && FP_HTTP+=("8080")
fi

for s in "${FP_SSH[@]}"; do RED+=("-R${s}:127.0.0.1:22"); FP_SSH_INFO+="$sip:${s} "; done
for s in "${FP_SX[@]}"; do RED+=("-R${s}:127.0.0.1:1080"); FP_SX_INFO+="$sip:${s} "; done
for s in "${FP_HTTP[@]}"; do RED+=("-R${s}:127.0.0.1:80"); FP_HTTP_INFO+="http://${sip}:${s} "; done
for s in "${FP_SS[@]}"; do RED+=("-R${s}:127.0.0.1:8388"); done

server_str="${sip} PORT <span style=\"background-color:yellow;\">${FP_SSH[0]}</span> (use this for PuTTY)"

ss_b64=$(echo -n "chacha20-ietf-poly1305:proxy@${sip}:${FP_SS[0]}" | base64)
ss_config_str="ss://${ss_b64}#${EXIT_NAME}"

sed 's/@@@SIP@@@/'"${sip}"'/g' -i /var/www/html/index.html
sed 's/@@@SPORT@@@/'"${FP_SSH[0]}"'/g' -i /var/www/html/index.html
sed 's|@@@SS@@@|'"${ss_config_str}"'|g' -i /var/www/html/index.html

# Create QR for this webpage:
qrencode -o /var/www/html/qr.png -s 6 "http://${sip}:${FP_HTTP[-1]}"

qrencode -o /var/www/html/qr-ss.png -s6 "${ss_config_str}"

SCMD="\
grep \"^GatewayPorts yes\" /etc/ssh/sshd_config >/dev/null || { echo \"Please set 'GatewayPorts yes' in /etc/ssh/sshd_config\"; exit 240; }
echo \"SOCKS: ${FP_SX_INFO}\"
echo \"SSH  : ${FP_SSH_INFO}\"
echo \"SS   : ${sip}:${FP_SS[0]}\"
echo \"WEB  : ${FP_HTTP_INFO}\"
exec sleep infinity
"

# Try to log in
err=0
while :; do
	last=$(date +%s)
	if [[ -n $spass ]]; then
		sshpass -p "${spass}" ssh -p "${sport}" "${RED[@]}" "${SOPTS[@]}" "${suser}@${sip}" "${SCMD}"
	else
		ssh -i "${skey}" -p "${sport}" "${RED[@]}" "${SOPTS[@]}" "${suser}@${sip}" "${SCMD}"
	fi
	ret=$?
	echo ret=$ret
	[[ $ret -eq 5 ]] && break # Permission denied
	[[ $ret -eq 240 ]] && break

	now=$(date +%s)
	[[ $((last + 60 )) -gt $now ]] && {
		# HERE: Error encountered immediately
		((err++))
		[[ $err -gt 10 ]] && { ERREXIT 255 "To many errors. Exiting..."; }
		[[ -z $success ]] && {
			# HERE: Never had a success
			[[ $ret -eq 5 ]] && ERREXIT 255 # Permission denied
		}
		sleep 15
	} || unset err
	success=1
done

