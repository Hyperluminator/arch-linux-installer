# Arch Linux Installer
A Bash script to install Arch Linux after booting into the installation media. Currently, this script only can perform an installation into an **EXT4 partition** with a **mandatory swap file** and **only supports legacy BIOS devices without an EFI partition**. This script **will format the target partition** that is specified as `root_partition` in `config/config.txt`.

Before executing the installer script, make sure to check out the configuration text files inside the `config/` directory and configure them according to your needs.

## How to Use
First, boot into an Arch Linux installation media.

Then, make sure that your device is connected to the internet. If your device is already connected to the internet via an ethernet cable, chances are your device is already connected to the internet. But if your device is connected to the internet via Wi-Fi, you need to use `iwctl` to connect it to the internet. Check out [the Arch Wiki page about iwd](https://wiki.archlinux.org/title/Iwd#Usage) to see the latest guide on how to use `iwctl`.

Make sure that the target partition isn't mounted, then the final step is to execute the installer script and follow the instructions.
