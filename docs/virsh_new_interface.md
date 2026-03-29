# Attach libvirt network to VM

This script attaches an existing libvirt network to an existing virtual machine by using `virsh attach-interface`. It is intended as an interactive helper for controlled network changes in KVM/libvirt environments.

## What the script does

The script performs the following steps:

1. Lists all available libvirt networks, bridges, and address ranges.
2. Lists all virtual machines known to libvirt.
3. Prompts for:
   - the target VM
   - the target libvirt network
4. Confirms the selected values with the operator.
5. Optionally validates that:
   - the VM exists
   - the network exists
   - the VM does not already have an interface connected to that network
6. Attaches a new interface of type `network` with model `virtio`.
7. Applies the change to both the live VM and the persistent VM configuration.

## Requirements

- Linux host with KVM/libvirt
- `virsh`
- `awk`
- `grep`
- `sed`
- permissions to modify libvirt guest definitions

## Important behavior

The script uses:

```
--config --live
````

This means the interface is attached:

* to the currently running VM
* and to the persistent VM definition for future boots

So the change is not temporary. It affects both the current runtime state and the saved configuration.

## Safety notes

Before attaching a network interface, verify the following:

* the selected VM is correct
* the selected network is correct
* the network is already defined and available in libvirt
* the VM does not already have an interface in the same network
* the guest operating system is expected to handle the new NIC correctly

Adding an interface at the libvirt level does not automatically configure the guest OS. Network configuration inside the VM may still be required.

## Recommended validation

A good implementation should validate these points before calling `virsh attach-interface`:

* `virsh dominfo <vm>` succeeds
* `virsh net-info <network>` succeeds
* `virsh domiflist <vm>` does not already show the selected network as an attached source

This helps prevent duplicate or unintended interface changes.

## Example use case

Typical use cases include:

* connecting an existing VM to a newly created isolated network
* adding a second NIC for service separation
* attaching a guest to a dedicated application or management network

## Post-change checks

After a successful attach operation, verify the result by checking:

* the VM interface list in libvirt
* the detected network interfaces inside the guest OS
* the guest IP configuration
* connectivity to the expected subnet or gateway

## Related script

This script is typically used after creating a new libvirt network with the companion script:

/docs/virsh_new_network.md
