# Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
# MIT
# https://raw.githubusercontent.com/NixOS/nixpkgs/b9956ceb874343097bfd25f3a441b332c15e8006/nixos/modules/tasks/auto-upgrade.nix
{
  nix-flake-upgrade
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.system.autoUpgradeFlake;

in
{

  options = {

    system.autoUpgradeFlake = {

      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to periodically upgrade NixOS to the latest
          version. If enabled, a systemd timer will run
          `nixos-rebuild switch --upgrade` once a
          day.
        '';
      };

      operation = lib.mkOption {
        type = lib.types.enum [
          "switch"
          "boot"
        ];
        default = "switch";
        example = "boot";
        description = ''
          Whether to run
          `nixos-rebuild switch --upgrade` or run
          `nixos-rebuild boot --upgrade`
        '';
      };

      flake-path = lib.mkOption {
        type = lib.types.str;
        example = "/home/your-user/my-flake-based-nixos-config/";
        description = ''
          Path to the flake of the NixOS configuration to build.
          Disables the option {option}`system.autoUpgrade.channel`.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        example = "your-user";
        description = ''
          The user to run the nix-flake-upgrade unit as. Use the user that the
          repository folder belongs to.
        '';
      };

      nix-flake-upgrade-flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "--update-lock-file" "--os" ];
        example = [ "--update-lock-file" "--push" "--os" ];
        description = ''
          Flags passed to {command}`nix-flake-upgrade`.
        '';
      };

      flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "-I"
          "stuff=/home/alice/nixos-stuff"
          "--option"
          "extra-binary-caches"
          "http://my-cache.example.org/"
        ];
        description = ''
          Any additional flags passed to {command}`nixos-rebuild`.
        '';
      };

      dates = lib.mkOption {
        type = lib.types.str;
        default = "04:40";
        example = "daily";
        description = ''
          How often or when upgrade occurs. For most desktop and server systems
          a sufficient upgrade frequency is once a day.

          The format is described in
          {manpage}`systemd.time(7)`.
        '';
      };

      allowReboot = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = ''
          Reboot the system into the new generation instead of a switch
          if the new generation uses a different kernel, kernel modules
          or initrd than the booted system.
          See {option}`rebootWindow` for configuring the times at which a reboot is allowed.
        '';
      };

      randomizedDelaySec = lib.mkOption {
        default = "0";
        type = lib.types.str;
        example = "45min";
        description = ''
          Add a randomized delay before each automatic upgrade.
          The delay will be chosen between zero and this value.
          This value must be a time span in the format specified by
          {manpage}`systemd.time(7)`
        '';
      };

      fixedRandomDelay = lib.mkOption {
        default = false;
        type = lib.types.bool;
        example = true;
        description = ''
          Make the randomized delay consistent between runs.
          This reduces the jitter between automatic upgrades.
          See {option}`randomizedDelaySec` for configuring the randomized delay.
        '';
      };

      rebootWindow = lib.mkOption {
        description = ''
          Define a lower and upper time value (in HH:MM format) which
          constitute a time window during which reboots are allowed after an upgrade.
          This option only has an effect when {option}`allowReboot` is enabled.
          The default value of `null` means that reboots are allowed at any time.
        '';
        default = null;
        example = {
          lower = "01:00";
          upper = "05:00";
        };
        type =
          with lib.types;
          nullOr (submodule {
            options = {
              lower = lib.mkOption {
                description = "Lower limit of the reboot window";
                type = lib.types.strMatching "[[:digit:]]{2}:[[:digit:]]{2}";
                example = "01:00";
              };

              upper = lib.mkOption {
                description = "Upper limit of the reboot window";
                type = lib.types.strMatching "[[:digit:]]{2}:[[:digit:]]{2}";
                example = "05:00";
              };
            };
          });
      };

      persistent = lib.mkOption {
        default = true;
        type = lib.types.bool;
        example = false;
        description = ''
          Takes a boolean argument. If true, the time when the service
          unit was last triggered is stored on disk. When the timer is
          activated, the service unit is triggered immediately if it
          would have been triggered at least once during the time when
          the timer was inactive. Such triggering is nonetheless
          subject to the delay imposed by RandomizedDelaySec=. This is
          useful to catch up on missed runs of the service when the
          system was powered down.
        '';
      };

    };

  };

  config = lib.mkIf cfg.enable {

    systemd.services.flake-upgrade = {
      description     = "Upgrade NixOS Flake";

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig.Type = "oneshot";
      serviceConfig.User = cfg.user;

      script = ''
          ${nix-flake-upgrade}/bin/nix-flake-upgrade ${toString (cfg.nix-flake-upgrade-flags)} ${cfg.flake-path} -- ${toString cfg.flags}
        '';

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    systemd.services.nixos-upgrade = {
      description = "NixOS Upgrade";

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig.Type = "oneshot";

      environment =
        config.nix.envVars
        // {
          inherit (config.environment.sessionVariables) NIX_PATH;
          HOME = "/root";
        }
        // config.networking.proxy.envVars;

      path = with pkgs; [
        coreutils
        gnutar
        xz.bin
        gzip
        gitMinimal
        config.nix.package.out
        config.programs.ssh.package
      ];

      script =
        let
          nixos-rebuild = "${config.system.build.nixos-rebuild}/bin/nixos-rebuild";
          date = "${pkgs.coreutils}/bin/date";
          readlink = "${pkgs.coreutils}/bin/readlink";
          shutdown = "${config.systemd.package}/bin/shutdown";
          flags = cfg.flags ++ [ "--flake ${cfg.flake-path}" ];
        in
        if cfg.allowReboot then
          ''
            ${nixos-rebuild} boot ${toString (flags)}
            booted="$(${readlink} /run/booted-system/{initrd,kernel,kernel-modules})"
            built="$(${readlink} /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"

            ${lib.optionalString (cfg.rebootWindow != null) ''
              current_time="$(${date} +%H:%M)"

              lower="${cfg.rebootWindow.lower}"
              upper="${cfg.rebootWindow.upper}"

              if [[ "''${lower}" < "''${upper}" ]]; then
                if [[ "''${current_time}" > "''${lower}" ]] && \
                   [[ "''${current_time}" < "''${upper}" ]]; then
                  do_reboot="true"
                else
                  do_reboot="false"
                fi
              else
                # lower > upper, so we are crossing midnight (e.g. lower=23h, upper=6h)
                # we want to reboot if cur > 23h or cur < 6h
                if [[ "''${current_time}" < "''${upper}" ]] || \
                   [[ "''${current_time}" > "''${lower}" ]]; then
                  do_reboot="true"
                else
                  do_reboot="false"
                fi
              fi
            ''}

            if [ "''${booted}" = "''${built}" ]; then
              ${nixos-rebuild} ${cfg.operation} ${toString flags}
            ${lib.optionalString (cfg.rebootWindow != null) ''
              elif [ "''${do_reboot}" != true ]; then
                echo "Outside of configured reboot window, skipping."
            ''}
            else
              ${shutdown} -r +1
            fi
          ''
        else
          ''
            ${nixos-rebuild} ${cfg.operation} ${toString (flags)}
          '';

      startAt = cfg.dates;

      requires = [ "flake-upgrade.service" ];
      after = [ "network-online.target" "flake-upgrade.service" ];
      wants = [ "network-online.target" ];
    };

    systemd.timers.nixos-upgrade = {
      timerConfig = {
        RandomizedDelaySec = cfg.randomizedDelaySec;
        FixedRandomDelay = cfg.fixedRandomDelay;
        Persistent = cfg.persistent;
      };
    };
  };

}
