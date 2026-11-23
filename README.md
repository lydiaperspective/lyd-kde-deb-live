# lyd KDE Debian Live

A Debian 13 (Trixie) Live Build project for two installable amd64 images:

- **Desktop** — KDE Plasma workstation image.
- **Server** — headless/server image with SSH, Podman and administration tools.

Both images include **lydsys**, an interactive system configuration utility, **lydhelp**, a terminal reference, and **lydsetup**, a separate interactive post-install setup manager. The project uses Debian's official repositories; it is a Debian derivative configuration, not a fork of Debian's package archive.

## Status

Initial project foundation. GitHub Actions builds are configured, but the first ISO builds and installation flows still need validation on real/virtual hardware before being treated as production releases.

## Build locally

On a Debian 13 build host, install the build dependencies:

```bash
sudo apt update
sudo apt install live-build debootstrap squashfs-tools xorriso isolinux syslinux-common grub-common grub-pc-bin grub-efi-amd64-bin librsvg2-bin fonts-dejavu-core mtools dosfstools rsync
```

The build host must use Debian 13 (Trixie) live-build version `1:20250505` or newer. Ubuntu 24.04 ships an older live-build with obsolete Debian Installer package names; the local script now checks this and stops rather than running a known-incompatible build. GitHub Actions builds inside a Debian Trixie container.
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
- Common utilities; optional gaming performance and virtualization components can be added later with `lydsetup`
- The **Mystical** KDE Global Theme: midnight-plum colour scheme, Plasma panel/widget style, moonlit wallpaper, animated Plasma splash, Breeze-compatible GTK integration, and original lunar/botanical artwork
- The Mystical GRUB boot theme on the desktop ISO UEFI menu, using the same moonlit artwork and plum/lavender/gold palette
- `lydsys` and the `lydhelp` command-line reference

### Server
- Debian 13 Trixie, amd64
- No desktop environment
- OpenSSH server, Podman, Cockpit, tuned, btrfs-progs, Snapper and common administration tools
- The Mystical GRUB theme assets and installer helper, without adding desktop packages
- `lydsys`
- The same guided UEFI/GPT Btrfs installation layout and post-install `@home`/Snapper setup as the desktop image

### lydsys and lydsetup

Run `sudo lydsys` after installation for system configuration tasks. Run `lydsetup` as your regular user for the guided post-install component selector. `lydsetup` offers optional tasks for KDE utilities, gaming performance tools (GameMode, MangoHud, vkBasalt and Vulkan utilities), QEMU/KVM virtualization with virt-manager, Flatpak/Flathub, Podman, TuneD, Cockpit, SSH, Tailscale, NVIDIA drivers, Btrfs/Snapper and headless conversion. It supports reusable task-selection profiles under `~/.config/lydsetup/profiles/` and records timestamped logs under `~/.config/lydsetup/logs/`. The gaming task does not install a game store or configure third-party repositories. `lydsys` remains the lower-level system configuration utility. The `lydhelp` command is included by default and provides topic-based terminal help for files, folders, search, permissions, storage, processes, networking, packages and archives. It offers optional configuration tasks for system updates, KDE workstation tools, gaming, Btrfs mount options, Snapper, Flatpak, Podman, TuneD, Cockpit, SSH, Tailscale, virtualization, legacy Intel VA-API, automatic APT updates, removing KDE to make a desktop install headless, creating the Ark-style `/ark` storage layout with `ark`, `video` and `render` group membership, adding the optional `woman` alias for `man`, applying the Mystical KDE Global Theme, and applying the Mystical GRUB boot theme. The GRUB option is available as `sudo lydsys run 19` or as a selectable task in `lydsetup`; it installs the staged theme assets, backs up `/etc/default/grub`, and regenerates the GRUB menu. The helper keeps a timestamped `/etc/default/grub` backup; run `sudo /usr/local/lib/lyd/install-grub-theme.sh --restore` to restore the latest backup. Read-only commands include `lydsys info`, `lydsys storage list`, and `lydsys storage status`. The `/ark` layout uses `Containers`, `Media`, `Share`, and `Configs`; it does not relocate Podman's graph root or migrate existing data.

