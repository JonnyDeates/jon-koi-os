{ pkgs }:

# Zed wrapper that bypasses the bwrap sandbox to fix NoSupportedDeviceFound when launched from Rofi.
# The sandbox's VK_ICD_FILENAMES points to /run/host/ which doesn't exist outside of container contexts.
# This wrapper calls the real Zed ELF directly, bypassing the bubblewrap sandbox.
pkgs.writeShellScriptBin "zed-open" ''
  # Real Zed ELF binary (bypassing bwrap sandbox at /run/current-system/sw/bin/zeditor).
  # System install is zed-editor-fhs (bwrap-wrapped); pkgs.zed-editor is the raw ELF.
  # Reference via nix interpolation so this stays in sync with the package.
  ZED_REAL="${pkgs.zed-editor}/bin/zeditor"

  # Wayland environment
  export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
  export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/1000}"

  # Unset VK_ICD_FILENAMES — /run/host/ doesn't exist in our context and causes the Vulkan
  # ICD loader to fail. RADV auto-detects fine without it.
  unset VK_ICD_FILENAMES

  # Preserve GPU env vars from NixOS AMDGPU config
  export AMD_VULKAN_ICD="''${AMD_VULKAN_ICD:-RADV}"
  export HSA_OVERRIDE_GFX_VERSION="''${HSA_OVERRIDE_GFX_VERSION:-11.0.0}"
  export HCC_AMDGPU_TARGET="''${HCC_AMDGPU_TARGET:-gfx1100}"

  exec "$ZED_REAL" "$@"
''
