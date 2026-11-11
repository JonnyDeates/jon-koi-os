{ pkgs }:

# Opens the lot-map Claude Code plugin's map in its own window (the plugin's
# terminal pane can only draw text). Needs the linux-window fork of lot-map,
# which writes the map to $XDG_RUNTIME_DIR/lot-map/map.svg.
pkgs.writeShellScriptBin "lot-map-window" ''
  exec ${pkgs.python3}/bin/python3 ${./lot-map-window.py} "$@"
''
