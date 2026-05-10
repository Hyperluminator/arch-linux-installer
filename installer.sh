#!/usr/bin/env bash

set -euo pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

mapfile -t packages_list < <(
    sed -E "s/[[:space:]]*#.*$//" "$script_directory/config/packages.txt" |
    sed "/^[[:space:]]*$/d"
)

mapfile -t daemons_list < <(
    sed -E "s/[[:space:]]*#.*$//" "$script_directory/config/daemons.txt" |
    sed "/^[[:space:]]*$/d"
)

mapfile -t file_replacements < <(
    sed -E "s/[[:space:]]*#.*$//" "$script_directory/config/file_replacements.txt" |
    sed "/^[[:space:]]*$/d"
)

keyboard_layout=""
locale=""
time_zone=""
username=""
password=""
root_password=""
hostname=""
grub_drive=""
root_partition=""
swapfile_size=8
source "$script_directory/config/config.txt"



check_packages() {
    local missing_packages

    if ! missing_packages=$(pacman -Sp "${packages_list[@]}" 2>&1 >/dev/null); then
        echo "Packages not found:"
        echo "$missing_packages"
        exit 1
    fi

    echo "All packages found."
}

select_keyboard() {
    if [[ -z "$keyboard_layout" ]]; then
        while ! localectl list-keymaps | grep -qxF "$keyboard_layout"; do
            read -r -p "Enter keyboard layout (leave empty to set to 'us'): " keyboard_layout

            if [ -z "$keyboard_layout" ]; then
                keyboard_layout="us"
            fi
        done
    fi

    loadkeys "$keyboard_layout"

    echo "Selected $keyboard_layout as the keyboard layout."
}

select_locale() {
    if [[ -z "$locale" ]]; then
        while true; do
            read -r -p "Enter locale (leave empty to set to en_US.UTF-8 UTF-8): " locale

            if [[ -z "$locale" ]]; then
                locale="en_US.UTF-8 UTF-8"
            fi

            if grep -E -q "^#?${locale}[[:space:]]" /etc/locale.gen; then
                break;
            fi
        done
    fi

    echo "Selected $locale as the locale."
}

select_time_zone() {
    if [[ -z "$time_zone" ]]; then
        while ! timedatectl list-timezones | grep -qxF "$time_zone"; do
            read -r -p "Enter time zone (leave empty to set to Etc/UTC): " time_zone

            if [[ -z "$time_zone" ]]; then
                time_zone="Etc/UTC"
            fi
        done
    fi

    echo "Selected $time_zone as the time zone."
}

create_user_config() {
    if [[ -z "$username" ]]; then
        while [[ -z "$username" ]]; do
            read -r -p "Enter username: " username
        done
    fi

    if [[ -z "$password" ]]; then
        local password_check=""

        while [[ -z "$password" ]]; do
            read -r -s -p "Enter password: " password
            echo
        done
    
        while [[ "$password" != "$password_check" ]]; do
            read -r -s -p "Confirm password: " password_check
            echo

            if [[ "$password" != "$password_check" ]]; then
                echo "Passwords don't match. Try again."
            fi
        done
    fi

    echo "Configurations for $username successfully created."
}

create_root_password() {
    if [[ -z "$root_password" ]]; then
        local password_check=""

        while [[ -z "$root_password" ]]; do
            read -r -s -p "Enter root password: " root_password
            echo
        done
    
        while [[ "$root_password" != "$password_check" ]]; do
            read -r -s -p "Confirm password: " password_check
            echo

            if [[ "$root_password" != "$password_check" ]]; then
                echo "Passwords don't match. Try again."
            fi
        done
    fi

    echo "Root password successfully created."
}

select_hostname() {
    while [[ -z "$hostname" ]]; do
        read -r -p "Enter hostname: " hostname
    done

    echo "Set hostname to $hostname."
}

select_grub_drive() {
    if [[ -z "$grub_drive" ]]; then
        while true; do
            read -r -p "Enter GRUB drive (e.g. /dev/sda, leave empty to skip): " grub_drive

            if [[ -z "$grub_drive" ]]; then
                echo "Set GRUB drive to empty."
                break
            fi

            if [[ -b "$grub_drive" ]]; then
                echo "Set GRUB drive to $grub_drive."
                break
            fi

            echo "Invalid GRUB drive: $grub_drive"
        done
    elif [[ -b "$grub_drive" ]]; then
        echo "Set GRUB drive to $grub_drive."
    else
        echo "Invalid GRUB drive from config: $grub_drive"
        exit 1
    fi
}

select_root_partition() {
    while true; do
        if [[ -n "$root_partition" ]]; then
            if [[ "$(lsblk -ndo TYPE "$root_partition" 2>/dev/null)" == "part" ]]; then
                echo "Set root partition to $root_partition."
                break
            fi

            echo "Invalid root partition: $root_partition"
        fi

        read -r -p "Enter root partition (e.g. /dev/sda1): " root_partition
    done
}

