{ pkgs }:

pkgs.writeShellScriptBin "gammastart" ''
  sleep 0.1
  gammastep -c ~/.config/gammastep/config.ini
''
