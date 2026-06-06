{ config, pkgs, cfg, ... }:
let 
  startPostgresService = pkgs.writeShellScriptBin "start_postgres_service" ''
    set -euo pipefail

    DB_CONFIG_DIR="$HOME/Config/postgres"
    if [ ! -f "$DB_CONFIG_DIR/pgpass.txt" ]; then
      echo "Password file missing in $DB_CONFIG_DIR"
      exit 1
    fi

    mkdir -p "$DB_CONFIG_DIR"

    cp ${./config/postgres/compose.yaml} "$DB_CONFIG_DIR/compose.yaml"

    cd "$DB_CONFIG_DIR"
    ${pkgs.podman-compose}/bin/podman-compose pull
    ${pkgs.podman-compose}/bin/podman-compose up -d
  '';
in
{
  home.username = "opihome";
  home.homeDirectory = "/home/opihome";
  home.stateVersion = "25.11";
  home.file.".config/containers/storage.conf".text = ''
    [storage]
    driver = "overlay"
    graphroot = "${cfg.storageMount}/Containers/graphroot"
    runroot = "${cfg.storageMount}/Containers/runroot"
  '';

  home.packages = [
    startPostgresService
  ];
}
