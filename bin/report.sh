#!/bin/bash

. /var/lib/event/redback_sync2/bin/const.sh

for i in $CMD_DIR_LIST; do 
	[ -d "${SPOOLDIR}$i" ] || continue
	printf "%25s" "$i"
	find ${SPOOLDIR}$i -name "*.cmd" | wc -l
done

echo "--------------------------------"

printf "%25s" всего
find $POOLDIR -type f -name "*.cmd" | sed -e 's/[^0-9]//g' | wc -l
printf "%25s" уникальных
find $POOLDIR -type f -name "*.cmd" | sed -e 's/[^0-9]//g' | sort | uniq | wc -l
