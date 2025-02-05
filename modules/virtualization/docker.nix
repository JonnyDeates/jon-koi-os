{
pkgs,
...
} : {
programs={
    # Allows for docker images, and virtualization of containers
    virt-manager.enable = true;
};
  environment.systemPackages =
    with pkgs; [

        # A toolkit to manage virtualization platforms; it provides APIs to interact with virtual machines, containers, and more.
        libvirt
        # A lightweight application for accessing the graphical console of virtual machines managed by libvirt.
        virt-viewer
        # A tool that lets you run containerized Linux distributions in a user‑space environment, isolating them from your host.
        distrobox

        docker-compose
    ];

      # Virtualization / Containers
      virtualisation.docker.enable = true;
      virtualisation.libvirtd.enable = true;
      virtualisation.podman = {
        enable = true;
        #    dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
}