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

  # Oracle Cloud ARM boots via UEFI. The EFI system partition is only 98MB,
  # too small for systemd-boot which stores kernels on the ESP. Using GRUB
  # instead so kernels live on the root filesystem.
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-label/UEFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  boot.loader = {
    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      configurationLimit = 10;
    };
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
      enable = true;
      stateDir = "/srv/restic-backup";
      paths = [
        "/srv/edge-cluster/rustdesk"
        "/var/lib/rancher/k3s/server/token"
      ];
      repositorySecret = "restic/borgbase_repo";
      passwordSecret = "restic/borgbase_password";
      environmentSecret = null;
    };
  };
}
