{
  description = "Deploy server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    ds4music = {
      url = "git+ssh://git@github.com/manushanga/ds4music.git?ref=main&submodules=1";
      flake = true;
    };
    shoppingList = {
      url = "git+ssh://git@github.com/manushanga/shoppinglist.git?ref=main&submodules=1";
      flake = true;
    };
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ds4music, shoppingList, home-manager, ... }:
  let
    cfg = import ./nandimitra.nix;
    system = "aarch64-linux";
    pkgs = import nixpkgs { inherit system; };

    ds4musicPkg = ds4music.packages.${system}.default;
    
    shoppingListPkg = shoppingList.packages.${system}.default;

    runDs4music = pkgs.writeShellScriptBin "run-ds4music" ''
      exec ${ds4musicPkg}/bin/remote "$@"
    '';

    runShoppingList = pkgs.writeShellScriptBin "run-shoppinglist" ''
      exec ${shoppingListPkg}/bin/shoppinglist "$@"
    '';

    mkSupervisorConf = config:
      let    
        supervisorConf = pkgs.writeText "supervisord.conf" ''
          [supervisord]
          nodaemon=true

          [program:ds4music]
          command=${runDs4music}/bin/run-ds4music ${config.remoteMusicPlaylist}
          environment=LOG_DIR="${config.logDir}"
          autostart=true
          autorestart=true
          stdout_logfile=${config.logDir}/ds4music.svd.log
          stderr_logfile=${config.logDir}/ds4music.err.svd.log

          [program:shoppinglist]
          environment=LOG_DIR="${config.logDir}",ORDERLIST_DB_FILE="${config.confDir}/shoppinglist/pgpass.txt",TLS_CERT_FILE="${config.confDir}/shoppinglist/certs/cert.pem",TLS_KEY_FILE="${config.confDir}/shoppinglist/certs/key.pem"
          command=${runShoppingList}/bin/run-shoppinglist
          autostart=true
          autorestart=true
          stdout_logfile=${config.logDir}/shoppinglist.svd.log
          stderr_logfile=${config.logDir}/shoppinglist.err.svd.log
        '';
      in
        supervisorConf;
    mkSupervisorRunner = config:
      let
        conf = mkSupervisorConf config;
      in
        pkgs.writeShellScriptBin "run-supervisord" ''
          exec ${pkgs.python3Packages.supervisor}/bin/supervisord -c ${conf}
        '';
  in {
    homeConfigurations.opihome = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      extraSpecialArgs = {
        inherit cfg;
      };
      modules = [
        ./home.nix
      ];
    };
    packages.${system} = {
      supervisorConf = mkSupervisorConf (cfg);
      supervisorRunner = mkSupervisorRunner (cfg);
      ds4music = ds4musicPkg;

      default = self.packages.${system}.supervisorRunner;
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        python3Packages.supervisor
	podman
	podman-compose
	slirp4netns
	fuse-overlays
      ];
    };
  };
}
