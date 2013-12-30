#!/bin/bash

# Собираем данные о пользователях из базы данных, парсим данные с redback, сравниваем, ищем неполадки,
# генерируем задачи по ним, отсылаем админу отчёт о косяке на почту.

. /etc/ics/ics.conf
. /var/lib/event/redback_sync/bin/const.sh

check_files_date() {
	local LOCAL_DATE="$(LANG=C ls -l $FILESDIR/clips_* |  awk '{print $6" "$7}')"
	local REMOTE_DATE="$($TCLDIR/files_rb_check.tcl  | awk '{print $6" "$7}' | grep -v "^ $")"
	[ "$LOCAL_DATE" = "$REMOTE_DATE" ]
	local retval=$?
	if [ "$retval" != '0' ]; then
		echo "Local:" $LOCAL_DATE
		echo "Remote:" $REMOTE_DATE
	fi
	return $retval
}

update_files() {
	echo ${FUNCNAME} >&2
	rm -f $CLIPSUP $CLIPSDETAIL

	$TCLDIR/files_rb.tcl # > /dev/null

	#check clips
	[ ! -f $CLIPSUP ] && echo No $CLIPSUP && exit 1
	[ ! -f $CLIPSDETAIL ] && echo No $CLIPSDETAIL && exit 1

	if ! check_files_date; then
		echo "Different date at local and remote files!"
		exit 1
	fi
}

prepare_clips() {
	( cd $SPOOLDIR; rm -rf $CMD_DIR_LIST; mkdir -p $CMD_DIR_LIST; )
	tail -n +3  $CLIPSUP | sort -k 6 > $CLIPSUPSORT
}

# дергаем список пользователей, todo: sqlexec clips pvc id sort by id, в результате минус 1 вайлрид
get_radius_list() {
	sqlexec "SELECT 
		'rowrow', id 
	FROM 
		users 
	WHERE 
		auth_type_cache=6 and nas_ip=uf_string2ip('$nas_ip') and id < 100000" | grep rowrow | awk '{print $2}' | sort > $RADIUS_USERS_LIST
}

get_id_radius_session_list() {
	awk '{print $2" "$9}' $TMPUSERLIST | grep -v null > $ID_ACCT_SESSION_LIST
}

get_noauth_no_radius() {
	join -a 1 -j 1 -v 1 $CLIPS_NOAUTH_LIST $RADIUS_USERS_LIST > $CLIPS_NOAUTH_LIST_NORADIUS
}

get_disabled_list() {
	sqlexec "SELECT 
		'rowrow', id 
	FROM 
		users 
	WHERE 
		enabled=0 and nas_ip=uf_string2ip('$nas_ip') and id < 100000" | grep rowrow | awk '{print $2}' | sort > $DISABLED_USERS_LIST
}

get_noauth_no_radius_no_disabled() {
	echo ${FUNCNAME} >&2
	join -a 1 -j 1 -v 1 $CLIPS_NOAUTH_LIST_NORADIUS $DISABLED_USERS_LIST > $CLIPS_NOAUTH_LIST_NORADIUS_NODISABLED
}

get_noauth_no_disabled() {
	echo ${FUNCNAME} >&2
	join -a 1 -j 1 -v 1 $CLIPS_NOAUTH_LIST $DISABLED_USERS_LIST > $CLIPS_NOAUTH_LIST_NODISABLED
}

get_all_user_list() {
	echo ${FUNCNAME} >&2
	sqlexec "SELECT 'rowrow', id, uf_ip2string(ip) from users where id < 100000" \
		| grep 'rowrow' | grep [0-9][.] > $ALLUSERSLIST
}

get_user_list() {
	echo ${FUNCNAME} >&2
	sqlexec "select 'rowrow', id, uf_ip2string(ip), cast(over_limit_date as date), deleted,
		enabled, cast(OWN_DISABLED_END as date), users.logged,
		acct_session_id , users_radiusauth.logged, users_radiusauth.radius_logged, users.auth_type_cache
	from users left outer join users_radiusauth
		on users_radiusauth.user_id=users.id
	where 
		nas_ip=uf_string2ip('$nas_ip') and id < 100000 order by deleted desc" \
	| grep rowrow  | grep [0-9][.] > $TMPUSERLIST

	while read t id ip over_limit_date  deleted enabled own_disabled_end logged acct_session_id r_logged r_radius_logged auth_type t ; do
		echo $id $ip $over_limit_date $deleted $enabled $own_disabled_end $logged $acct_session_id $auth_type
	done < $TMPUSERLIST > $SQLUSERLIST
}

