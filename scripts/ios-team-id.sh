#!/bin/sh
# Prints the Team IDs of the Apple Development certificates in the login keychain.
# Create one in Xcode > Settings > Accounts > Manage Certificates > + > Apple Development.
pems=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null)
if [ -z "$pems" ]; then
  echo "No Apple Development certificate found. Create one in Xcode > Settings > Accounts > Manage Certificates." >&2
  exit 1
fi
echo "$pems" | awk '/BEGIN CERT/{c=""} {c=c $0 "\n"} /END CERT/{printf "%s", c | "openssl x509 -noout -subject"; close("openssl x509 -noout -subject")}' \
  | sed -nE 's/.*CN ?= ?([^,/]+).*OU ?= ?([A-Z0-9]{10}).*/\2  \1/p; s/.*OU ?= ?([A-Z0-9]{10}).*CN ?= ?([^,/]+).*/\1  \2/p' | sort -u
