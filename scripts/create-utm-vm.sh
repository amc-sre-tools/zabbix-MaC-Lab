#!/bin/bash

# =============================================================================
# UTM VM Creation Script for Zabbix Testing Environment
# =============================================================================
# Author: Andrés M. Correa
# Email: korc.dev@gmail.com
# Description: Creates a Ubuntu 24.04 VM in UTM with cloud-init configuration
# Usage: ./create-utm-vm.sh
# =============================================================================

set -e

VM_NAME="zabbix-testing"
VM_DIR="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/$VM_NAME.utm"
UBUNTU_VERSION="24.04"
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img"
UBUNTU_IMAGE_FILE="ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img"
DISK_SIZE_GB=70
RAM_MB=8192
CPU_CORES=4

SSH_USER="sre-ubuntu"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7S09tP3e9XvH+w4MzIgahc6aUt9SFjOppddh1/MZzc korc.dev@gmail.com"

echo "=== UTM VM Creation Script for Zabbix Testing ==="

check_utm() {
    if ! command -v utmctl &> /dev/null && [ ! -d "/Applications/UTM.app" ]; then
        echo "Error: UTM is not installed"
        exit 1
    fi
    echo "[OK] UTM installed"
}

download_ubuntu_image() {
    if [ ! -f "$UBUNTU_IMAGE_FILE" ]; then
        echo "Downloading Ubuntu ${UBUNTU_VERSION} cloud image..."
        curl -L -o "$UBUNTU_IMAGE_FILE" "$UBUNTU_IMAGE_URL"
    else
        echo "[OK] Ubuntu image already exists"
    fi
}

create_cloud_init_config() {
    local ci_dir="cloud-init"
    mkdir -p "$ci_dir"
    
    cat > "$ci_dir/user-data" << EOF
#cloud-config
hostname: zabbix-testing
manage_etc_hosts: true

users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh-authorized-keys:
      - ${SSH_KEY}
    shell: /bin/bash

package_update: true
package_upgrade: true

packages:
  - qemu-guest-agent
  - cloud-init
  - net-tools
  - curl
  - wget
  - git
  - ansible
  - lvm2
  - podman

runcmd:
  - echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
  - systemctl enable qemu-guest-agent
EOF

    cat > "$ci_dir/meta-data" << EOF
instance-id: zabbix-testing-vm
local-hostname: zabbix-testing
EOF

    echo "[OK] Cloud-init config created"
}

generate_utm_config() {
    local vm_display_name="$VM_NAME"
    local vm_uuid=$(uuidgen)
    local disk_uuid=$(uuidgen)
    
    mkdir -p "$VM_DIR/Data"
    
    cat > "$VM_DIR/config.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>DisplayConfiguration</key>
    <dict>
        <key>ConsoleMode</key>
        <string>text</string>
        <key>DisplayType</key>
        <string>none</string>
    </dict>
    <key>Information</key>
    <dict>
        <key>CPUCount</key>
        <integer>${CPU_CORES}</integer>
        <key>DisplayName</key>
        <string>${vm_display_name}</string>
        <key>IconPath</key>
        <string>VmDriveTemplate</string>
        <key>Memory</key>
        <integer>${RAM_MB}</integer>
        <key>Name</key>
        <string>${VM_NAME}</string>
        <key>UUID</key>
        <string>${vm_uuid}</string>
    </dict>
    <key>Network</key>
    <dict>
        <key>Count</key>
        <integer>1</integer>
        <key>Devices</key>
        <array>
            <dict>
                <key>Card</key>
                <string>virtio-net-pci</string>
                <key>Mode</key>
                <string>network</string>
                <key>Type</key>
                <string>network</string>
            </dict>
        </array>
    </dict>
    <key>RemovableDisks</key>
    <array>
        <dict>
            <key>DeviceType</key>
            <string>CD</string>
            <key>ImagePath</key>
            <string></string>
            <key>IsExternal</key>
            <true/>
            <key>Name</key>
            <string>CD</string>
            <key>UUID</key>
            <string>$(uuidgen)</string>
        </dict>
    </array>
    <key>State</key>
    <dict>
        <key>CurrentBootDiskUUID</key>
        <string>${disk_uuid}</string>
    </dict>
    <key>Storage</key>
    <dict>
        <key>Disks</key>
        <array>
            <dict>
                <key>DeviceType</key>
                <string>IDE</string>
                <key>Harddisk</key>
                <dict>
                    <key>AttachmentType</key>
                    <string>disk</string>
                    <key>ImagePath</key>
                    <string>Data/$(basename "$UBUNTU_IMAGE_FILE")</string>
                    <key>Interface</key>
                    <string>ide</string>
                    <key>UUID</key>
                    <string>${disk_uuid}</string>
                </dict>
                <key>Name</key>
                <string>Main</string>
                <key>Slot</key>
                <integer>0</integer>
            </dict>
        </array>
    </dict>
    <key>System</key>
    <dict>
        <key>Boot</key>
        <dict>
            <key>Kernel</key>
            <string></string>
            <key>KernelCommandLine</key>
            <string>console=hvc0</string>
            <key>LinuxCommandLine</key>
            <string>console=hvc0 root=/dev/sda1 ro</string>
            <key>OperatingSystem</key>
            <string>Linux</string>
        </dict>
    </dict>
</dict>
</plist>
EOF

    echo "[OK] UTM config.plist created"
}

create_vm() {
    echo "Creating VM bundle..."
    mkdir -p "$VM_DIR/Data"
    
    cp "$UBUNTU_IMAGE_FILE" "$VM_DIR/Data/"
    
    echo "Importing VM into UTM..."
    open "$VM_DIR"
    
    echo "[OK] VM created: $VM_NAME"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Open UTM and configure the VM:"
    echo "   - Add network card (NAT or bridge)"
    echo "   - Add cloud-init ISO (use the generated config)"
    echo "   - Start the VM"
    echo ""
    echo "2. Wait for cloud-init to complete (~5 minutes)"
    echo ""
    echo "3. Find VM IP and update ansible/inventory.ini"
    echo "   grep -r 'cloud-init' /var/log/ | tail -20"
    echo ""
    echo "4. Run Ansible provisioning:"
    echo "   cd ansible && ansible-playbook -i inventory.ini prepare-vm.yml"
}

main() {
    check_utm
    download_ubuntu_image
    create_cloud_init_config
    generate_utm_config
    create_vm
}

main "$@"
