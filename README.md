# **Custom Kali Linux ISO Builder – Advanced Edition**

> Build a **fully automated, weaponised Kali Linux ISO** with pre‑configured user accounts, massive tool arsenal, BlackArch integration, and an aggressive unattended installation preseed.  
> **For authorised penetration testing and red‑team operations only.**

---

## 📌 Overview

This project takes the official Kali Linux live‑build system and transforms it into a **turn‑key ISO factory**. It provides:

- A **bash build script** (`build_kali_pro.sh`) that:
  - Clones the Kali live‑build repository.
  - Downloads and injects an **advanced preseed.cfg** for unattended installation.
  - Adds **hundreds of tools**, including the **BlackArch repository**.
  - Installs extra Python packages and custom scripts (Firefox Decrypt, first‑boot setup).
  - Generates an ISO with your chosen username, password, and desktop environment.

- A **power‑user preseed.cfg** that:
  - Enables **root** with a strong password.
  - Grants **passwordless sudo** to the default user.
  - **Auto‑logs in** to the desktop (no login prompt).
  - **Enables SSH** and **disables the firewall** – instant remote access.
  - Uses **LVM** with separate `/home`, `/var`, and `/tmp` partitions.
  - Applies all post‑install tweaks via a single `late_command`.

The result is a **"most dangerous" Kali ISO** – ready to boot, install, and **start hacking within seconds**.

---

## ✨ Key Features

| Area | What’s Included |
|------|----------------|
| **User Experience** | Auto‑generated password (or user‑supplied), auto‑login, passwordless sudo, root enabled. |
| **Desktops** | Choose XFCE, GNOME, or KDE Plasma with `--desktop`. |
| **Tool Arsenal** | Metasploit, Nmap, BloodHound, Evil‑WinRM, Impacket, CrackMapExec, Responder, Bettercap, BeEF, Burp Suite, WPScan, and **BlackArch’s entire repository** (2000+ tools). |
| **Wordlists** | RockYou and SecLists downloaded on first boot – ready for cracking and fuzzing. |
| **Python Environment** | Pre‑installed: `requests`, `beautifulsoup4`, `paramiko`, `scapy`, `colorama`, `uploadserver`, plus `pycryptodome`. |
| **Custom Scripts** | Firefox Decrypt (`/opt/firefox_decrypt.py`) and a first‑boot orchestrator (`/opt/kali-startup.sh`). |
| **Aliases & Shortcuts** | Pre‑configured `.bashrc` with `scan`, `upweb`, `listen`, `pwn` and more. |
| **Remote Access** | SSH enabled, firewall disabled, auto‑started – connect immediately. |
| **Disk Layout** | LVM with separate `/boot`, `/`, `/home`, `/var`, `/tmp`, and swap – flexible and performant. |
| **Build Optimisations** | Caching, XZ compression, and `eatmydata` during installation for faster builds. |

---

## 📋 Prerequisites (Host System)

| Requirement | Minimum |
|-------------|---------|
| **OS** | Debian/Ubuntu/Kali (or any Debian‑based distro) |
| **Disk Space** | ≥ **25 GB** free |
| **RAM** | ≥ 4 GB (8+ GB recommended) |
| **Internet** | Fast, stable connection |
| **User** | `sudo` privileges |

---

## 🚀 Quick Start

### 1. Save the Build Script

Create a file named `build_kali_pro.sh` (you can copy the script from this repository or the provided code block) and make it executable:

```bash
chmod +x build_kali_pro.sh
```

### 2. (Optional) Prepare a Custom Tool List

Create a plain text file (e.g., `my_tools.txt`) with one package name per line. These will be appended to the default tool list.

```
# Example custom additions
cherrytree
ghidra
recon-ng
```

### 3. Build Your ISO

```bash
# Use defaults (username=kali, auto‑generated password, XFCE)
./build_kali_pro.sh

# Fully customised build
./build_kali_pro.sh \
    --username redteam \
    --password "MyC0mpl3xP@ss" \
    --fullname "Red Team Operator" \
    --desktop gnome \
    --tools my_tools.txt
```

The script will display the generated password (if not provided) and the final ISO path.

---

## 🧠 Command‑Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--username USER` | UNIX username | `kali` |
| `--password PASS` | User password. If omitted, a **secure 16‑character** password is generated and shown. | *(auto)* |
| `--fullname NAME` | Full name (used in preseed) | same as `username` |
| `--desktop TYPE` | Desktop: `xfce`, `gnome`, or `kde` | `xfce` |
| `--tools FILE` | Path to file with additional packages (one per line) | *(none)* |
| `--help` | Show usage | – |

> **Note:** If you don't supply a password, the script prints it once. **Save it immediately** – it won't be shown again.

---

## 🔧 Customisation Deep‑Dive

### The Build Script in Detail

The script does the following automatically:

1. **Installs dependencies** (`git`, `live-build`, `mkpasswd`, etc.).
2. **Clones** the official Kali live‑build repository.
3. **Downloads** our advanced `preseed.cfg` and replaces placeholders (`MY_FULLNAME`, `MY_USERNAME`, `MY_PASSWORD`) with your values.
4. **Adds custom files**:
   - Firefox Decrypt to `/opt`.
   - A first‑boot startup script (`kali-startup.sh`) that downloads wordlists and enables SSH.