get_tray_list() {
	echo ${FUNCNAME} >&2
	sqlexec "SELECT 'rowrow', 
		id, uf_ip2string(ip), tray_logged, auth_type_cache, deleted 
	from users 
		left outer join tray_cache on tray_cache.user_id=users.id 
		left outer join users_radiusauth on users_radiusauth.user_id=users.id 
	where 
		acct_session_id is not null 
		and nas_ip=uf_string2ip('$nas_ip')
		and over_limit_date is null
		and deleted=0
		and enabled=1
		and id < 100000
		and auth_type_cache=6" > $SQL_TRAY_CACHE.tmp
	grep rowrow $SQL_TRAY_CACHE.tmp > $SQL_TRAY_CACHE || true
}

# ГЕНЕРАЦИЯ ИСХОДНЫХ ДАННЫХ

# список всех юзеров на редбэке
get_sort_user_list() {
	echo ${FUNCNAME} >&2
	while read id t; do
		echo "    clips pvc $id" 
	done < $SQLUSERLIST | sort > $ALLIDLIST 
}

# список всех юзеров на редбэке
get_sort_user_list_no_deleted() {
	echo ${FUNCNAME} >&2
	while read id t t deleted enabled t; do
		if [ "$deleted" = '0' -a "$enabled" = '1' ]; then
			echo "    clips pvc $id" 
		fi
	done < $SQLUSERLIST | sort > $EXISTINGIDLIST 
}

get_logged_user_list() {
	echo ${FUNCNAME} >&2
	# список всех залогиненых на редбэке в стиле clips_up
	while read id ip t t t t logged t; do
		if [ "$logged" = '1' ]; then
			echo "lg id 825 clips 132284               $ip         $ip"
		fi
	done < $SQLUSERLIST | sort > $UPIDLIST 
}

get_sql_nomoney_list() {
	echo ${FUNCNAME} >&2
	# список пользователей которых надо редиректить на негбал, согласно базе
	while read id ip over_limit_date deleted enabled tmp; do
		[ "$over_limit_date" = '<null>' ] && overlimit=0 || overlimit=1
		if [ "$overlimit" = '1' -a "$enabled" = '1' -a "$deleted" = '0' ]; then
			echo "$id $ip http://10.0.0.100/nomoney" 
		fi
	done < $SQLUSERLIST | sort > $NEGBAL_LIST
}

