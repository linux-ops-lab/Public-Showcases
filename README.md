Public Showcases

A curated collection of small Bash utilities for Linux system administration and virtualization environments.

This repository contains sanitized, public-safe showcase scripts derived from practical administration tasks. The focus is on readability, operational usefulness, and safe publication, without exposing private infrastructure details.

Purpose

The goal of this repository is to demonstrate hands-on scripting in areas such as:

Linux process and memory analysis
disk health monitoring
libvirt network inspection
virtual network firewall handling

These scripts are intentionally small and focused. They are meant to solve concrete operational problems with as little overhead as possible.

Included Scripts
ram_monitor.sh

Shows the top memory-consuming processes on a Linux system, sorted by RSS, and adds small contextual hints for selected process types such as QEMU guests or PHP-FPM pools.

hdd_temp_monitoring.sh

Checks disk temperatures via smartctl, writes the results to a log file, and can send a warning email if a configurable threshold is exceeded.

virsh_net.sh

Prints an overview of all libvirt networks including network name, bridge name, IP address, and netmask.

libvirt-inter-vnet.sh

Ensures that traffic between libvirt virtual bridge interfaces is permitted by inserting missing iptables rules into the relevant libvirt chains.

Requirements

Depending on the script, the following tools may be required:

bash
ps
awk
lsblk
smartctl
mail
virsh
iptables

The scripts are intended for Linux systems and assume that the required tools are already installed and available in PATH.

Usage

Make the scripts executable first:

chmod +x *.sh

Run examples:

./ram_monitor.sh
./ram_monitor.sh 30

./hdd_temp_monitoring.sh

./virsh_net.sh

sudo ./libvirt-inter-vnet.sh

Notes on Safety

These scripts are published in a generalized form. They do not contain private hostnames, internal domains, real storage layouts, or environment-specific identifiers.

Still, some of them interact with system-level components such as:

process tables
SMART disk data
libvirt virtual networks
firewall rules

Review every script before using it in production and adapt it to your environment where necessary.

Design Principles

This repository follows a few simple principles:

keep scripts short and focused
prefer clarity over cleverness
make operational intent easy to understand
avoid hidden infrastructure-specific assumptions in the public version
Audience

This repository is intended for:

Linux administrators
home lab operators
virtualization enthusiasts
recruiters or technical reviewers who want a quick view of practical scripting work
Additional Private Repositories

Beyond the public showcase scripts in this repository, I maintain several additional production-focused private repositories that reflect real-world operational work and infrastructure automation.

These repositories are intentionally not public because they include environment-specific implementation details, internal structures, and operational context that are not suitable for open publication.

If relevant, these private repositories can be reviewed together on request in an appropriate professional setting, such as a technical interview or portfolio discussion.

Disclaimer

These scripts are provided as examples and learning material. Test them in a safe environment before using them on productive systems.

License

You can add a license of your choice here, for example:

MIT License
Apache 2.0
GPLv3

If no license is added, the default legal situation is that others may view the code but not freely reuse it.
