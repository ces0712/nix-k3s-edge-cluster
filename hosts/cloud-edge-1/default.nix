{modulesPath, ...}: {
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  networking.hostName = "cloud-edge-1";

  # Oracle cloud images keep the root filesystem on the original cloud image
  # root partition label after nixos-infect.
  fileSystems."/" = {
    device = "/dev/disk/by-label/cloudimg-rootfs";
    fsType = "ext4";
  };

  # Oracle Cloud ARM boots via UEFI. Keep the EFI system partition mounted and
  # let systemd-boot manage boot entries there.
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-label/UEFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot/efi";
  };
  boot.kernelParams = ["net.ifnames=0"];

  system.stateVersion = "25.11";

  edgeCluster = {
    bootstrap = {
      enable = false;
      permitRootLogin = false;
    };

    stateDir = "/srv/edge-cluster";

    apps.rustdesk = {
      enable = true;
      serverHost = "cloud-edge-1";
      dataDir = "/srv/edge-cluster/rustdesk";
      enableWebClient = false;
    };

    backup = {
      enable = false;
      paths = [
        "/srv/edge-cluster/rustdesk"
        "/var/lib/rancher/k3s/server"
      ];
    };
  };
}
