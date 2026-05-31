{
  description = "Deploy server";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.ds4music = {
    url = "git+ssh://git@github.com/manushanga/ds4music.git?ref=main&submodules=1";
    flake = true;
  };

  outputs = { self, nixpkgs, ds4music, ... }:
  let
    system = "aarch64-linux";
    pkgs = import nixpkgs { inherit system; };

    ds4musicPkg = ds4music.packages.${system}.default;

    runDs4music = pkgs.writeShellScriptBin "run-ds4music" ''
      exec ${ds4musicPkg}/bin/remote "$@"
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
    packages.${system} = {
      supervisorConf = mkSupervisorConf (import ./nandimitra.nix);
      supervisorRunner = mkSupervisorRunner (import ./nandimitra.nix);
      ds4music = ds4musicPkg;

      default = self.packages.${system}.supervisorRunner;
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = [
        pkgs.python3Packages.supervisor
      ];
    };
  };
}
