#!/bin/bash

#Script to add Cloudflare IPs to firewalld's ipset

ipset4="cloudflare4"
ipset6="cloudflare6"

clear

mapfile -t ipv4_cidrs < <(
  curl -fsS https://api.cloudflare.com/client/v4/ips | jq -r '.result.ipv4_cidrs[]'
)

mapfile -t ipv6_cidrs < <(
  curl -fsS https://api.cloudflare.com/client/v4/ips | jq -r '.result.ipv6_cidrs[]'
)

echo "__________________________________________"
echo "Listing Cloudflare IPv4s:"
echo "__________________________________________"
echo

printf 'IPv4:\n'
printf '  %s\n' "${ipv4_cidrs[@]}"

echo ""
echo "__________________________________________"
echo "Listing Cloudflare IPv6s:"
echo "__________________________________________"
echo

printf 'IPv6:\n'
printf '  %s\n' "${ipv6_cidrs[@]}"

echo ""

echo "__________________________________________"
echo "Checking if $ipset4 and $ipset6 already existing:"
echo "__________________________________________"
echo ""

if ! firewall-cmd --permanent --info-ipset="$ipset4"; then
        echo ""
        read -p "Ipset $ipset4 does not exist. Do you want to create it? (y/n) " create
                if [ "$create" == "y" ]; then
                        if ! firewall-cmd --permanent --new-ipset="$ipset4" --type=hash:net --family=inet; then
                                echo "Could not create ipset $ipset4. Abort script!"
                                exit 1;
                        else
                                echo "Ipset $ipset4 created successfully!"
                        fi

                else 
                        echo "Script terminated by user input."
                        exit 2;
                fi

else 
        echo ""
        echo "$ipset4 already there."
fi

echo ""

if ! firewall-cmd --permanent --info-ipset="$ipset6"; then
        echo ""
        read -p "Ipset $ipset6 does not exist. Do you want to create it? (y/n) " create
                if [ "$create" == "y" ]; then
                        if ! firewall-cmd --permanent --new-ipset="$ipset6" --type=hash:net --family=inet6; then
                                echo "Could not create ipset $ipset6. Abort script!"
                                exit 1;
                        else
                                echo "Ipset $ipset6 created successfully!"
                        fi

                else 
                        echo "Script terminated by user input."
                        exit 2;
                fi

else
        echo ""
        echo "$ipset6 already there."
fi

echo ""

echo "Reloading firewalld."
if ! firewall-cmd --reload; then
        echo "Could not reload firewall. Exit script."
        exit 3;
fi

echo ""
read -p "Add the IP addresses listed above to the ipset $ipset4 and $ipset6 ? (y/n) " answer
echo ""


if [ "$answer" == "y" ]; then
        for net in "${ipv4_cidrs[@]}"; do
                if ! firewall-cmd --permanent --ipset="$ipset4" --add-entry="$net"; then
                        echo "Could not add $net to IPv4 ipset."
                else
                        echo "$net added to IPv4 ipset."
                fi
        done
fi

if [ "$answer" == "y" ]; then
        for net in "${ipv6_cidrs[@]}"; do
                if ! firewall-cmd --permanent --ipset="$ipset6" --add-entry="$net"; then
                        echo "Could not add $net to IPv6 ipset."
                else
                        echo "$net added to IPv6 ipset."
                fi
        done
fi

echo ""

echo "__________________________________________"
read -p "Do you want to add new ipsets to existing zones (y/n): " answer2
echo "__________________________________________"
echo ""

if [ "$answer2" == "y" ]; then
        echo ""
        echo "Listing existing zones:"
        echo ""
        firewall-cmd --get-zones
        echo ""
        read -p "Choose zone: " zone
        echo ""
        
        if firewall-cmd --zone="$zone" --query-source=ipset:"$ipset4"; then
                echo "$ipset4 already part of $zone. Skipping."
                echo ""
        else
                echo "Adding ipset $ipset4 to $zone ..."
        
                if ! firewall-cmd --permanent --zone="$zone" --add-source=ipset:"$ipset4"; then
                        echo "Could not add $ipset4 to $zone!"
                        exit 4;
                else echo "$ipset4 added to $zone successfully."
                fi
        fi

        if firewall-cmd --zone="$zone" --query-source=ipset:"$ipset6"; then
                echo "$ipset6 already part of $zone. Skipping."
                echo ""
        else
                echo "Adding ipset $ipset6 to $zone ..."

                if ! firewall-cmd --permanent --zone="$zone" --add-source=ipset:"$ipset6"; then
                        echo "Could not add $ipset6 to $zone!"
                        exit 4;
                else echo "$ipset6 added to $zone successfully."
                fi
        fi

else 
        echo "Script terminated by user input."
        exit 2;
fi

echo "Reloading firewalld."
if ! firewall-cmd --reload; then
        echo "Could not reload firewall. Exit script."
        exit 3;
fi

echo ""
echo "__________________________________________"
echo "Done! To make the ipsets effective — for example, to allow or block traffic — this must still be configured manually."
echo "__________________________________________"
echo ""
