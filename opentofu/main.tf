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
  depends_on = [
    proxmox_cloud_init_disk.ci,
  ]

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
  ciuser = "ansible"
  ipconfig0 = ""

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
      scsi2 {
        disk {
          type    = "scsi"
          media   = "cdrom"
          storage = var.iso_storage_pool
          volume  = proxmox_cloud_init_disk.ci.id
          size    = proxmox_cloud_init_disk.ci.size
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
}
resource "proxmox_cloud_init_disk" "ci" {
  count = var.node_count

  name      = "k3s-${count.index}"
  pve_node  = var.proxmox_host
  storage   = var.iso_storage_pool


  meta_data = yamlencode({
    instance_id    = sha1("k3s-${count.index}")
    local-hostname = "k3s-${count.index}"
  })

  user_data = <<EOT
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
EOT

  network_config = yamlencode({
    version = 1
    config = [{
      type = "physical"
      name = "eth0"
      subnets = [{
        type            = "static"
        address         = "192.168.1.13${count.index}/24"
        gateway         = "192.168.1.1"
        dns_nameservers = ["192.168.1.100"]
      }]
    }]
  })
}
