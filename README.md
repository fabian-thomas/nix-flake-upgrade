nix-flake-upgrade module and script. Pretty much `system.autoUpgrade` but with nicer commits for `flake.lock` changes.

Git commits look like this:
```md
chore(thinkpad,os): update flake.lock

## Flake lock changes
Flake lock file updates:

• Updated input 'child':
    'path:/home/fabian/desktop/flake-update-test/child?lastModified=1745778931&narHash=sha256-i%2Bl6bo9KOKCrnBoAKtAJ46kpX61pamb4MAk2UwMcbvE%3D' (2025-04-27)
  → 'path:/home/fabian/desktop/flake-update-test/child?lastModified=1745781832&narHash=sha256-lzFCaTPSx8UcCJQBNHtdgtbQNnRk1XBrIfcV7SaalZg%3D' (2025-04-27)

## System closure diff
<<< /nix/store/fsjsa2012s442gcai1vn3wz1qhn60f6r-nixos-system-thinkpad-24.11pre-git
>>> /nix/store/z3am2v7pp30m58j8gnih71rj60s30irh-nixos-system-nixos-24.11.20250424.5630cf1
Version changes:
[C*]  #001  acl                     2.3.2 x3, 2.3.2-bin, 2.3.2-doc, 2.3.2-man -> 2.3.2, 2.3.2-bin, 2.3.2-doc, 2.3.2-man
[C*]  #002  attr                    2.5.2 x3, 2.5.2-bin, 2.5.2-doc, 2.5.2-man -> 2.5.2, 2.5.2-bin, 2.5.2-doc, 2.5.2-man
[C.]  #003  audit                   4.0 x2, 4.0-bin, 4.0.3-lib -> 4.0, 4.0-bin
```

## Features

- Auto-update the `flake.lock` file with `--update-lock-file` option.
- Supports NixOS (`--os`) and Home Manager (`--home`) configs.
- Integrated Git workflow (`--push`) for pulling, rebasing, and pushing changes.
- Provides (via [nh](https://github.com/nix-community/nh)): `switch`, `boot`, `test`, and `build`.
- NixOS module for scheduled upgrades similar to `system.autoUpgrade`.

## Usage

### NixOS Module

The NixOS Module is a minor modification to the `system.autoUpgrade` module, therefore you can largely copy over your settings.
For a detailed explanation of the options see `auto-upgrade.nix`.

Flake input:
```nix
nix-flake-upgrade = {
  url = "path:/home/fabian/nix-flake-upgrade";
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
    path = "/home/fabian/dotfiles-remote/nix/machines/${config.networking.hostName}";
    user = "fabian";
    nix-flake-upgrade-flags = [ "--os" ];
    nix-flake-upgrade-flags-once = [ "--update-lock-file" "--push" ];
  };
}
```

### CLI

```bash
nix-flake-upgrade [--update-lock-file] [--result-dir <path>] [--os] [--home] [--push] <COMMAND> [<FLAKE_DIR>] [-- <EXTRA_ARGS>...]
```

#### Commands

Those of [nh](https://github.com/nix-community/nh):
- `switch`: Build and activate the new configuration, and make it the boot default
- `boot`:   Build the new configuration and make it the boot default
- `test`:   Build and activate the new configuration
- `build`:  Build the new configuration

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

#### Examples

- **Update lock file, switch NixOS config, push commit**:
  ```bash
  nix-flake-upgrade --update-lock-file --push --os switch
  ```

- **Build Home-Manager configuration**:
  ```bash
  nix-flake-upgrade --home build
  ```