5. **Integrates BlackArch** via `strap.sh`.
6. **Creates hooks** to install extra Python packages and merge custom `.bashrc` aliases.
7. **Extends the package list** with the default tools, your custom tools file, and a curated selection of BlackArch packages.
8. **Runs the build** with caching and compression optimisations.

### The Preseed Configuration

The preseed file (`preseed.cfg`) is the heart of unattended installation. Key decisions:

- **Root enabled** – root password set (default `toor` – **change it!**).
- **Default user** – created with hashed password, added to `sudo` group.
- **Late command** – executes after installation to:
  - Grant `NOPASSWD` sudo to the user.
  - Enable and start SSH.
  - Disable `ufw` (firewall).
  - Configure auto‑login for LightDM (used by XFCE).
  - Disable IPv6 (optional).
- **Partitioning** – uses LVM with separate `/boot`, `/`, `/home`, `/var`, `/tmp`, and swap.

You can customise the preseed further by editing the `PRESEED_URL` variable at the top of the script to point to your own file (or modify the downloaded file before build).

### Adding Your Own Tools

- **APT packages**: Add them to the `EXTRA_TOOLS` array in the script, or supply a file via `--tools`.
- **Python packages**: Edit the `EXTRA_PIP_PKGS` array.
- **BlackArch packages**: List them in your `--tools` file – they will be installed via `pacman`.

### Injecting Custom Scripts

Place any executable file in `kali-config/common/includes.chroot/opt/` – they will be copied to the ISO. To run them on first boot, add calls to `/opt/kali-startup.sh` (which is already triggered via `.bashrc`).

---

## 🔒 Security & Legal Warning

- **This ISO is designed for professional security testing in controlled environments.**
- **Unauthorised use** of the included tools (e.g., exploiting systems without permission) is **illegal** and **unethical**.
- The configuration **disables firewall, enables root, auto‑logs in, and grants passwordless sudo** – this is **extremely insecure** by design. **Do not** connect such a system to an untrusted network without additional protections.
- The generated password is printed in plaintext during the build – ensure your terminal logs are secure.

> **You are solely responsible for how you use this ISO.** The authors do not condone any malicious activity.

---

## 📂 Build Output

After a successful build (1–2 hours), the ISO will be located in the `kali-live-build-advanced/` directory, e.g.:

```
kali-live-build-advanced/kali-linux-2026.1-live-amd64.iso
```

The script outputs the full path and the password for the default user.

### Test with QEMU

```bash
qemu-system-x86_64 -cdrom /path/to/kali-linux-*.iso -m 4G -enable-kvm
```

---

## 🧹 Troubleshooting

| Issue | Solution |
|-------|----------|
| **Build fails with “No space left”** | Free at least 25 GB; use `df -h` to check. |
| **`mkpasswd` not found** | Install `whois` package: `sudo apt install whois`. |
| **BlackArch strap.sh fails** | Check network connectivity; retry the build. |
| **ISO doesn’t boot** | Ensure you’re on AMD64 hardware. The script builds for `amd64`. |
| **Auto‑login not working** | Verify LightDM is installed (XFCE uses it). If using GNOME/KDE, adjust the `late_command` accordingly. |
| **SSH not starting** | Check that `openssh-server` is in the package list; the `late_command` enables it. |
| **Root password not accepted** | The hash might be malformed – generate a new one and replace it in the preseed. |

---

## 📁 Project Structure (Inside Builder)

```
kali-live-build-advanced/
├── kali-config/
│   └── common/
│       ├── includes.installer/
│       │   └── preseed.cfg              # customised unattended install
│       ├── includes.chroot/
│       │   ├── opt/
│       │   │   ├── firefox_decrypt.py
│       │   │   └── kali-startup.sh
│       │   ├── etc/skel/                # skeleton .bashrc, etc.
│       │   └── root/
│       └── hooks/live/
│           ├── 00-add-blackarch-repo.hook.chroot
│           ├── 98-merge-bashrc.hook.chroot
│           └── 99-install-python-pkgs.hook.chroot
├── variant-light/
│   └── package-lists/
│       └── kali.list.chroot             # main package manifest
└── build.sh                             # Kali's official build script
```

---

## 🤝 Credits & Acknowledgements

- **Kali Linux** – the base distribution and live‑build framework.
- **BlackArch** – for their incredible penetration testing repository.
- **ChristElise** – original preseed.cfg template.
- **unode** – Firefox Decrypt script.
- **Open‑source community** – for the countless tools that make this possible.

---

## 📄 License

This project (the build script and accompanying files) is provided under the **MIT License**. The resulting ISO contains software under various open‑source licenses – refer to the Kali Linux and BlackArch documentation for specifics.

---

## 💬 Final Notes

- The script is **self‑documenting** – read the source to understand every detail.
- For frequent builds, consider mirroring the Kali and BlackArch repositories locally to save time and bandwidth.
- Always verify the integrity of downloaded packages and scripts.

**Happy (ethical) hacking!** 🐉