select_swapfile_size() {
    while [[ ! "$swapfile_size" =~ ^[1-9][0-9]*$ ]]; do
        read -r -p "Enter swapfile size in GB (e.g. 8): " swapfile_size
    done

    echo "Set swapfile size to $swapfile_size."
}

confirm() {
    read -r -p "${1:-Are you sure?} [Y/n]: " response
    case "$response" in
    [nN][oO]|[nN]) 
        return 1
        ;;
    *)
        return 0
        ;;
    esac
}



if [[ "$EUID" -ne 0 ]]; then
    echo "This installer must be run as root."
    exit 1
fi

# Add DNS servers just in case the current one isn't working properly
cat << EOF >> /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

# Start config
select_keyboard
select_locale
select_time_zone
create_user_config
create_root_password
select_hostname
select_grub_drive
select_root_partition
select_swapfile_size

echo

# Display all configs for the last time before installing
cat << EOF
[ Configuration Summary ]
Keyboard Layout : $keyboard_layout
Locale          : $locale
Time Zone       : $time_zone
Username        : $username
Hostname        : $hostname
GRUB Drive      : $grub_drive
Root Partition  : $root_partition
Swapfile Size   : $swapfile_size GB
EOF

echo

if confirm "Are you sure you want to install Arch Linux with the configuration as stated above?"; then
    echo "Proceeding to installation..."
else
    echo "Exiting installation script..."
    exit 1
fi

if confirm "Rank mirrors by rate using reflector?"; then
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
fi

echo "Finding missing packages..."
check_packages

# Partition format
echo "WARNING: $root_partition will be formatted and ALL DATA ON IT WILL BE DESTROYED."

if ! confirm "Continue formatting $root_partition?"; then
    exit 1
fi

mkfs.ext4 "$root_partition"
mount "$root_partition" /mnt

# Install packages
echo "Installing packages..."
pacstrap -K /mnt "${packages_list[@]}"

# Enable daemons
echo "Enabling daemons..."

for daemon in "${daemons_list[@]}"; do
    arch-chroot /mnt systemctl enable "$daemon"
done

# FStab
echo "Generating FSTab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Localization
echo "Configuring localization..."
cat << EOF >> /mnt/etc/locale.gen

# Enabled by installer script
$locale
EOF

arch-chroot /mnt locale-gen
echo "KEYMAP=$keyboard_layout" > /mnt/etc/vconsole.conf
echo "LANG=${locale%% *}" > /mnt/etc/locale.conf

arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$time_zone" /etc/localtime

# Network Configuration
echo "Configuring network..."
echo "$hostname" > /mnt/etc/hostname
cat << EOF > /mnt/etc/hosts
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
127.0.1.1  $hostname.localdomain    $hostname
EOF

# Initramfs
echo "Generating initramfs..."
arch-chroot /mnt mkinitcpio -P

# Perform file replacements
echo "Copying files..."
for file in "${file_replacements[@]}"; do
    IFS='>' read -r origin target <<< "$file"

    origin=$(echo "$origin" | xargs)
    origin="$script_directory/$origin"
    target="/mnt$(echo "$target" | xargs)"

    if [[ -f "$origin" ]]; then
        if [[ -f "$target" ]]; then
            rm -f "$target"
        fi

        mkdir -p "$(dirname "$target")"
        cp "$origin" "$target"
    elif [[ -d "$origin" ]]; then
        if [[ -d "$target" ]]; then
            rm -rf "$target"
        fi

        mkdir -p "$(dirname "$target")"
        cp -r "$origin" "$target"
    fi
done

# Root password
echo "Setting up root password..."
echo "root:$root_password" | arch-chroot /mnt chpasswd

# User setup
echo "Setting up user..."
mkdir -p /mnt/etc/sudoers.d
echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$password" | arch-chroot /mnt chpasswd

# Install GRUB
if [[ -z "$grub_drive" ]]; then
    echo "GRUB drive is empty, skipping..."
else
    echo "Installing GRUB..."
    arch-chroot /mnt grub-install "$grub_drive"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi

# Create swapfile
if [[ "$swapfile_size" =~ ^[1-9][0-9]*$ ]]; then
    echo "Creating swapfile..."
    arch-chroot /mnt fallocate -l "${swapfile_size}"G /swapfile
    arch-chroot /mnt chmod 600 /swapfile
    arch-chroot /mnt mkswap /swapfile

    if ! arch-chroot /mnt grep -q '^/swapfile' /etc/fstab; then
        echo "/swapfile                                       none            swap            defaults        0 0" | arch-chroot /mnt tee -a /etc/fstab
    fi
else
    echo "Invalid swapfile size, skipping..."
fi

echo "Unmounting /mnt..."
umount -R /mnt

echo "Arch Linux successfully installed. Remove the installation media and reboot to continue."

exit 0

