{ ... }:

{
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    config = {
      DOMAIN = "https://localhost";
      SIGNUPS_ALLOWED = true;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      WEB_VAULT_ENABLED = true;
      LOG_LEVEL = "warn";
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts."localhost".extraConfig = ''
      bind 127.0.0.1
      tls internal
      reverse_proxy 127.0.0.1:8222
    '';
  };
}
