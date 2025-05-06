`nix-flake-upgrade` module and script. Pretty much `system.autoUpgrade` but with nicer commits for `flake.lock` changes.

Git commits look like this:
```md
commit d768e16bc74a6ac146b510c093508c3a3cf13530
Author: my-server[bot] <my-server[bot]>
Commit: Fabian Thomas <fabian@fabianthomas.de>

    chore(my-server,os): update nix/machines/my-server/flake.lock

    ## Flake lock changes
    Flake lock file updates:

    • Updated input 'nixpkgs':
        'github:NixOS/nixpkgs/bf3287dac860542719fe7554e21e686108716879?narHash=sha256-kwaaguGkAqTZ1oK0yXeQ3ayYjs8u/W7eEfrFpFfIDFA%3D' (2025-05-02)
      → 'github:NixOS/nixpkgs/537ee98218704e21ea465251de512ab6bbb9012e?narHash=sha256-5odz%2BNZszRya//Zd0P8h%2BsIwOnV35qJi%2B73f4I%2Biv1M%3D' (2025-05-03)
    • Updated input 'nixpkgs-unstable':
        'github:NixOS/nixpkgs/7a2622e2c0dbad5c4493cb268aba12896e28b008?narHash=sha256-MHmBH2rS8KkRRdoU/feC/dKbdlMkcNkB5mwkuipVHeQ%3D' (2025-05-03)
      → 'github:NixOS/nixpkgs/979daf34c8cacebcd917d540070b52a3c2b9b16e?narHash=sha256-uKCfuDs7ZM3QpCE/jnfubTg459CnKnJG/LwqEVEdEiw%3D' (2025-05-04)

    ## System closure diff
    <<< /nix/store/pfhj5ryyar39cbn2379bp522r0aqzlw6-nixos-system-my-server-24.11.20250502.bf3287d
    >>> /nix/store/r9pv9ld4flyzfbqk1iljjb2jdb99bw68-nixos-system-my-server-24.11.20250503.537ee98
    Version changes:
    [U*]  #1  cpupower                6.6.88 -> 6.6.89
    [U.]  #2  initrd-linux            6.6.88 -> 6.6.89
    [U.]  #3  linux                   6.6.88, 6.6.88-modules, 6.6.88-modules-shrunk -> 6.6.89, 6.6.89-modules, 6.6.89-modules-shrunk
    [U.]  #4  nixos-system-my-server  24.11.20250502.bf3287d -> 24.11.20250503.537ee98
    Closure size: 810 -> 810 (26 paths added, 26 paths removed, delta +0, disk usage -5.3KiB).
```

## Features

- Update `flake.lock` with nicer commit messages (see above).
- Supports NixOS (`--os`) and Home Manager (`--home`) configs.
- Integrated Git workflow (`--push`) for pulling, rebasing, and pushing changes.
- NixOS module for scheduled upgrades similar to `system.autoUpgrade`.

## Usage

### NixOS Module

The NixOS Module is a minor modification to the `system.autoUpgrade` module, therefore you can largely copy over your settings.
For a detailed explanation of the options see `auto-upgrade.nix`.
The modified module introduces a second systemd unit that runs as the user that the flake repository belongs too.
This unit updates `flake.lock` if the configuration builds successfully.

> [!IMPORTANT]
> Because the nixos-upgrade service runs as the root user you need to run this command once:
> ``` sh
> sudo git config --global --add safe.directory "/path/to/your/repo"
> ```

Flake input:
```nix
nix-flake-upgrade = {
  url = "github:fabian-thomas/nix-flake-upgrade";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Configuration:
```nix
{ config, nix-flake-upgrade, system, ... }:

{
  imports = [
    nix-flake-upgrade.nixosModule.${system}
  ];

  system.autoUpgradeFlake = {
    enable = true;
    dates = "03:00";
    allowReboot = true;
    flake-dir = "/path/to/your/repo/nixos/my-machine";
    user = "your-user";
    nix-flake-upgrade-flags = [ "--update-lock-file" "--push" "--os" ];
  };
}
```

### CLI

```bash
nix-flake-upgrade [--update-lock-file] [--result-dir <path>] [--os] [--home] [--push] [<FLAKE_DIR>] [-- <EXTRA_ARGS>...]
```

#### Options

- `--update-lock-file`:  Bump flake.lock and commit
- `--os`:                Build NixOS
- `--home`:              Build Home-Manager
- `--push`:              git pull --rebase && git push
- `--result-dir <path>`: Write outputs into `<path>`
- `-- <EXTRA_ARGS>`:     Passed to nix build

#### Installation

Test it out without installation:
```
nix run github:fabian-thomas/nix-flake-upgrade
```

Install it permanently:
```
nix profile install github:fabian-thomas/nix-flake-upgrade
```

#### Example

Update lock file, build NixOS and Home-Manager config, diff configs, and push commit:
```bash
nix-flake-upgrade --update-lock-file --push --os --home
```
