# Installing lyd Debian and preparing Btrfs snapshots

This guide covers two supported paths:

1. **Install the custom lyd ISO** — the guided installer already uses the intended Btrfs layout and runs the post-install Snapper/GRUB integration.
2. **Install Debian 13 first, then apply lyd** — useful when starting from a standard Debian installer or an existing Debian 13 installation.

The project currently targets **Debian 13 (Trixie), amd64, UEFI/GPT**. Keep a separate backup of important files before changing partitions or migrating an existing Btrfs layout. Snapshots on the same filesystem are not backups.

## 1. Choose your installation path

### Path A — install from the custom lyd ISO

1. Download the desktop or server ISO from the repository's [latest release](https://github.com/lydiaperspective/lyd-kde-deb-live/releases/tag/latest). If it is split into numbered parts, download every part, the matching `.iso.sha256` file, and `recombine-isos.sh` into one directory. Run the recombine script and let its checksum verification finish before using the ISO.
2. Boot the ISO in UEFI mode. The desktop image uses the Mystical GRUB theme in its UEFI boot menu; legacy BIOS uses the standard Syslinux menu.
3. On the live desktop, choose **Install Debian** for the graphical installer or **Install lyd (Text Installer)** for the terminal-based installer. The terminal launcher opens Debian Installer's text frontend in Konsole; the installer's own Newt interface keeps its standard colors.
4. Follow the installer prompts. The guided recipe is GPT with a 1 GiB EFI System Partition, 8 GiB swap, and the remaining space as Btrfs mounted at `/`. The installer asks you to choose the target disk and confirm partition changes; it does not silently choose a disk.
5. Let the installation finish and reboot into the installed system.

The custom ISO's installer late step creates `@home` and `@var`, configures Snapper and its cleanup/timeline timers, enables `grub-btrfsd`, creates an initial snapshot, and regenerates GRUB. The desktop image also installs the Mystical KDE and Konsole defaults. The server image remains headless and applies its server firewall policy.

### Path B — install standard Debian 13, then apply lyd

Use this path if you are starting with the official Debian installer rather than the custom ISO.

#### Partitioning in Debian Installer

1. Boot the Debian 13 installer in **UEFI mode** and choose Graphical install or Install.
2. At **Partition disks**, choose **Manual** so you can confirm the intended filesystem and mount points. Use a GPT partition table.
3. Create:
   - **EFI System Partition:** 1 GiB, FAT32, type EFI System Partition, mounted at `/boot/efi`.
   - **Swap:** 8 GiB, used as swap.
   - **Root:** remaining space, formatted as **Btrfs**, mounted at `/`.
4. Do not create a separate `/home` or `/var` partition for this layout. The lyd post-install step creates Btrfs subvolumes for those paths. Do not create a separate `/boot` partition unless you understand how it changes your boot layout.
5. Finish partitioning, write the changes only after checking the selected disk and partition list, and continue the Debian installation.
6. At software selection:
   - **Desktop:** select Debian desktop environment and KDE Plasma. Keep standard system utilities selected.
   - **Server:** deselect the desktop environment, select SSH server if remote access is wanted, and keep standard system utilities selected.
7. Install GRUB to the EFI System Partition when prompted, finish the installation, and reboot into Debian.

Debian Installer normally creates a Btrfs root subvolume named `@rootfs`. Confirm this after the first boot before continuing:

```bash
findmnt -no SOURCE,FSTYPE,FSROOT /
sudo btrfs subvolume list /
grep -vE '^\\s*(#|$)' /etc/fstab
```

The root line in `/etc/fstab` should identify the Btrfs filesystem and a root subvolume (commonly `subvol=@rootfs`). If `/` is not Btrfs, stop here: the lyd script does **not** convert ext4 to Btrfs. Reinstall using the intended layout or plan a separately backed-up filesystem migration.

#### Apply the lyd profile

Install Git if it is not already present, clone the repository, and run the profile installer:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/lydiaperspective/lyd-kde-deb-live.git
cd lyd-kde-deb-live

# KDE desktop:
sudo bash scripts/install-existing-debian.sh desktop

