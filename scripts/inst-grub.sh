#!/bin/bash

source $HOME/dotfiles/globals.sh

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# --- /etc/default/grub ---
# Remember last booted OS, show menu for 5s, flat menu (no submenu)
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
grep -q '^GRUB_SAVEDEFAULT=' /etc/default/grub \
    && sed -i 's/^GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' /etc/default/grub \
    || sed -i '/^GRUB_DEFAULT=/a GRUB_SAVEDEFAULT=true' /etc/default/grub

sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub

grep -q '^GRUB_DISABLE_SUBMENU=' /etc/default/grub \
    && sed -i 's/^GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/' /etc/default/grub \
    || sed -i '/^GRUB_TIMEOUT=/a GRUB_DISABLE_SUBMENU=y' /etc/default/grub

# --- Display "Linux Mint" in menu entries ---
cat > /etc/default/grub.d/60_linuxmint_name.cfg << 'EOF'
# Override the menu entry name to "Linux Mint" while keeping
# the EFI boot path as "ubuntu" (set in 50_linuxmint.cfg)
GRUB_DISTRIBUTOR="Linux Mint"
EOF

# --- Fix 10_linux to show clean name for Linux Mint ---
if ! grep -q '"Linux Mint"' /etc/grub.d/10_linux; then
    sed -i 's/Ubuntu|Kubuntu)/Ubuntu|Kubuntu|"Linux Mint")/' /etc/grub.d/10_linux
fi

# --- Fix 05_debian_theme to use dark theme for Linux Mint ---
if ! grep -q '"Linux Mint"' /etc/grub.d/05_debian_theme; then
    sed -i 's/Tanglu|Ubuntu|Kubuntu)/Tanglu|Ubuntu|Kubuntu|"Linux Mint")/' /etc/grub.d/05_debian_theme
fi

# --- Windows 11 custom entry ---
# Detect Windows EFI partition UUID
WIN_UUID=$(grub-probe --target=fs_uuid /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi 2>/dev/null)

if [ -n "$WIN_UUID" ]; then
    cat > /etc/grub.d/40_custom << EOF
#!/bin/sh
exec tail -n +3 \$0
# Custom menu entries

menuentry "Windows 11" --class windows --class os \$menuentry_id_option 'osprober-efi-${WIN_UUID}' {
	insmod part_gpt
	insmod fat
	search --no-floppy --fs-uuid --set=root ${WIN_UUID}
	chainloader /efi/Microsoft/Boot/bootmgfw.efi
}
EOF
    chmod +x /etc/grub.d/40_custom

    # Skip auto-detected Windows entry to avoid duplicate
    if ! grep -q 'GRUB_OS_PROBER_SKIP_LIST' /etc/default/grub.d/50_linuxmint.cfg 2>/dev/null; then
        echo "GRUB_OS_PROBER_SKIP_LIST=\"${WIN_UUID}@/efi/Microsoft/Boot/bootmgfw.efi\"" \
            >> /etc/default/grub.d/50_linuxmint.cfg
    else
        sed -i "s|^GRUB_OS_PROBER_SKIP_LIST=.*|GRUB_OS_PROBER_SKIP_LIST=\"${WIN_UUID}@/efi/Microsoft/Boot/bootmgfw.efi\"|" \
            /etc/default/grub.d/50_linuxmint.cfg
    fi
    echo "Windows 11 entry configured (EFI UUID: $WIN_UUID)"
else
    echo "Windows EFI not found, skipping Windows entry"
fi

update-grub
echo "GRUB configured successfully"
