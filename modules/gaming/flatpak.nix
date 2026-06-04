{
config,
pkgs,
...
}:

let
  # We point directly to 'gnugrep' instead of 'grep'
  grep = pkgs.gnugrep;

  # 1. Declare the Flatpaks you *want* on your system
  desiredFlatpaks = [
    "com.valvesoftware.Steam"
    "com.github.tchx84.Flatseal"
    "org.kde.isoimagewriter"
    "com.heroicgameslauncher.hgl"
    "io.github.limo_app.limo"
    "com.github.Matoking.protontricks"
    "org.kde.kdenlive"
  ];

  # Flatpak distributed as a GitHub release bundle, not on Flathub
  amethystId = "io.github.Amethyst.ModManager";
  amethystUrl = "https://github.com/ChrisDKN/Amethyst-Mod-Manager/releases/download/v1.3.6/AmethystModManager.flatpak";

  # Apps the cleanup sweep must NOT remove (Flathub apps + the bundle app)
  protectedFlatpaks = desiredFlatpaks ++ [ amethystId ];
in {
  services = {
      flatpak.enable = true;
  };
  environment.systemPackages = [ pkgs.flatpak-builder ];
  systemd.services.flatpak-repo = {
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
  system.activationScripts.flatpakManagement = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo

      installedFlatpaks=$(${pkgs.flatpak}/bin/flatpak list --app --columns=application)

      # Remove anything not in the protected list
      for installed in $installedFlatpaks; do
        if ! echo ${toString protectedFlatpaks} | ${grep}/bin/grep -q $installed; then
          echo "Removing $installed because it's not in the protected list."
          ${pkgs.flatpak}/bin/flatpak uninstall -y --noninteractive $installed
        fi
      done

      # Install the Flathub apps
      for app in ${toString desiredFlatpaks}; do
        echo "Ensuring $app is installed."
        ${pkgs.flatpak}/bin/flatpak install -y flathub $app
      done

      # Install Amethyst from its GitHub release bundle, only if missing
      if ! ${pkgs.flatpak}/bin/flatpak info ${amethystId} >/dev/null 2>&1; then
        echo "Installing Amethyst Mod Manager from release bundle."
        ${pkgs.curl}/bin/curl -L -o /tmp/amethyst.flatpak "${amethystUrl}"
        ${pkgs.flatpak}/bin/flatpak install -y --bundle /tmp/amethyst.flatpak
        rm -f /tmp/amethyst.flatpak
      fi

      # Grant Amethyst access to the game library and Steam's flatpak data
      ${pkgs.flatpak}/bin/flatpak override ${amethystId} \
        --filesystem=/mnt/game_disc \
        --filesystem=/home/jonkoi/.var/app/com.valvesoftware.Steam

      ${pkgs.flatpak}/bin/flatpak update -y
    '';
  };
}
