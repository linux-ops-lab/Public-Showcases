# cloudflare_ipset

## Purpose

This script retrieves the current Cloudflare IPv4 and IPv6 network ranges and adds them to firewalld IP sets.

It is intended as a helper for environments where Cloudflare source networks should be maintained in firewalld through `ipset` objects instead of manually managing many individual source entries.

The script does not build firewall rules on its own. It prepares and attaches IP sets so they can be used later by manually defined firewalld logic.

## What the script does

The script performs the following tasks:

1. Downloads the current Cloudflare IP ranges from the official Cloudflare API.
2. Extracts both IPv4 and IPv6 CIDR ranges using `jq`.
3. Prints the retrieved IPv4 and IPv6 ranges to the terminal.
4. Checks whether the firewalld IP sets `cloudflare4` and `cloudflare6` already exist.
5. Creates missing IP sets if the user confirms this interactively.
6. Reloads firewalld after IP set creation.
7. Adds the retrieved IPv4 ranges to `cloudflare4`.
8. Adds the retrieved IPv6 ranges to `cloudflare6`.
9. Optionally attaches both IP sets to an existing firewalld zone.
10. Reloads firewalld again so the changes become active.

## IP sets used by the script

The script works with two firewalld IP sets:

* `cloudflare4` for IPv4 networks
* `cloudflare6` for IPv6 networks

These are created as `hash:net` sets with the appropriate family:

* `inet` for IPv4
* `inet6` for IPv6

## Requirements

The script depends on the following components being available:

* `bash`
* `curl`
* `jq`
* `firewalld`
* `firewall-cmd`

It also requires sufficient privileges to modify the permanent firewalld configuration and reload firewalld.

## Workflow

## 1. Fetch Cloudflare IP ranges

The script queries the Cloudflare API endpoint:

* `https://api.cloudflare.com/client/v4/ips`

It reads:

* `.result.ipv4_cidrs[]`
* `.result.ipv6_cidrs[]`

The returned networks are stored in Bash arrays.

## 2. Display the retrieved networks

Before making any changes, the script prints all retrieved IPv4 and IPv6 CIDRs to the terminal.

This allows the user to see exactly which ranges were returned before they are added to firewalld.

## 3. Check whether the IP sets exist

The script checks whether the permanent firewalld IP sets already exist.

If an IP set is missing, the user is asked whether it should be created.

If the user declines, the script exits.

## 4. Create missing IP sets

If confirmed by the user, the script creates:

* `cloudflare4` as an IPv4 `hash:net` IP set
* `cloudflare6` as an IPv6 `hash:net` IP set

If creation fails, the script aborts with an error.

## 5. Reload firewalld

After creating missing IP sets, the script reloads firewalld.

This is necessary so the newly created objects become available for further operations.

## 6. Add Cloudflare ranges to the IP sets

If the user confirms, the script iterates through all retrieved CIDRs and adds them to the permanent IP sets.

IPv4 networks are added to `cloudflare4`.

IPv6 networks are added to `cloudflare6`.

If an entry cannot be added, the script prints a warning and continues with the next network.

## 7. Optionally attach the IP sets to a zone

The script can optionally add both IP sets as sources to an existing firewalld zone.

If the user chooses this step, the script:

* lists all existing zones
* asks for a zone name
* checks whether `cloudflare4` is already attached
* checks whether `cloudflare6` is already attached
* adds missing attachments to the chosen zone

If the user declines this step, the script exits.

## 8. Reload firewalld again

After the zone changes, the script reloads firewalld a second time so all changes become active.

## Important behavior

## The script is interactive

This is not a non-interactive automation script.

Several steps require user confirmation, including:

* creating missing IP sets
* adding the retrieved entries
* attaching the IP sets to a zone

Because of this, the script is intended for manual administration.

## The script is additive

The script adds entries, but it does not remove old ones.

That means it does not perform a full synchronization in the strict sense. If Cloudflare ever removes a network from its published list, this script will not automatically delete that old entry from the existing IP set.

It is therefore best described as an additive update script, not as a strict reconciliation script.

## Repeated runs may produce warnings

If the script is executed repeatedly, some entries may already exist.

In that case, `firewall-cmd` may report that an entry is already enabled or already present. This is expected behavior for an additive script and does not necessarily mean that anything is broken.

## Zone attachment is optional

Adding the IP sets to a zone is optional.

This step only makes the zone aware of the source IP sets. It does not by itself define what traffic is allowed, denied, or forwarded.

Any actual policy based on these IP sets must still be configured manually.

## What the script does not do

This script does not:

* remove obsolete entries from existing IP sets
* create rich rules, port rules, or forwarding rules
* define allow or deny behavior for specific services
* validate whether a zone configuration makes semantic sense
* verify that the resulting firewall policy behaves as intended
* run automatically on a schedule

## Exit conditions

The script aborts in several cases, for example when:

* an IP set cannot be created
* firewalld cannot be reloaded
* a selected IP set cannot be attached to a zone
* the user declines one of the required interactive steps

Because of this, it should be treated as an admin helper script, not as a resilient unattended provisioning workflow.

## Typical use case

A typical use case is preparing firewalld so that Cloudflare source networks are available as reusable source objects.

An administrator can then manually reference these IP sets in zone logic, rich rules, or other firewalld constructs without maintaining the individual Cloudflare ranges by hand.

## Summary

This script is a manual helper for maintaining Cloudflare IPv4 and IPv6 ranges in firewalld IP sets.

It:

* fetches the current ranges from Cloudflare
* creates missing IPv4 and IPv6 IP sets
* adds the retrieved networks
* optionally attaches the sets to a firewalld zone
* reloads firewalld so the changes take effect

It does not implement the actual firewall policy. The final traffic behavior must still be configured manually.
