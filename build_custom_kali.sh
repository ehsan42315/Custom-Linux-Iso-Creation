#!/bin/bash
set -euo pipefail
trap 'echo -e "\n[!] Build interrupted. Cleaning up..."; cd "$START_DIR" 2>/dev/null; rm -rf "$BUILD_DIR" 2>/dev/null; exit 1' INT TERM

# ------------------------------------------------------------
# Configuration & defaults
# ------------------------------------------------------------
START_DIR="$(pwd)"
BUILD_DIR="kali-live-build-advanced"
KALI_REPO="https://gitlab.com/kalilinux/build-scripts/live-build-config.git"
PRESEED_URL="https://raw.githubusercontent.com/ChristElise/Custom-Linux-Iso-Creation/main/preseed.cfg"
FIREFOX_DECRYPT_URL="https://raw.githubusercontent.com/unode/firefox_decrypt/main/firefox_decrypt.py"

DESKTOP="xfce"          # default: xfce, gnome, kde
FULLNAME=""
USERNAME="kali"
PASSWORD=""
TOOLS_FILE=""           # optional path to custom tool list
EXTRA_PIP_PKGS=("requests" "beautifulsoup4" "paramiko" "scapy" "colorama" "uploadserver")
EXTRA_TOOLS=(
    "metasploit-framework" "python3-pip" "python3" "ffuf"
    "nmap" "hydra" "john" "aircrack-ng" "wireshark" "sqlmap"
    "bloodhound" "evil-winrm" "impacket-scripts" "crackmapexec"
    "exploitdb" "seclists" "gobuster" "nikto" "proxychains"
    "enum4linux" "smbclient" "samba" "ldap-utils" "snmp"
)
BLACKARCH_REPO="https://github.com/BlackArch/blackarch.git"

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build a custom Kali Linux ISO with advanced tooling.

Options:
  --username USER    Set the default username (default: kali)
  --password PASS    Set password (if not given, a secure one is generated)
  --fullname NAME    Set the user's full name (default: empty)
  --desktop TYPE     Desktop environment: xfce, gnome, kde (default: xfce)
  --tools FILE       Path to a file with additional package names (one per line)
  --help             Show this help message

Examples:
  $0 --username hacker --password s3cr3t --fullname "Jane Doe" --desktop gnome
  $0 --tools my-tools.txt
EOF
    exit 0
}

generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()_+' </dev/urandom | head -c 16 || true
}

log() {
    echo "[*] $*"
}

error() {
    echo "[!] $*" >&2
    exit 1
}

# ------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --username) USERNAME="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --fullname) FULLNAME="$2"; shift 2 ;;
        --desktop)  DESKTOP="$2";  shift 2 ;;
        --tools)    TOOLS_FILE="$2"; shift 2 ;;
        --help)     usage ;;
        *) error "Unknown option: $1" ;;
    esac
done

if [[ -z "$PASSWORD" ]]; then
    PASSWORD="$(generate_password)"
    log "Generated password: $PASSWORD (save this!)"
fi

if [[ -z "$FULLNAME" ]]; then
    FULLNAME="$USERNAME"
fi

case "$DESKTOP" in
    xfce|gnome|kde) ;;
    *) error "Desktop must be one of: xfce, gnome, kde" ;;
esac

log "Configuration:"
log "  Username: $USERNAME"
log "  Fullname: $FULLNAME"
log "  Desktop: $DESKTOP"
log "  Password: [hidden]"

# ------------------------------------------------------------
# Install host dependencies
# ------------------------------------------------------------
log "Updating system and installing required packages..."
sudo apt update -y
sudo apt install -y git live-build simple-cdd cdebootstrap curl mkpasswd \
    wget xorriso squashfs-tools zip unzip

# ------------------------------------------------------------
# Clone Kali live‑build repository
# ------------------------------------------------------------
if [[ -d "$BUILD_DIR" ]]; then
    log "Removing existing build directory..."
    rm -rf "$BUILD_DIR"
fi
git clone "$KALI_REPO" "$BUILD_DIR"
cd "$BUILD_DIR"

# ------------------------------------------------------------
# Prepare customisation directories
# ------------------------------------------------------------
mkdir -p kali-config/common/includes.installer
mkdir -p kali-config/common/includes.chroot/opt
mkdir -p kali-config/common/hooks/live
mkdir -p kali-config/common/includes.chroot/etc/skel/Desktop
mkdir -p kali-config/common/includes.chroot/root

# ------------------------------------------------------------
# Download and customise preseed.cfg
# ------------------------------------------------------------
log "Fetching and customising preseed.cfg..."
wget -q "$PRESEED_URL" -O kali-config/common/includes.installer/preseed.cfg
sed -i "s/MY_FULLNAME/$FULLNAME/g" kali-config/common/includes.installer/preseed.cfg
sed -i "s/MY_USERNAME/$USERNAME/g" kali-config/common/includes.installer/preseed.cfg
HASHED_PASS="$(mkpasswd -m sha-512 "$PASSWORD")"
sed -i "s|MY_PASSWORD|$HASHED_PASS|g" kali-config/common/includes.installer/preseed.cfg

# ------------------------------------------------------------
# Add custom scripts (Firefox Decrypt, plus a custom helper)
# ------------------------------------------------------------
log "Downloading Firefox Decrypt..."
wget -q "$FIREFOX_DECRYPT_URL" -O kali-config/common/includes.chroot/opt/firefox_decrypt.py

