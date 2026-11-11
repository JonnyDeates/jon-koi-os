{ pkgs, inputs, ... }:

{
  environment.variables = {
    # Prisma engine paths for NixOS (avoids libssl detection failure)
    PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
    PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
    PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING = "1";
  };

  environment.systemPackages = with pkgs; [
    rustup # The official installer and version manager for the Rust programming language toolchain.
    cargo
    rustc
    gcc
    nodejs_22
    nodePackages.pnpm
    prisma-engines
    openssl
    inputs.openclaude-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
