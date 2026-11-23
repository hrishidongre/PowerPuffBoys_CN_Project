#!/bin/bash
# Prints the line to paste into the group chat so hosts.env can be filled in.
set -e
iface=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
ip=$(ipconfig getifaddr "$iface")
echo "host     : $(scutil --get LocalHostName)"
echo "interface: $iface"
echo "ip       : $ip"
echo "mac      : $(ifconfig "$iface" | awk '/ether/{print $2}')"
echo "gateway  : $(route get default | awk '/gateway:/{print $2}')"
echo
echo "Paste this line in the group chat:"
echo "  <YOUR_ROLE>_IP=$ip"
