#!/bin/bash

. /var/lib/event/redback_sync/bin/const.sh

echo _____clips_detail_______
grep -m1 --color -w "clips $1" -B 2 -A 1000 $FILESDIR/clips_detail.txt | grep -m2 -B 1000 statclips || echo no data in clips detail

echo _____clips_all_______
grep -m1 --color -w "$1" $FILESDIR/clips_all.txt || echo no data in clips all

echo '______tray_logged______'

selexec "SELECT 
        id, uf_ip2string(ip), tray_logged, auth_type, deleted
from users
        left outer join tray_cache on tray_cache.user_id=users.id
        left outer join users_radiusauth on users_radiusauth.user_id=users.id
where
        acct_session_id is not null
        and nas_ip=uf_string2ip('$nas_ip')
        and over_limit_date is null
        and deleted=0
        and enabled=1
        and auth_type!=1 
	and id=$1"

echo '______auth_type_cache______'

sqlexec "SELECT
	id, uf_ip2string(ip), auth_type_cache, deleted, logged, enabled
from 
	users
where
	id=$1"

echo '______retmsg_______'

selexec "SELECT
	retmsg
from
	cln_usr_test($1)" | iconv -f cp1251 -t koi8-r
echo '______cmd_________'

find -name "${1}.cmd"
