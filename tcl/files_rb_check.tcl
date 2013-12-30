#!/usr/local/bin/expect -f
#stty echo
match_max -d 10000
# for debug - begin ##
log_user 0
# for debug - end ##

# �������� ����� �� scp, ����� ������������ � �������  /var/lib/event/files/
# ���� clips_up.txt - �������� ������.
# ���� clips_all.txt ��� ��������� ������ �� redback'e, ���������� ������ id ������������.
# ���� clips_detail.txt - ��������� ���������� �� �������.

set timeout 240
set switch_ip "10.0.0.1"
set user "username"
set pass "password"
set context "nondhcpclips"
set path "/var/lib/event/redback_sync/var/files/"

spawn telnet -K $switch_ip

expect timeout {
	send_user "$switch_ip failed to connect switch\n"
	continue
} "telnet: connect to address $switch_ip No route to host" {
	exit 2
} "Redback" {
	expect "login:" { send "$user\r"}
	expect "Password:" {send "$pass\r"}

	expect "*#" {send "context $context\r"}
	expect "*#" {send "dir clips_*\r"}
	expect "*#" {send "\r"}
	set results $expect_out(buffer)
	puts $results

	expect "*#" {send "end\r"}
	expect "*#" {send "exit\r"}
}

exit 0
