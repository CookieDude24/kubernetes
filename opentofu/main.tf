terraform {
  required_providers {
    proxmox = {
      source = "registry.terraform.io/Telmate/proxmox"
      #latest version as of Nov 30 2022
      version = "3.0.1-rc1"
    }
  }
}

provider "proxmox" {
  # References our vars.tf file to plug in the api_url
  pm_api_url = var.api_url
  # References our secrets.tfvars file to plug in our token_id
  pm_api_token_id = var.token_id
  # References our secrets.tfvars to plug in our token_secret
  pm_api_token_secret = var.token_secret
  # Default to `true` unless you have TLS working within your pve setup
  pm_tls_insecure = true
}

# Creates a proxmox_vm_qemu entity named blog_demo_test
resource "proxmox_vm_qemu" "k3s-node" {
  count = var.node_count
  name = "k3s-${count.index}"
  target_node = var.proxmox_host

  # References our vars.tf file to plug in our template name
  clone = var.template_name
  # Creates a full clone, rather than linked clone
  # https://pve.proxmox.com/wiki/VM_Templates_and_Clones
  full_clone  = "true"

  # VM Settings. `agent = 1` enables qemu-guest-agent
  agent = 1
  os_type = "cloud-init"
  cores = 4
  sockets = 1
  cpu = "host"
  memory = 6144
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  bios = "ovmf"
  onboot = true
  searchdomain = "home.007337.xyz"

  disks {
    scsi {
      scsi0 {
        disk {
          size    = 32
          storage = "disk-images" # Name of storage local to the host you are spinning the VM up on
          emulatessd = true
        }
      }
      scsi1 {
        disk {
          size    = 32
          storage = "disk-images" # Name of storage local to the host you are spinning the VM up on
          emulatessd = true
        }
      }
    }
  }

  network {
    model = "virtio"
    bridge = var.nic_name
  }


  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  cicustom = <<EOT
#cloud-config
hostname: ${var.vm_name}-${count.index}
manage_etc_hosts: true
users:
  - name: maxid
    gecos: Maximilian Dorninger
    ssh_import_id:
      - gh: CookieDude24
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
  - name: ansible
    gecos: Ansible User
    ssh_import_id:
      - gh: CookieDude24
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
package_upgrade: true
package_reboot_if_required: true
locale: de_AT.UTF-8
timezone: Europe/Vienna
runcmd:
  - systemctl reload ssh
packages:
  - qemu-guest-agent
  - wget
  - nano
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.20${count.index}/24
      gateway4: 192.168.1.1
      nameserver:
        search: [home.007337.xyz]
        addresses: [192.168.1.100]
EOT
}
