#!/bin/bash

nas_ip=10.0.0.1
telnet_ip=10.0.0.1
coa_port=3799
nas_pass=password

EXPECT=/usr/local/bin/expect
EVENTDIR=/var/lib/event/
ROOTDIR=$EVENTDIR/redback_sync/
POOLDIR=$ROOTDIR/var/
SPOOLDIR=$POOLDIR/
FILESDIR=$POOLDIR/files/
BINDIR=$ROOTDIR/bin/
TCLDIR=$ROOTDIR/tcl/
CLIPSALL=$FILESDIR/clips_all.txt
CLIPSDETAIL=$FILESDIR/clips_detail.txt
CLIPSUP=$FILESDIR/clips_up.txt

PREFIX=/tmp/$(basename $0)
SQLUSERLIST=${PREFIX}.$$
TMPUSERLIST=${PREFIX}_tmp.$$
CLIPSALLSORT=${PREFIX}_clips_all_sort.txt.$$
ALLIDLIST=${PREFIX}_all.$$
ALLUSERSLIST=${POOLDIR}/all_users_row_id_ip
ID_ACCT_SESSION_LIST=${POOLDIR}/id_acct_session
EXISTINGIDLIST=${PREFIX}_exist.$$
ADD_REDBACK=${PREFIX}_add.$$
DEL_REDBACK=${PREFIX}_del.$$
CLIPSUPSORT=${PREFIX}_clips_up_sort.txt.$$
UPIDLIST=${PREFIX}_up.$$
NEED_CONNECT=${PREFIX}_need_connect.$$
NEED_DISCONNECT=${PREFIX}_need_disconnect.$$
NEED_DISCONNECT_WITHOUT_NEGBAL=${PREFIX}_need_disconnect_without_negbal.$$
CLIPS_NEGBAL=${PREFIX}_clips_negbal.txt.$$
NEGBAL_LIST=${PREFIX}_negbal.$$
DISABLED_USERS_LIST=${PREFIX}_disabled.$$
ADD_NEGBAL=${PREFIX}_negbal_add.$$
DEL_NEGBAL=${PREFIX}_negbal_del.$$
SQL_TRAY_CACHE=${PREFIX}_sql_tray_cache.$$
TRAY_CACHE=${PREFIX}_tray_cache.$$
CLIPS_NOAUTH_LIST=${PREFIX}_clips_noauth.txt.$$
SQL_NOAUTH_LIST=${PREFIX}_sql_noauth.txt.$$
SQL_AUTH_LIST=${PREFIX}_sql_auth.txt.$$
ADD_NOAUTH=${PREFIX}_noauth_add.$$
DEL_NOAUTH=${PREFIX}_noauth_del.$$
REPORT_FILE=${PREFIX}_report.$$
RADIUS_USERS_LIST=${PREFIX}_radius_users.$$
CLIPS_NOAUTH_LIST_NORADIUS=${PREFIX}_clips_noauth_noradius.txt.$$
CLIPS_NOAUTH_LIST_NORADIUS_NODISABLED=${PREFIX}_clips_noauth_noradius_nodisabled.$$
CLIPS_NOAUTH_LIST_NODISABLED=${PREFIX}_clips_noauth_nodisabled.$$
RECONNECT_SNMP=$BINDIR/reconnect_snmp_nondhcpclips.sh

CMD_DIR_LIST="deluser adduser send_disconnect send_connect remove_noauth_redirect remove_negbal_redirect set_noauth_redirect set_negbal_redirect files"

NEGBAL_POLICY='Forward-Policy="in:HTTP-REDIRECT",HTTP-Redirect-URL="http://10.0.0.100/nomoney"'
NOAUTH_POLICY='Forward-Policy="in:",Forward-Policy="in:HTTP-REDIRECT",HTTP-Redirect-URL="http://10.0.0.100/noauth"'
REMOVE_POLICY='Forward-Policy="in:"'

ip2id() {
	grep -w "$ip" "$ALLUSERSLIST" | awk '{print $2}'
}