# Or headless/server:
sudo bash scripts/install-existing-debian.sh server
```

The script checks that the system is Debian 13 amd64 and requires an interactive terminal. It installs the packages from the selected ISO profile, the lyd helper commands, the pinned grub-btrfs integration, and the relevant theme assets. It does not repartition disks, replace the installed bootloader, or run a full system upgrade.

It creates a timestamped log under `/var/log/lyd-install/` and configuration backups under `/var/backups/lyd-install/`. It asks before applying the Mystical GRUB theme, changing the server Firewalld policy, and running the Btrfs/Snapper migration. Read each prompt before accepting it.

If you decline the Btrfs step, first review the layout and then run:

```bash
sudo /usr/local/sbin/lyd-btrfs-postinstall
```

Do not run that migration on a non-Btrfs root or on an unfamiliar/custom subvolume layout.

## 2. Intended Btrfs layout

The intended filesystem arrangement is:

| Mount point | Btrfs subvolume / partition | Purpose |
|---|---|---|
| `/` | `@rootfs` | Snapper-managed operating system root |
| `/home` | `@home` | User data kept outside root snapshots |
| `/var` | `@var` | Logs, package state, and runtime data kept outside root snapshots |
| `/boot/efi` | EFI System Partition | UEFI boot files, not a Btrfs subvolume |
| swap | swap partition | Swap |

The helper creates `@home` and `@var` as sibling subvolumes at the Btrfs top level, copies the existing contents, adds their mount entries to `/etc/fstab`, and validates the resulting mounts. It applies `noatime,compress=zstd:3` to the root mount. Existing `/home` or `/var` mount entries are preserved rather than replaced.

Keeping `/var` outside the root snapshots is part of this project's intended read-only snapshot-boot design. Do not improvise a different subvolume layout without reviewing how Snapper and grub-btrfs discover the snapshots.

## 3. Snapper and GRUB integration

The post-install step:

- Installs/configures Snapper's `root` configuration if one does not already exist.
- Enables Snapper timeline and cleanup timers with conservative retention limits.
- Creates an initial snapshot if no snapshot exists yet.
- Installs the project's pinned grub-btrfs v4.14 integration, including its Debian Btrfs UUID parsing compatibility patch.
- Enables `grub-btrfsd` and runs `update-grub` to generate the snapshot menu.

After the installer finishes, inspect the configuration:

```bash
findmnt -no SOURCE,FSTYPE,FSROOT /
findmnt /home /var /boot/efi
sudo btrfs subvolume list /
sudo snapper -c root list
systemctl status snapper-timeline.timer snapper-cleanup.timer grub-btrfsd.service
grep -E '^(GRUB_THEME|GRUB_GFXMODE|GRUB_TERMINAL_OUTPUT)=' /etc/default/grub
```

If the theme was selected, the GRUB configuration should reference:

```
/boot/grub/themes/lyd-mystical/theme.txt
```

Then reboot and check that the GRUB menu loads and that the snapshot submenu appears. Create a test snapshot with:

```bash
sudo snapper -c root create --description "Manual verification snapshot"
sudo update-grub
sudo snapper -c root list
```

The daemon should monitor later snapshot changes and refresh the menu. If the submenu is absent, check `journalctl -u grub-btrfsd.service` and the generated `/boot/grub/grub.cfg` before attempting recovery.

**Important:** a GRUB snapshot entry is a recovery boot option, not an automatic persistent rollback. The snapshot is generally booted read-only; treat it as a way to inspect or recover the system. A real rollback requires a deliberate restore procedure. Keep backups on another device or system as well.

## 4. Mystical desktop theme

The desktop profile installs the currently included Mystical appearance components:

- KDE Global Theme and midnight-plum color scheme.
- Custom Plasma panel/widget style and moonlit wallpaper.
- Plasma splash screen.
- Breeze-compatible GTK integration.
- Lyd Mystical Konsole profile and color scheme.
- Mystical GRUB theme using the moonlit artwork and matching plum/lavender/gold palette.
- Original lunar, botanical, crystal, and pentacle SVG artwork.

For an existing KDE account, the installer offers to apply the Global Theme. If you skip that prompt or it cannot reach the running Plasma session, sign in and select **System Settings → Appearance → Global Theme → Mystical**. Sign out and back in if some Plasma components do not update immediately.

The standard Breeze, hicolor, and Adwaita icon themes are installed as application-icon fallbacks. The SVG artwork collection is not a complete freedesktop application icon theme, so it does not replace every app icon. Debian's Breeze window decoration remains the compatible default; the Aurorae runtime is provided by Debian's `kwin-common` package. A separate custom SDDM login theme and custom cursor theme are not currently included.

The server profile does not install Plasma or the desktop theme; it includes the Mystical GRUB theme helper/assets only.

## 5. Recovery and safety notes

- Keep a separate backup before changing partitions, moving data, or changing `/etc/fstab`.
- Do not run the Btrfs migration on an ext4 root; it is not an ext4-to-Btrfs converter.
- Check that the root filesystem is mounted from a named Btrfs subvolume, normally `@rootfs`, before enabling Snapper.
- If the machine uses encryption, RAID, a separate `/boot`, an unusual EFI arrangement, or custom Btrfs subvolumes, review the layout manually before accepting automated changes.
- Snapshots share the same underlying filesystem and do not protect against disk failure, accidental filesystem loss, or theft.
- The project has not yet been validated across every hardware/firmware combination. Test the install and recovery path in a virtual machine before relying on it on a primary machine.

## References

- [Debian Wiki: Btrfs](https://wiki.debian.org/Btrfs)
- [Debian Trixie Btrfs installation notes](https://mutschler.dev/linux/debian-btrfs-trixie/)
- [grub-btrfs upstream project](https://github.com/Antynea/grub-btrfs)
