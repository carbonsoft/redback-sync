#!/bin/bash

bras_ip="$1"
ip="$2"
id="$3"
context="$4"
community="$5"
rbnSubsBounceName=".1.3.6.1.4.1.2352.2.27.1.1.3.3.0"
rbnSubsClearSubscriberName=".1.3.6.1.4.1.2352.2.27.1.1.3.1.0"

/usr/bin/snmpset -v2c -c $community@$context $bras_ip $rbnSubsClearSubscriberName s $ip
