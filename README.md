# lyd KDE Debian Live

A Debian 13 (Trixie) Live Build project for two installable amd64 images:

- **Desktop** — KDE Plasma workstation image.
- **Server** — headless/server image with SSH, Podman and administration tools.

Both images include **lydsys**, an interactive system configuration utility. The project uses Debian's official repositories; it is a Debian derivative configuration, not a fork of Debian's package archive.

## Status

Initial project foundation. GitHub Actions builds are configured, but the first ISO builds and installation flows still need validation on real/virtual hardware before being treated as production releases.

## Build locally

On a Debian 13 build host, install the build dependencies:

```bash
sudo apt update
sudo apt install live-build debootstrap squashfs-tools xorriso isolinux syslinux-common grub-pc-bin grub-efi-amd64-bin mtools dosfstools
```

Build either image:

```bash
bash scripts/build-iso.sh desktop
bash scripts/build-iso.sh server
```

The generated ISO is placed in the selected profile directory. Builds require root privileges for live-build; the script uses sudo when needed.

## GitHub Actions

The workflow in `.github/workflows/build-iso.yml` runs on pushes to `main`, pull requests, a weekly schedule, and manual dispatch. It builds both profiles and uploads the ISO plus SHA256 checksum as workflow artifacts.

Push a tag such as `v0.1.0` to create a GitHub Release containing both images. Repository Actions permissions must allow write access for release publishing.

## Image contents

### Desktop
- Debian 13 Trixie, amd64
- KDE Plasma desktop task and SDDM
- Firefox ESR, NetworkManager, firmware, Flatpak and Discover Flatpak support
- Common utilities, gaming tools and virtualization packages
- lydsys

### Server
- Debian 13 Trixie, amd64
- No desktop environment
- OpenSSH server, Podman, Cockpit, tuned, btrfs-progs, Snapper and common administration tools
- lydsys

### lydsys

Run `sudo lydsys` after installation. It offers optional configuration tasks for system updates, KDE workstation tools, gaming, Btrfs mount options, Snapper, Flatpak, Podman, TuneD, Cockpit, SSH, Tailscale, virtualization, legacy Intel VA-API, automatic APT updates, removing KDE to make a desktop install headless, and creating the Ark-style `/ark` storage layout with `ark`, `video` and `render` group membership. Read-only commands include `lydsys info`, `lydsys storage list`, and `lydsys storage status`. The `/ark` layout uses `Containers`, `Media`, `Share`, and `Configs`; it does not relocate Podman's graph root or migrate existing data.

Tasks are opt-in. The utility does not repartition disks or silently convert filesystem layouts. Snapper setup requires a Btrfs root subvolume and deliberately stops if an existing `/.snapshots` layout needs inspection.

For Ivy Bridge Intel HD Graphics (such as the i7-3770S' integrated GPU), the legacy VA-API option installs Debian's `i965-va-driver` and `i965-va-driver-shaders` packages plus `vainfo`/FFmpeg. Debian documents Ivy Bridge support in this driver family. Encoding support depends on the codec and hardware entry point; verify with `vainfo` and your application. [Debian package details](https://packages.debian.org/trixie/i965-va-driver) · [shader package](https://packages.debian.org/trixie/i965-va-driver-shaders).

## Important design notes

- The live system and installed system are separate environments. The included live installer is Debian Installer's live mode; verify the installer path and installed package persistence during the first test cycle.
- Both profiles use Debian's `main contrib non-free non-free-firmware` archive areas to make firmware and optional non-free driver packages available.
- The ISO build itself does not create a custom APT repository. Installed systems receive normal Debian updates. A project-owned signed APT repository can be added later for lydsys and distribution packages.
- Snapper snapshots are not backups.
- The workflow uses GitHub-hosted runners and may approach runner storage/time limits as images grow. Artifacts have a 14-day retention period.

## Project layout

```text
.github/workflows/       CI build and tagged release
profiles/desktop/        KDE image configuration and package list
profiles/server/         server image configuration and package list
scripts/build-iso.sh     local profile builder
scripts/lydsys           installed configuration utility
```

## License

Configuration and scripts in this repository are provided under the MIT License. Debian packages, artwork and other third-party components remain under their respective licenses.