# распарсенный clips_detail для nomoney
get_parsed_nomoney_list() {
        echo ${FUNCNAME} >&2
        while read line; do
                if [[ "$line" = *address* ]]; then
                        unset id ip redirect policy
                        ip=${line//[^0-9.]/}
                fi

                [[ "$line" = *Circuit*clips* ]] && id=${line##* }
                [[ "$line" = *HTTP-REDIRECT* ]] && policy=1

                if [[ "$line" = *http-redirect-url* ]]; then
                        redirect="${line#* }"
                        redirect=${redirect% *}
                fi

                if [ "$redirect" = 'http://10.0.0.100/nomoney' -a "$policy" = '1' ]; then
                        echo $id $ip $redirect
                        unset id ip redirect policy
                fi
        done < $CLIPSDETAIL | sort > $CLIPS_NEGBAL
}

# ТУДУ ТРЭЙ
# список пользователей которых надо редиректить на noauth, согласно базе
get_sql_noauth_list() {
	echo ${FUNCNAME} >&2
	while read tmp id ip tray_logged auth_type deleted tmp; do
		if [ "$tray_logged" = '0' -a "$auth_type" != '1' -a "$auth_type" != '6' -a "$deleted" = '0' ]; then
			echo "$id $ip http://10.0.0.100/noauth"
		fi
	done < $SQL_TRAY_CACHE | sort > $SQL_NOAUTH_LIST
}

get_sql_auth_list() {
	echo ${FUNCNAME} >&2
	while read tmp id ip tray_logged auth_type deleted tmp; do
		if [ "$tray_logged" = '1' -a "$auth_type" != '1' -a "$deleted" = '0' ]; then
			echo "$id $ip http://10.0.0.100/noauth"
		fi
	done < $SQL_TRAY_CACHE | sort > $SQL_AUTH_LIST
}

print_parsed_noauth_list() {
        echo ${FUNCNAME} >&2
        while read line; do
                if [[ "$line" = *address* ]]; then
                        unset id ip redirect policy
                        ip=${line//[^0-9.]/}
                fi

                [[ "$line" = *Circuit*clips* ]] && id=${line##* }
                [[ "$line" = *HTTP-REDIRECT* ]] && policy=1

                if [[ "$line" = *http-redirect-url* ]]; then
                        redirect="${line#* }"
                        redirect=${redirect% *}
                fi

                if [ "$redirect" = 'http://10.0.0.100/noauth' -a "$policy" = '1' ]; then
                        echo $id $ip $redirect
                        unset id ip redirect policy
                fi
        done < $CLIPSDETAIL | sort
}

get_parsed_noauth_list() {
	echo ${FUNCNAME} >&2
	print_parsed_noauth_list > $CLIPS_NOAUTH_LIST
}

# ПОЛУЧЕНИЕ СПИСКОВ КОМАНД ДЛЯ РЕДБЭКА

# список юзеров которых надо добавить на редбэк
# те, кто не deleted, enabled, есть в базе, нет в клипсах
do_adduser_list() {
	echo ${FUNCNAME} >&2
	join -a 1 -j 3 -v 1  $EXISTINGIDLIST $CLIPSALLSORT >  $ADD_REDBACK
	find ${SPOOLDIR}/adduser/ -name "*.cmd" | xargs rm -f
	while read id tmp; do
		echo "Add_user $1" > ${SPOOLDIR}/adduser/$id.cmd
	done < $ADD_REDBACK
}

# список юзеров которых надо удалить с редбэка
do_deluser_list() {
	join -a 1 -j 3 -v 1  $CLIPSALLSORT $ALLIDLIST >  $DEL_REDBACK
	find ${SPOOLDIR}/deluser/ -name "*.cmd" | xargs rm -f
	while read id tmp; do
		echo "Del_user" > ${SPOOLDIR}/deluser/$id.cmd
	done < $DEL_REDBACK
}

# список пользователей которых надо пропустить на редбэке
# те, кто logged в базе на этом nas и нет в clips_up.txt
do_send_connect_list() {
	join -a 1 -j1 7 -j2 5 -v 1 $UPIDLIST $CLIPSUPSORT > $NEED_CONNECT
	find ${SPOOLDIR}/send_connect/ -name "*.cmd" | xargs rm -f
	# while read a b c d e f id ip g; do
	while read id t t t t t t ip t; do
		echo "Connect user $ip" > ${SPOOLDIR}/send_connect/$id.cmd
	done < $NEED_CONNECT
}

# список тех, кого надо бы отключить
do_send_disconnect_list() {
	join -a1 -j 6 -v1 $CLIPSUPSORT $UPIDLIST > $NEED_DISCONNECT
	join -a 1 -j 1 -v 1 $NEED_DISCONNECT $CLIPS_NEGBAL > $NEED_DISCONNECT_WITHOUT_NEGBAL
	find ${SPOOLDIR}/send_disconnect/ -name "*.cmd" | xargs rm -f
	while read t t t t t t ip t; do
		id=$(ip2id $ip)
		echo "Disconnect user $ip" > ${SPOOLDIR}/send_disconnect/$id.cmd
	done < $NEED_DISCONNECT_WITHOUT_NEGBAL
}

do_set_negbal_redirect_list() {
	join -a 1 -j 1 -v 1 $NEGBAL_LIST $CLIPS_NEGBAL | sort -r > $ADD_NEGBAL.tmp
	join  -j1 2 -j2 6 $ADD_NEGBAL.tmp $CLIPSUPSORT | sort > $ADD_NEGBAL
	find ${SPOOLDIR}/set_negbal_redirect/ -name "*.cmd" | xargs rm -f
	while read ip id link tmp; do
		echo "Add $ip to $link redirect" > ${SPOOLDIR}/set_negbal_redirect/$id.cmd
	done < $ADD_NEGBAL
}

# список пользователей у которых необходимо убрать негбал с редбэка
do_remove_negbal_redirect_list() {
	join -a 1 -j 1 -v 1 $CLIPS_NEGBAL $NEGBAL_LIST | sort -r > $DEL_NEGBAL.tmp
	join  -j1 2 -j2 6 $DEL_NEGBAL.tmp $CLIPSUPSORT | sort > $DEL_NEGBAL
	find ${SPOOLDIR}/remove_negbal_redirect/ -name "*.cmd" | xargs rm -f
	while read id ip link; do
		echo "Del $ip to $link redirect" > ${SPOOLDIR}/remove_negbal_redirect/$id.cmd
	done < $DEL_NEGBAL
}

# список пользователей у которых необходимо добавить noauth на редбэк
do_set_noauth_redirect_list() {
	join -a 1 -j 1 -v 1 $SQL_NOAUTH_LIST $CLIPS_NOAUTH_LIST | sort -r > $ADD_NOAUTH.tmp
	join -j1 2 -j2 6 $ADD_NOAUTH.tmp $CLIPSUPSORT | sort > $ADD_NOAUTH
	find ${SPOOLDIR}/set_noauth_redirect -name "*.cmd" | xargs rm -f
	while read id ip link; do
		echo "Add $ip to $link redirect" > ${SPOOLDIR}/set_noauth_redirect/$id.cmd
	done < $ADD_NOAUTH 
}


# список пользователей у которых необходимо убрать noauth с редбэка
# нет негбала в базе, есть негбал на редбэке, авторизация не IP и не Radius
# ещё бы как-то enabled проверять
do_remove_noauth_redirect_list() {
	join -a 1 -j 1 -v 1 $CLIPS_NOAUTH_LIST_NORADIUS_NODISABLED $SQL_NOAUTH_LIST | sort -r > $DEL_NOAUTH.tmp
	join  -j1 1 -j2 6 $DEL_NOAUTH.tmp $CLIPSUPSORT | sort > $DEL_NOAUTH
	find ${SPOOLDIR}/remove_noauth_redirect -name "*.cmd" | xargs rm -f
	while read ip link; do
		echo "Del $ip to $link redirect" > ${SPOOLDIR}/remove_noauth_redirect/$(ip2id $ip).cmd
	done < $DEL_NOAUTH
}

cleanup_tmp() {
	date +${FUNCNAME}_%s
	rm -f ${PREFIX}*
}

make_report() {
	for i in $CMD_DIR_LIST; do 
		echo
		echo $i:
		ls $SPOOLDIR$i | xargs echo | sed -e 's/.cmd//g'
	done > $REPORT_FILE
}

send_report() {
	/usr/local/ics/bin/msg_email "$HOSTNAME" "$ADMIN_MAIL" "$(cat $REPORT_FILE)"
}

# ВЫЗОВ ВСЕХ ФУНКЦИЙ

get_lists() {
	date +${FUNCNAME}_%s
	get_all_user_list		# все пользователи на этом nas_ip
	get_user_list
	get_radius_list			# все радиус пользователи на этом nas_ip
	get_disabled_list		# все отключенные пользователи на этом nas
	get_tray_list			# данные о трэй-авторизации на этом насе
	get_sort_user_list		# сортировка всех юзеров и закос под clips
	get_sort_user_list_no_deleted
	get_id_radius_session_list	# список id - acct-session
	get_logged_user_list
	get_sql_nomoney_list		# список негбальщиков из базы
	wait
	get_parsed_nomoney_list
	get_sql_noauth_list
	get_parsed_noauth_list
	get_noauth_no_radius
	get_noauth_no_radius_no_disabled
	get_noauth_no_disabled
}

do_lists() {
	date +${FUNCNAME}_%s
	do_send_disconnect_list
	do_set_negbal_redirect_list
	do_remove_negbal_redirect_list
	do_set_noauth_redirect_list
	do_remove_noauth_redirect_list
}

main() {
	cleanup_tmp
	[[ "$@" = *--no-update* ]] || update_files
	prepare_clips
	get_lists
	do_lists
	make_report && send_report
	cleanup_tmp
}

main $@
