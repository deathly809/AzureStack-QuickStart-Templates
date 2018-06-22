#!/bin/bash
cd /var/lib/waagent
mkdir certdir -f
for CERT in `grep -l Bag *.crt `;
do
    cp $CERT certdir
done
#
# Linux
#
# "/usr/lib/ssl/certs.pem",                            // Heuristic
# "/etc/ssl/certs/ca-certificates.crt",                // Debian/Ubuntu/Gentoo etc.
# "/etc/pki/tls/certs/ca-bundle.crt",                  // Fedora/RHEL 6
# "/etc/ssl/ca-bundle.pem",                            // OpenSUSE
# "/etc/pki/tls/cacert.pem",                           // OpenELEC
# "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", // CentOS/RHEL 7
#
# Unix (Not supported)
#
# "/etc/ssl/certs",               // SLES10/SLES11, https://golang.org/issue/12139
# "/system/etc/security/cacerts", // Android
# "/usr/local/share/certs",       // FreeBSD
# "/etc/pki/tls/certs",           // Fedora/RHEL
# "/etc/openssl/certs",           // NetBSD
#
for F in *.crt; do openssl x509 -in $F -out "${F%.*}".pem -outform PEM; done
cat *.pem > temporary.crt
function install {
    FROM=$0;TO=$1;shift;shift;FUNCTION="$@"
    if [ -f "$TO " ]; then
        cat $FROM >> $TO
        $FUNCTION
    fi
}
# Hacky
touch '/usr/lib/ssl/certs.pem'
install certdir/temporary.crt '/usr/lib/ssl/certs.pem'
# Known locations
install certdir/temporary.crt "/etc/ssl/certs/ca-certificates.crt" update-ca-certificates
install certdir/temporary.crt "/etc/pki/tls/certs/ca-bundle.crt"
install certdir/temporary.crt "/etc/ssl/ca-bundle.pem"
install certdir/temporary.crt "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem" update-ca-trust extract
