# JonKoiOS

My NixOS + Home Manager flake for a single AMD desktop running Hyprland. It started from
[ZaneyOS](https://gitlab.com/Zaney/zaneyos) and has since been reorganized around my own setup.

## Layout

```
flake.nix                 inputs, overlays, the `default` host
hosts/default/            this machine: hardware, boot, users, host variables
  config.nix              NixOS entry point (imports modules/system)
  home.nix                Home Manager entry point (imports modules/home)
  variables.nix           git identity, monitors, browser/terminal, clock
modules/system/           NixOS modules, each folder pulled in by its default.nix
  core.nix                locale, nix settings, CLI tools, sudo/polkit basics
  desktop.nix             Hyprland, portals, Thunar, desktop apps
  dev.nix                 toolchains, Prisma engines
  apps.nix                GUI applications
  aliases.nix             bash aliases
  discipline/             nightly shutdown, stand reminders, rebuild guard
  drivers/ hardware/ virtualization/ gaming/ styling/
modules/home/             Home Manager modules: Hyprland, Waybar, Rofi, theme, shell, files
pkgs/                     small scripts packaged with writeShellScriptBin
overlays/                 package overlays
shells/                   nix-shell environments (pythonShell, pythonAIShell, ...)
```

## Rebuilding

```
build-os      # nixos-rebuild switch --flake ~/jon-koi-os#default, through the rebuild guard
upgrade-os    # nix flake update
```

New files must be tracked by git (`git add`) before a flake rebuild can see them.

## Discipline

`modules/system/discipline/` enforces a nightly shutdown (22:30 Sun–Wed, 00:00 Thu–Sat) and
standing breaks. The units refuse manual stops, polkit and sudo block disabling them, and
`nixos-rebuild` is shadowed by a guard that refuses to rebuild inside the shutdown window.
`discipline-window-check --status` shows where you are. The oneshot services are marked
`restartIfChanged = false` so a rebuild never triggers them.

`steam-blocker.nix` is kept there but not imported.