cat <<'EOF' > kali-config/common/includes.chroot/opt/kali-startup.sh
#!/bin/bash
# Custom startup script – runs on first boot
echo "Kali Pro – ready for action!" > /etc/motd
# Example: enable SSH
systemctl enable ssh
systemctl start ssh
# Download common wordlists if missing
if [[ ! -f /usr/share/wordlists/rockyou.txt ]]; then
    wget -q https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt -O /usr/share/wordlists/rockyou.txt
fi
if [[ ! -d /usr/share/seclists ]]; then
    git clone https://github.com/danielmiessler/SecLists.git /usr/share/seclists
fi
EOF
chmod +x kali-config/common/includes.chroot/opt/kali-startup.sh

# Make it run on first boot via .profile or systemd (simple: add to .bashrc)
cat <<'EOF' > kali-config/common/includes.chroot/etc/skel/.bashrc.append
# Run custom startup once
if [[ ! -f ~/.kali_pro_first_run ]]; then
    /opt/kali-startup.sh
    touch ~/.kali_pro_first_run
fi
EOF
# Append to existing .bashrc (we'll use a hook to merge)

# ------------------------------------------------------------
# Add BlackArch repository (extra danger)
# ------------------------------------------------------------
log "Integrating BlackArch repository..."
cat <<'EOF' > kali-config/common/hooks/live/00-add-blackarch-repo.hook.chroot
#!/bin/bash
curl -s https://blackarch.org/strap.sh | bash
EOF
chmod 755 kali-config/common/hooks/live/00-add-blackarch-repo.hook.chroot

# ------------------------------------------------------------
# Install extra Python packages
# ------------------------------------------------------------
log "Creating Python package install hook..."
{
    echo '#!/bin/bash'
    echo 'pip3 install '"${EXTRA_PIP_PKGS[*]}"
    echo 'pip3 install --upgrade pycryptodome'  # sometimes needed
} > kali-config/common/hooks/live/99-install-python-pkgs.hook.chroot
chmod 755 kali-config/common/hooks/live/99-install-python-pkgs.hook.chroot

# ------------------------------------------------------------
# Customise package lists
# ------------------------------------------------------------
log "Adding extra tools to the package list..."
KALI_LIST="kali-config/variant-light/package-lists/kali.list.chroot"
mkdir -p "$(dirname "$KALI_LIST")"

# Start with default Kali tools (light) but we'll append our extras
# We'll actually overwrite the whole list to ensure we have a minimal base + extras.
cat > "$KALI_LIST" <<EOF
# Base Kali light packages
kali-linux-headless
kali-linux-core
kali-desktop-$DESKTOP
# Additional tools
${EXTRA_TOOLS[*]}
EOF

# If user provided a tools file, append it
if [[ -n "$TOOLS_FILE" && -f "$TOOLS_FILE" ]]; then
    log "Appending tools from $TOOLS_FILE..."
    cat "$TOOLS_FILE" >> "$KALI_LIST"
fi

# Add BlackArch tools (they will be installed via the repo hook, but we can also
# request specific BlackArch packages – we'll just install the whole blackarch group? 
# That might be too heavy. Instead, we'll let user decide via TOOLS_FILE.
# We'll include a few popular BlackArch tools.
cat <<'EOF' >> "$KALI_LIST"
# BlackArch tools (some popular ones)
bettercap
beef-xss
burpsuite
ew
hydra
john
metasploit
nmap
sqlmap
wpscan
aircrack-ng
responder
impacket
crackmapexec
bloodhound
evil-winrm
EOF

# ------------------------------------------------------------
# Additional hooks: copy custom bashrc, aliases, desktop icons
# ------------------------------------------------------------
log "Adding custom .bashrc and aliases..."
cat <<'EOF' > kali-config/common/includes.chroot/etc/skel/.bashrc_custom
# Kali Pro aliases
alias ll='ls -la'
alias scan='nmap -sV -sC -O'
alias upweb='python3 -m uploadserver 8000'
alias listen='nc -lvnp'
alias pwn='echo "Ready to pwn!"'
export PATH=$PATH:/opt
EOF
# We'll merge via hook:
cat <<'EOF' > kali-config/common/hooks/live/98-merge-bashrc.hook.chroot
#!/bin/bash
# Append custom aliases to default .bashrc
cat /etc/skel/.bashrc_custom >> /etc/skel/.bashrc
cat /root/.bashrc_custom >> /root/.bashrc 2>/dev/null || true
EOF
chmod 755 kali-config/common/hooks/live/98-merge-bashrc.hook.chroot

# Also copy the .bashrc_custom to root and skel
cp kali-config/common/includes.chroot/etc/skel/.bashrc_custom kali-config/common/includes.chroot/root/.bashrc_custom

# ------------------------------------------------------------
# Build the ISO with optimizations
# ------------------------------------------------------------
log "Starting ISO build (this will take a while)..."
./build.sh --variant light --verbose --arch amd64 --distribution kali-rolling \
           --cache --compression xz

# ------------------------------------------------------------
# Finalise
# ------------------------------------------------------------
cd "$START_DIR"
ISO_PATH=$(find "$BUILD_DIR" -name "*.iso" -type f | head -n1)
if [[ -f "$ISO_PATH" ]]; then
    log "Build successful! ISO created at: $ISO_PATH"
    log "Password for user '$USERNAME' is: $PASSWORD"
    log "You can test it with: qemu-system-x86_64 -cdrom $ISO_PATH -m 4G"
else
    error "ISO not found; build may have failed."
fi

log "Done."