The Mystical theme is copied from the Lyd Ark Themes project into this repository under `themes/mystical/`. It is installed in the desktop image as a KDE Plasma 6 Global Theme, standalone colour scheme, Plasma Style, wallpaper package, and Plasma splash package. The installer also preserves the original illustrated moon, triple-moon, crystal, lavender, sage, and pentacle SVG assets. System XDG defaults select the Mystical colour scheme and Plasma Style for new desktop users while retaining Breeze's application widget style, icon theme, cursor, and window-decoration implementation for compatibility. GTK integration uses Debian's Breeze GTK theme and KDE GTK configuration module so GTK applications remain visually coordinated. Existing users can apply the full package from System Settings → Appearance → Global Theme or with `sudo lydsys run 18`. The SVG artwork pack is not represented as a complete application icon theme, and custom cursor artwork / a custom SDDM login theme are not included yet. The GRUB theme uses the existing moonlit wallpaper, rendered to PNG with GRUB-compatible fonts during the image build. Debian Trixie live-build handles the current installer and firmware package metadata; the obsolete Ubuntu live-build compatibility patch is no longer run.

The installer defaults to a guided UEFI/GPT layout with a 1 GiB EFI System Partition, an 8 GiB swap partition, and the remaining space as Btrfs. The installer still asks you to choose the target disk and confirm partition changes; it does not silently erase a disk. Debian Installer creates the root subvolume (`@rootfs`), and a late-install step creates a sibling `@home` subvolume, migrates the initial home-directory contents, applies `noatime,compress=zstd:3`, and configures Snapper/timers when Snapper is present. This post-install path needs testing in both UEFI virtual machines and real hardware before release. Manual partitioning remains available, but the automatic post-install subvolume step expects the standard Btrfs root layout. Snapper snapshots are not backups.

For Ivy Bridge Intel HD Graphics (such as the i7-3770S' integrated GPU), the legacy VA-API option installs Debian's `i965-va-driver` and `i965-va-driver-shaders` packages plus `vainfo`/FFmpeg. Debian documents Ivy Bridge support in this driver family. Encoding support depends on the codec and hardware entry point; verify with `vainfo` and your application. [Debian package details](https://packages.debian.org/trixie/i965-va-driver) · [shader package](https://packages.debian.org/trixie/i965-va-driver-shaders).

## Important design notes

- The live system and installed system are separate environments. The included live installer is Debian Installer's live mode; verify the installer path and installed package persistence during the first test cycle.
- Both profiles use Debian's `main contrib non-free non-free-firmware` archive areas to make firmware and optional non-free driver packages available.
- The desktop ISO uses the Mystical theme in its UEFI GRUB menu; the legacy BIOS live menu remains the standard Syslinux/ISOLINUX menu. Both images include the optional installed-system GRUB theme helper and assets. The server live menu remains simple, and the server remains headless without Plasma theme packages.
- The ISO build itself does not create a custom APT repository. Installed systems receive normal Debian updates. A project-owned signed APT repository can be added later for lydsys and distribution packages.
- Snapper snapshots are not backups.
- The workflow uses GitHub-hosted runners and may approach runner storage/time limits as images grow. Artifacts have a 14-day retention period.

## Project layout

```text
.github/workflows/       CI build and tagged release
profiles/desktop/        KDE image configuration and package list
profiles/server/         server image configuration and package list
themes/mystical/         copied Ark theme source and KDE Plasma components
scripts/build-iso.sh     local profile builder
scripts/install-mystical-theme.sh  stages Mystical KDE appearance into desktop image
scripts/install-grub-theme.sh      stages/applies Mystical GRUB theme
scripts/9999-grub-theme.hook.binary  enables theme in desktop UEFI live GRUB menu
scripts/lydsys           Debian-specific system configuration utility
scripts/lydsetup         interactive post-install setup manager
```

## License

Configuration and scripts in this repository are provided under the MIT License. Debian packages, artwork and other third-party components remain under their respective licenses.
