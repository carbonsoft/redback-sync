#!/bin/bash

# Проходимся по списку сгенеренных задач и выполняем их.
# Для nondhcpclips adduser / send_connect больше не нужны.

. /var/lib/event/redback_sync2/bin/const.sh

context="nondhcpclips"
community="supercommunity"

id2ip() {
	grep -w "$1" "$ALLUSERSLIST" | awk '{print $3}'
}

id2acct_session() {
	grep -w "$1" "$ID_ACCT_SESSION_LIST" | awk '{print $2}'
}

RADCLIENT() {
	radclient -x $nas_ip:$coa_port coa $nas_pass 2>&1 | grep -i "Session-Context-Not-Found"
}

snmp_disconnect() {
	/bin/bash $RECONNECT_SNMP $telnet_ip $(id2ip $1) $1 $context $community
}

remove_policy() {
	echo 'User-Name="'$(id2ip $1)'",'"$REMOVE_POLICY" | RADCLIENT
}

adduser() {
	return 0
}

send_connect() {
	return 0
}

deluser() {
	snmp_disconnect $1
}

send_disconnect() {
	snmp_disconnect $1
}

remove_noauth_redirect() {
	remove_policy $1
}

remove_negbal_redirect() {
	remove_policy $1
}

set_noauth_redirect() {
	echo 'User-Name="'$(id2ip $1)'",'"$NOAUTH_POLICY" | RADCLIENT
}

set_negbal_redirect() {
	echo 'User-Name="'$(id2ip $1)'",'"$NEGBAL_POLICY" | RADCLIENT
}

run_commands() {
	for dir in $CMD_DIR_LIST; do
		for id in $(find ${SPOOLDIR}$dir -name "*.cmd" | sed -e 's/.*\///g; s/[^0-9]//g'); do
			echo "$dir $id "
			$dir $id #>> /var/log/redback_sync2_details.log
			if [ "$?" != 0 ]; then
				echo "$dir $id" > $POOLDIR/errors/$id.cmd
			fi
			echo "$dir $id" >> /var/log/redback_sync.log
		done
	done
}

main() {
	LANG=C date >> /var/log/redback_sync.log
	run_commands
}

main
