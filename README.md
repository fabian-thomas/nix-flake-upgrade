`nix-flake-upgrade` module and script. Pretty much `system.autoUpgrade` but with nicer commits for `flake.lock` changes.

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

- Update `flake.lock` with nicer commit messages.
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
