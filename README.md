# Arch Linux Installer
A Bash script to install Arch Linux after booting into the installation media. Currently, this script only can perform an installation into an **EXT4 partition** with a **mandatory swap file** and **only supports legacy BIOS devices without an EFI partition**. This script **will format the target partition** that you will specify while running the script or by modifying the `root_partition` variable.

## Prerequisite
Before using the script, if you want to install packages and copy your dotfiles automatically, you need to clone this repository or at least only download the `installer.sh` first. If you want to do them all manually however, you can skip this step and even `curl` the installer script later in the installation media.

Configuration variables are defined inside `installer.sh`, you can open the script in a text editor and modify them all if you want to automate more steps in the installer:
- `packages_list`<br>An array that contains all of the package names that will be automatically installed with `pacstrap` by the script.
- `daemons_list`<br>An array that contains all of the service names that will be enabled after all packages in `packages_list` are installed.
- `file_replacements`<br>An array that contains directory/file paths that are going to be copied into their respective target directory. Mainly used for copying dotfiles.

There are still more variables under the arrays that can be filled to perform a full auto install:
- `keyboard_layout`<br>All possible layouts can be seen by executing `localectl list-keymaps`. An example is `us`.
- `locale`<br>All possible locales can be seen in `/etc/locale.gen`. An example is `en_US.UTF-8 UTF-8`.
- `time_zone`<br>All possible time zones can be seen by executing `timedatectl list-timezones`. An example is `Antarctica/Troll`.
- `username`
- `password`
- `root_password`
- `hostname`
- `grub_drive`<br>The block device that GRUB is going to be installed, e.g. `/dev/sda`.
- `root_partition`<br>The drive partition that Arch Linux will be installed, e.g. `/dev/sda1`.
- `swapfile_size`<br>The size of the swap file (`/swapfile`) in GiB.

## How to Use
First, boot into an Arch Linux installation media.

Then, make sure that your device is connected to the internet. If your device is already connected to the internet via an ethernet cable, chances are your device is already connected to the internet. But if your device is connected to the internet via Wi-Fi, you need to use `iwctl` to connect it to the internet. Check out [the Arch Wiki page about iwd](https://wiki.archlinux.org/title/Iwd#Usage) to see the latest guide on how to use `iwctl`.

Make sure that the target partition isn't mounted, then the final step is to execute the installer script and follow the instructions.
