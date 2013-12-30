#!/usr/local/bin/expect -f
#stty echo
match_max -d 10000
# for debug - begin ##
log_user 0
# for debug - end ##

# Забираем файлы по scp, файлы складываются в каталог  /var/lib/event/files2/
# Файл clips_up.txt - поднятые клипсы.
# Файл clips_detail.txt - детальная информация по сессиям.

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
	expect "*#" {send "sho clips up | save clips_up.txt\r"}
	puts "Файл с поднятыми сессиями создан, OK"
	expect "*#" {send "sho subscribers active all | save clips_detail.txt\r"}
	puts "Файл с поднятыми сессиями  и подробным описание создан, OK"
	expect "*#" {send "exit\r"}
}

spawn scp $user@$switch_ip:clips_detail.txt $path/clips_detail.txt

expect timeout {
	send_user "$switch_ip failed scp file clips_detail.txt to connect switch\n"
	continue
} "ssh: connect to host $switch_ip port 22: No route to host" {
	exit 2
} "*password:" {
	send "$pass\r"
	expect "*password:" {send "$pass\r"}
}

spawn scp $user@$switch_ip:clips_up.txt $path/clips_up.txt

expect timeout {
	send_user "$switch_ip failed scp file clips_up.txt to connect switch\n"
	continue
} "ssh: connect to host $switch_ip port 22: No route to host" {
	exit 2
} "*password:" {
	send "$pass\r"
	expect "*password:" {send "$pass\r"}
}

exit 0

#expect eof
