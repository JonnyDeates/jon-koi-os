{pkgs}:
pkgs.writeShellScriptBin "aiRenamer" ''
  ~/Documents/Github/ai-renamer/result/bin/ai-renamer "$@" -m llava:34b
''