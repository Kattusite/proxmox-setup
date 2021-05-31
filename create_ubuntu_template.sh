#!/bin/bash -ex
#
# Create an Ubuntu cloud-init template for use with Proxmox.
#
# Source:
#    https://pve.proxmox.com/wiki/Cloud-Init_Support
#    https://norocketscience.at/deploy-proxmox-virtual-machines-using-cloud-init/

VMID=${1:-1804}
BUILD=${2:-focal}
ISO_STORAGE=${3:-proxmox-iso}
VM_STORAGE=${4:-vm-storage}

if [[ -z "$1" ]] ; then
    echo "Usage: $0 <vmid> <focal,bionic,...> (<iso_storage> <vm_storage>)"
    exit
fi

IMG="${BUILD}-server-cloudimg-amd64"

echo "Creating VM ID $VMID with Ubuntu build $BUILD"

# Download the image on your Proxmox server (I'm using Ubuntu for my VMs)
wget https://cloud-images.ubuntu.com/${BUILD}/current/${IMG}.img

# Define your virtual machine which you're like to use as a template
qm create $VMID --name "ubuntu-${VMID}-cloudinit-template" --memory 2048 --net0 virtio,bridge=vmbr0

# (Important for Ubuntu!) Rename your image suffix
mv ${IMG}.img ${IMG}.qcow2

# Import the disk image in the local Proxmox storage
qm importdisk $VMID ${IMG}.qcow2 $VM_STORAGE

# Clean up old disk image.
rm ${IMG}.qcow2

# Configure your virtual machine to use the uploaded image
qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${VM_STORAGE}:vm-${VMID}-disk-0

# Adding the Cloud-init image as CD-Rom to your virtual machine
qm set $VMID --ide2 $VM_STORAGE:cloudinit

# Restrict the virtual machine to boot from the Cloud-init image only
qm set $VMID --boot c --bootdisk scsi0

# Attach a serial console to the virtual machine (this is needed for some Cloud-Init distributions, such as Ubuntu)
qm set $VMID --serial0 socket --vga serial0

# Finally create a template
qm template $VMID

set +ex

# Create a virtual machine out of the template
echo
echo 'To create a VM from this template, run:'
echo ' $ qm clone $VMID <vm-id> --name <vm-name>'
echo
echo 'Configure cloud-init settings via proxmox web UI, or `qm set`'
echo
