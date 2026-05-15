#!/bin/bash

################################################################################
# Ham Radio Package Installer
# Version 1.0.1  (2026-05-15)
# For Ubuntu 26.04 "Resolute Raccoon" only
################################################################################

VERSION="1.0.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# XDG directories
APPS_DIR="$HOME/.local/share/applications"
DIRS_DIR="$HOME/.local/share/desktop-directories"

################################################################################
# Desktop menu helpers
################################################################################

install_desktop_directories() {
    mkdir -p "$APPS_DIR" "$DIRS_DIR"

    write_dir_file() {
        cat > "$DIRS_DIR/$1" <<EOF
[Desktop Entry]
Type=Directory
Name=$2
Icon=$3
Comment=$4
EOF
    }

    write_dir_file "hamradio.directory"          "Ham Radio"        "applications-hamradio"   "Amateur radio applications"
    write_dir_file "hamradio-digitalmodes.directory" "Digital Modes" "network-wireless"        "FT8, PSK, SSTV, etc."
    write_dir_file "hamradio-logging.directory"  "Logging"          "x-office-address-book"   "QSO logging applications"
    write_dir_file "hamradio-sdr.directory"      "SDR"              "audio-input-microphone"  "Software Defined Radio"
    write_dir_file "hamradio-aprs.directory"     "APRS"             "network-transmit-receive" "APRS and packet radio"
    write_dir_file "hamradio-satellite.directory" "Satellite"       "weather-clear-night"     "Satellite tracking"
    write_dir_file "hamradio-winlink.directory"  "Winlink"          "mail-send-receive"       "Winlink email over radio"
    write_dir_file "hamradio-antenna.directory"  "Antenna Modeling" "applications-engineering" "Antenna design and modeling"
    write_dir_file "hamradio-morse.directory"    "Morse Code"       "audio-speakers"          "Morse code training and tools"
    write_dir_file "hamradio-utilities.directory" "Utilities"       "applications-utilities"  "General ham radio utilities"

    xdg-desktop-menu install --novendor \
        "$DIRS_DIR/hamradio.directory" \
        "$DIRS_DIR/hamradio-digitalmodes.directory" \
        "$DIRS_DIR/hamradio-logging.directory" \
        "$DIRS_DIR/hamradio-sdr.directory" \
        "$DIRS_DIR/hamradio-aprs.directory" \
        "$DIRS_DIR/hamradio-satellite.directory" \
        "$DIRS_DIR/hamradio-winlink.directory" \
        "$DIRS_DIR/hamradio-antenna.directory" \
        "$DIRS_DIR/hamradio-morse.directory" \
        "$DIRS_DIR/hamradio-utilities.directory" \
        2>/dev/null || true

    log_info "Desktop menu groups created."
}

# Write a .desktop file and register it.
# Usage: write_desktop <filename> <Name> <Comment> <Exec> <Icon> <Categories> [Terminal=true|false]
write_desktop() {
    local file="$APPS_DIR/$1"
    local terminal="${7:-false}"
    mkdir -p "$APPS_DIR"
    cat > "$file" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Comment=$3
Exec=$4
Icon=$5
Terminal=${terminal}
Categories=$6
EOF
    xdg-desktop-menu install --novendor "$file" 2>/dev/null || true
}

# Patch an installed package's .desktop into our menu group.
# Usage: adopt_desktop <search-name> <output-filename> <Categories>
# Looks in /usr/share/applications first, then ~/.local/share/applications.
# Falls back to write_desktop arguments 4..6 if a caller provides them.
adopt_desktop() {
    local search="$1"
    local outfile="$2"
    local categories="$3"

    # Search common locations for an existing .desktop by substring
    local src
    src=$(find /usr/share/applications "$APPS_DIR" \
              -iname "*${search}*.desktop" 2>/dev/null | head -1)

    if [ -n "$src" ] && [ "$src" != "$APPS_DIR/$outfile" ]; then
        cp "$src" "$APPS_DIR/$outfile"
        sed -i "s|^Categories=.*|Categories=${categories}|" "$APPS_DIR/$outfile"
        xdg-desktop-menu install --novendor "$APPS_DIR/$outfile" 2>/dev/null || true
        return 0
    fi
    return 1   # caller should fall back to write_desktop
}

################################################################################
# Package helpers
################################################################################

package_exists() { apt-cache show "$1" &>/dev/null; }

# Install package and always write a desktop entry into our menu.
# Usage: safe_install <pkg> <display-name> <exec> <icon> <categories> [terminal] [comment]
safe_install() {
    local package="$1"
    local display_name="${2:-$1}"
    local exec_cmd="${3:-$1}"
    local icon="${4:-applications-utilities}"
    local categories="${5:-X-HamRadio;X-HamRadio-Utilities;}"
    local terminal="${6:-false}"
    local comment="${7:-$display_name}"

    if ! package_exists "$package"; then
        log_warn "$display_name ($package) not available in repositories"
        return 1
    fi

    if ! sudo apt install -y "$package" 2>/dev/null; then
        log_warn "Failed to install $display_name ($package)"
        return 1
    fi

    log_info "$display_name installed!"

    # Try to adopt the package's own .desktop; if none exists, create one.
    if ! adopt_desktop "$package" "${package}.desktop" "$categories"; then
        write_desktop "${package}.desktop" \
            "$display_name" "$comment" \
            "$exec_cmd" "$icon" "$categories" "$terminal"
    fi
    return 0
}

################################################################################
# Pre-flight checks
################################################################################

if [[ $EUID -eq 0 ]]; then
    log_error "Do not run as root. Run as a regular user with sudo privileges."
    exit 1
fi

# Accept Ubuntu 24.04, 25.x, or 26.04 "Resolute Raccoon"
if ! grep -qE "(26\.04|resolute)" /etc/os-release; then
    log_warn "This script is designed for Ubuntu 26.04 (Resolute Raccoon) only."
    read -p "Continue anyway? (y/N) " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Detect distro codename for repository entries
UBUNTU_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
log_info "Detected Ubuntu codename: $UBUNTU_CODENAME"

################################################################################
# User info
################################################################################

log_info "Getting user information..."
read -p "Enter your ham radio callsign: "    CALLSIGN
read -p "Enter your handle/name: "           FULL_NAME
read -p "Enter your grid square (e.g. JO22): " GRID_SQUARE
CALLSIGN=${CALLSIGN^^}
log_info "Callsign: $CALLSIGN  |  Name: $FULL_NAME  |  Grid: $GRID_SQUARE"

################################################################################
# Menu
################################################################################

show_menu() {
    clear
    echo "================================================"
    echo "   Ham Radio Software Installer v${VERSION}"
    echo "   Ubuntu ${UBUNTU_CODENAME} edition"
    echo "================================================"
    echo "Callsign: $CALLSIGN | Grid: $GRID_SQUARE"
    echo "================================================"
    echo ""
    echo "1.  Install ALL packages (recommended first-time setup)"
    echo "2.  System preparation & core utilities"
    echo "3.  Digital modes (WSJT-X, JS8Call, FLDigi suite)"
    echo "4.  APRS applications (Xastir, Direwolf, YAAC)"
    echo "5.  Logging applications (CQRLOG, KLog, TrustedQSL)"
    echo "6.  SDR applications (GQRX, CubicSDR, SDRAngel)"
    echo "7.  Morse code applications"
    echo "8.  Antenna modeling (NEC2, Yagiuda)"
    echo "9.  Winlink (Pat Winlink with ARDOP)"
    echo "10. Satellite tracking (Gpredict)"
    echo "11. General ham radio utilities"
    echo "12. Install HamClock"
    echo "13. Install DX Spider Cluster server"
    echo "14. Install VarAC (Wine-based chat over VARA)"
    echo "15. Install D-Rats (D-STAR data communications)"
    echo "16. Install voacapl + pythonprop (HF propagation)"
    echo ""
    echo "0.  Exit"
    echo ""
    read -p "Enter your choice [0-16]: " choice
}

################################################################################
# 2. System preparation
################################################################################

install_system_prep() {
    log_info "Installing system dependencies and core utilities..."
    sudo apt update

    # Build tools
    sudo apt install -y \
        build-essential cmake git wget curl ca-certificates gnupg \
        software-properties-common dkms "linux-headers-$(uname -r)" \
        pkg-config autoconf automake autoconf-archive libtool gfortran \
        xdg-utils || true

    # Python — 26.04 ships Python 3.13; use system packages, avoid bare pip
    sudo apt install -y \
        python3 python3-pip python3-dev python3-setuptools python3-wheel \
        python3-venv python3-numpy python3-scipy python3-serial \
        python3-requests python3-yaml || true

    # Audio / RF libraries
    # Note: libasound2-dev is renamed to libasound2-dev on 26.04 (same name,
    # but the underlying ALSA package may be libasound2t64 on some builds)
    sudo apt install -y \
        libusb-1.0-0-dev libssl-dev libfftw3-dev libsamplerate0-dev \
        libpulse-dev portaudio19-dev libasound2-dev libsndfile1-dev \
        libxml2-dev libxslt1-dev \
        libhamlib-dev libhamlib4t64 libhamlib-utils 2>/dev/null || \
    sudo apt install -y \
        libusb-1.0-0-dev libssl-dev libfftw3-dev libsamplerate0-dev \
        libpulse-dev portaudio19-dev libasound2-dev libsndfile1-dev \
        libxml2-dev libxslt1-dev \
        libhamlib-dev libhamlib4 libhamlib-utils || true

    # GUI toolkits — Qt6 is default on 26.04; keep Qt5 as fallback
    sudo apt install -y libgtk-3-dev 2>/dev/null || true
    sudo apt install -y \
        qt6-base-dev qt6-tools-dev qt6-multimedia-dev 2>/dev/null || \
    sudo apt install -y \
        qtbase5-dev qttools5-dev qtmultimedia5-dev 2>/dev/null || true

    install_desktop_directories

    log_info "System preparation complete!"
}

################################################################################
# 3. Digital modes
################################################################################

install_gridtracker() {
    log_info "Installing GridTracker..."

    # GridTracker needs Node.js ≥ 20
    local node_ok=false
    if command -v node &>/dev/null; then
        local node_major
        node_major=$(node -e "process.stdout.write(process.version.slice(1).split('.')[0])" 2>/dev/null)
        [[ "$node_major" =~ ^[0-9]+$ ]] && (( node_major >= 20 )) && node_ok=true
    fi
    if ! $node_ok; then
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
            sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
        echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | \
            sudo tee /etc/apt/sources.list.d/nodesource.list
        sudo apt update
        sudo apt install -y nodejs
    fi
    log_info "Node.js: $(node --version)"

    cd /tmp
    ARCH=$(dpkg --print-architecture)
    case "$ARCH" in
        amd64)        GT_PACKAGE="GridTracker2-2.250914.1-amd64.deb" ;;
        arm64)        GT_PACKAGE="GridTracker2-2.250914.1-arm64.deb" ;;
        armhf|armv7l) GT_PACKAGE="GridTracker2-2.250914.1-armv7l.deb" ;;
        *)
            log_warn "GridTracker not available for architecture: $ARCH"
            return 0 ;;
    esac

    if wget -q --show-progress "https://download2.gridtracker.org/${GT_PACKAGE}" 2>/dev/null; then
        sudo dpkg -i "${GT_PACKAGE}" 2>/dev/null || sudo apt --fix-broken install -y
        rm -f "${GT_PACKAGE}"
        if ! adopt_desktop "gridtracker" "gridtracker.desktop" \
                "X-HamRadio;X-HamRadio-DigitalModes;"; then
            write_desktop "gridtracker.desktop" \
                "GridTracker" "Live amateur radio map and statistics" \
                "gridtracker" "network-wireless" \
                "X-HamRadio;X-HamRadio-DigitalModes;"
        fi
        log_info "GridTracker installed!"
    else
        log_warn "GridTracker download failed. Manual: https://gridtracker.org/index.php/downloads/"
    fi
}

install_js8call() {
    log_info "Installing JS8Call..."

    if safe_install "js8call" "JS8Call" "js8call" \
            "applications-internet" "X-HamRadio;X-HamRadio-DigitalModes;"; then
        return 0
    fi

    log_info "JS8Call not in repos — trying GitHub release..."
    cd /tmp
    ARCH=$(dpkg --print-architecture)
    JS8_VERSION=$(curl -s https://api.github.com/repos/js8call/js8call/releases/latest \
        | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)
    [ -z "$JS8_VERSION" ] && { log_warn "Cannot determine JS8Call version."; return 0; }

    case "$ARCH" in
        amd64) JS8_PACKAGE="js8call_${JS8_VERSION}_amd64.deb" ;;
        armhf) JS8_PACKAGE="js8call_${JS8_VERSION}_armhf.deb" ;;
        *)     log_warn "JS8Call not available for $ARCH"; return 0 ;;
    esac

    if wget -q --show-progress \
            "https://github.com/js8call/js8call/releases/download/v${JS8_VERSION}/${JS8_PACKAGE}" \
            2>/dev/null; then
        sudo dpkg -i "${JS8_PACKAGE}" 2>/dev/null || sudo apt --fix-broken install -y
        rm -f "${JS8_PACKAGE}"
        write_desktop "js8call.desktop" \
            "JS8Call" "JS8 keyboard-to-keyboard messaging" \
            "js8call" "applications-internet" "X-HamRadio;X-HamRadio-DigitalModes;"
        log_info "JS8Call installed!"
    else
        log_warn "JS8Call download failed. Manual: https://github.com/js8call/js8call/releases"
    fi
}

install_flarq() {
    log_info "Installing FLArq..."

    if safe_install "flarq" "FLArq" "flarq" \
            "applications-internet" "X-HamRadio;X-HamRadio-DigitalModes;"; then
        return 0
    fi

    log_info "FLArq not in repos — building from source..."
    sudo apt install -y \
        libfltk1.3-dev libsndfile1-dev libsamplerate0-dev libpulse-dev \
        libasound2-dev portaudio19-dev libhamlib-dev libudev-dev \
        libxi-dev libxfixes-dev libxft-dev libxinerama-dev libxcursor-dev || true

    cd /tmp
    FLARQ_VERSION=$(curl -s "https://sourceforge.net/projects/flarq/files/" \
        | grep -oP 'flarq-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)
    [ -z "$FLARQ_VERSION" ] && FLARQ_VERSION="4.3.9"

    FLARQ_TARBALL="flarq-${FLARQ_VERSION}.tar.gz"
    if wget -q --show-progress -O "${FLARQ_TARBALL}" \
            "https://sourceforge.net/projects/flarq/files/flarq-${FLARQ_VERSION}/${FLARQ_TARBALL}/download" \
            2>/dev/null; then
        tar -xzf "${FLARQ_TARBALL}"
        cd "flarq-${FLARQ_VERSION}"
        ./configure --prefix=/usr/local 2>/dev/null && \
            make -j"$(nproc)" 2>/dev/null && \
            sudo make install 2>/dev/null || { log_warn "FLArq build failed"; return 1; }
        cd /tmp; rm -rf "flarq-${FLARQ_VERSION}" "${FLARQ_TARBALL}"
        write_desktop "flarq.desktop" \
            "FLArq" "ARQ file transfer for FLDigi" \
            "flarq" "applications-internet" "X-HamRadio;X-HamRadio-DigitalModes;"
        log_info "FLArq built and installed!"
    else
        log_warn "FLArq download failed. Manual: https://sourceforge.net/projects/flarq/files/"
    fi
}

install_digital_modes() {
    log_info "Installing digital mode applications..."

    # WSJT-X — package may be wsjtx or wsjt-x on 26.04
    if ! safe_install "wsjtx" "WSJT-X" "wsjtx" \
            "network-wireless" "X-HamRadio;X-HamRadio-DigitalModes;"; then
        safe_install "wsjt-x" "WSJT-X" "wsjtx" \
            "network-wireless" "X-HamRadio;X-HamRadio-DigitalModes;" || true
    fi

    # JTDX
    safe_install "jtdx" "JTDX" "jtdx" \
        "network-wireless" "X-HamRadio;X-HamRadio-DigitalModes;" || true

    install_js8call  || true
    install_gridtracker || true

    log_info "Installing FLDigi suite..."
    # flrig2 may replace flrig on 26.04
    for pkg in fldigi flmsg flamp; do
        safe_install "$pkg" "$pkg" "$pkg" \
            "network-wireless" "X-HamRadio;X-HamRadio-DigitalModes;" || true
    done
    if ! safe_install "flrig" "FLRig" "flrig" \
            "network-wireless" "X-HamRadio;X-HamRadio-DigitalModes;"; then
        safe_install "flrig2" "FLRig" "flrig2" \
            "network-wireless" "X-HamRadio;X-HamRadio-DigitalModes;" || true
    fi

    install_flarq || true

    safe_install "xlog"  "XLog"  "xlog"  "x-office-address-book" "X-HamRadio;X-HamRadio-DigitalModes;" || true
    safe_install "qsstv" "QSSTV" "qsstv" "network-wireless"       "X-HamRadio;X-HamRadio-DigitalModes;" || true

    log_info "Digital modes installation complete!"
}

################################################################################
# 4. APRS
################################################################################

install_aprs() {
    log_info "Installing APRS applications..."

    safe_install "xastir"   "Xastir"    "xastir"   "network-transmit-receive" "X-HamRadio;X-HamRadio-APRS;" || true
    safe_install "direwolf" "Direwolf"  "direwolf" "network-transmit-receive" "X-HamRadio;X-HamRadio-APRS;" || true
    safe_install "aprx"     "APRx"      "aprx"     "network-transmit-receive" "X-HamRadio;X-HamRadio-APRS;" || true
    safe_install "aprsdigi" "APRS Digi" "aprsdigi" "network-transmit-receive" "X-HamRadio;X-HamRadio-APRS;" || true

    # Java needed by YAAC; prefer default-jre-headless on 26.04 (OpenJDK 23+)
    sudo apt install -y default-jre-headless 2>/dev/null || \
    sudo apt install -y default-jre || true

    log_info "APRS applications installed!"
}

################################################################################
# 5. Logging
################################################################################

install_logging() {
    log_info "Installing logging applications..."

    safe_install "cqrlog"     "CQRLOG"     "cqrlog"     "x-office-address-book" "X-HamRadio;X-HamRadio-Logging;" || true
    safe_install "klog"       "KLog"       "klog"       "x-office-address-book" "X-HamRadio;X-HamRadio-Logging;" || true
    safe_install "trustedqsl" "TrustedQSL" "tqsl"       "x-office-address-book" "X-HamRadio;X-HamRadio-Logging;" || true
    safe_install "pyqso"      "PyQSO"      "pyqso"      "x-office-address-book" "X-HamRadio;X-HamRadio-Logging;" || true
    safe_install "tlf"        "TLF"        "tlf"        "x-office-address-book" "X-HamRadio;X-HamRadio-Logging;" true || true

    log_info "Logging applications installed!"
}

################################################################################
# 6. SDR
################################################################################

install_sdr() {
    log_info "Installing SDR applications and drivers..."

    sudo apt install -y soapysdr-tools soapysdr-module-all 2>/dev/null || \
    sudo apt install -y soapysdr-tools || true

    sudo apt install -y rtl-sdr librtlsdr-dev || true
    sudo usermod -a -G plugdev "$USER"

    # gqrx may be gqrx-sdr on 26.04
    if ! safe_install "gqrx-sdr" "GQRX" "gqrx" \
            "audio-input-microphone" "X-HamRadio;X-HamRadio-SDR;"; then
        safe_install "gqrx" "GQRX" "gqrx" \
            "audio-input-microphone" "X-HamRadio;X-HamRadio-SDR;" || true
    fi

    safe_install "cubicsdr" "CubicSDR" "cubicsdr" \
        "audio-input-microphone" "X-HamRadio;X-HamRadio-SDR;" || true
    safe_install "quisk"    "Quisk"    "quisk"    \
        "audio-input-microphone" "X-HamRadio;X-HamRadio-SDR;" || true
    safe_install "cutesdr"  "CuteSDR"  "cutesdr"  \
        "audio-input-microphone" "X-HamRadio;X-HamRadio-SDR;" || true

    log_info "SDR applications installed!"
    log_warn "Log out and back in for USB/plugdev permissions to take effect."
    log_info "SDRPlay drivers: https://www.sdrplay.com/downloads/"
}

################################################################################
# 7. Morse
################################################################################

install_morse() {
    log_info "Installing Morse code applications..."

    safe_install "aldo"       "Aldo"        "aldo"       "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "cw"         "CW"          "cw"         "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "cwcp"       "CWCP"        "cwcp"       "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "xcwcp"      "XCWCP"       "xcwcp"      "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" || true
    safe_install "morse"      "Morse"       "morse"      "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "morse2ascii" "Morse2ASCII" "morse2ascii" "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "morsegen"   "MorseGen"    "morsegen"   "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "qrq"        "QRQ"         "qrq"        "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" true || true
    safe_install "xdemorse"   "Xdemorse"    "xdemorse"   "audio-speakers" "X-HamRadio;X-HamRadio-Morse;" || true

    log_info "Morse code applications installed!"
}

################################################################################
# 8. Antenna modeling
################################################################################

install_antenna_modeling() {
    log_info "Installing antenna modeling software..."

    safe_install "nec2c"   "NEC2c"   "nec2c"   "applications-engineering" "X-HamRadio;X-HamRadio-Antenna;" true || true
    safe_install "xnec2c"  "XNEC2c"  "xnec2c"  "applications-engineering" "X-HamRadio;X-HamRadio-Antenna;" || true
    safe_install "yagiuda" "Yagiuda" "yagiuda" "applications-engineering" "X-HamRadio;X-HamRadio-Antenna;" true || true

    log_info "Antenna modeling software installed!"
}

################################################################################
# 9. Winlink / ARDOP
################################################################################

install_ardop() {
    log_info "Installing ardopcf (ARDOP TNC)..."
    sudo apt install -y libasound2-dev libpulse-dev portaudio19-dev || true

    cd /tmp
    ARCH=$(dpkg --print-architecture)
    ARDOP_VERSION=$(curl -s https://api.github.com/repos/pflarue/ardop/releases/latest \
        | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)
    [ -z "$ARDOP_VERSION" ] && ARDOP_VERSION="1.0.4.1.3"

    case "$ARCH" in
        amd64) ARDOP_BIN="ardopcf_amd64_Linux_64" ;;
        arm64) ARDOP_BIN="ardopcf_arm_Linux_64"   ;;
        armhf) ARDOP_BIN="ardopcf_arm_Linux_32"   ;;
        *)     ARDOP_BIN="" ;;
    esac

    local INSTALLED=false
    if [ -n "$ARDOP_BIN" ]; then
        if wget -q --show-progress -O ardopcf \
                "https://github.com/pflarue/ardop/releases/download/v${ARDOP_VERSION}/${ARDOP_BIN}" \
                2>/dev/null; then
            chmod +x ardopcf
            sudo mv ardopcf /usr/local/bin/ardopcf
            sudo ln -sf /usr/local/bin/ardopcf /usr/local/bin/ardopc
            INSTALLED=true
            log_info "ardopcf binary installed."
        fi
    fi

    if [ "$INSTALLED" = false ]; then
        log_info "Building ardopcf from source..."
        sudo apt install -y git build-essential cmake || { log_warn "Build deps failed"; return 1; }
        rm -rf /tmp/ardop
        git clone --depth=1 https://github.com/pflarue/ardop.git /tmp/ardop 2>/dev/null || return 1
        cd /tmp/ardop
        if [ -f CMakeLists.txt ]; then
            mkdir -p build && cd build
            cmake .. -DCMAKE_BUILD_TYPE=Release 2>/dev/null && \
                make -j"$(nproc)" 2>/dev/null && \
                sudo cmake --install . 2>/dev/null && INSTALLED=true
            cd /tmp
        else
            make -j"$(nproc)" 2>/dev/null && \
                sudo install -m 755 ardopcf /usr/local/bin/ardopcf && \
                sudo ln -sf /usr/local/bin/ardopcf /usr/local/bin/ardopc && \
                INSTALLED=true
            cd /tmp
        fi
        rm -rf /tmp/ardop
    fi

    [ "$INSTALLED" = false ] && { log_warn "ardopcf install failed"; return 1; }

    cat > /tmp/ardop.service <<'EOF'
[Unit]
Description=ARDOP TNC (ardopcf)
After=sound.target

[Service]
ExecStart=/usr/local/bin/ardopcf 8515
Restart=on-failure
User=%i

[Install]
WantedBy=default.target
EOF
    sudo mv /tmp/ardop.service /etc/systemd/system/ardop@.service
    sudo systemctl daemon-reload
    log_info "ardopcf installed. Enable with: sudo systemctl enable ardop@$USER"
}

install_winlink() {
    log_info "Installing Pat Winlink..."
    install_ardop || true

    cd /tmp
    PAT_VERSION=$(curl -s https://api.github.com/repos/la5nta/pat/releases/latest \
        | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)
    [ -z "$PAT_VERSION" ] && PAT_VERSION="0.15.1"
    ARCH=$(dpkg --print-architecture)

    if wget -q "https://github.com/la5nta/pat/releases/download/v${PAT_VERSION}/pat_${PAT_VERSION}_linux_${ARCH}.deb" \
            -O pat.deb 2>/dev/null; then
        sudo dpkg -i pat.deb || sudo apt --fix-broken install -y
        rm -f pat.deb
        mkdir -p ~/.config/pat
        pat configure 2>/dev/null || true
        write_desktop "pat-winlink.desktop" \
            "Pat Winlink" "Winlink email over radio" \
            "pat http" "mail-send-receive" "X-HamRadio;X-HamRadio-Winlink;"
        log_info "Pat Winlink installed!"
    else
        log_warn "Pat download failed. Manual: https://github.com/la5nta/pat/releases"
    fi

    sudo apt install -y ax25-tools ax25-apps 2>/dev/null || \
        log_warn "AX.25 tools not available"
}

################################################################################
# 10. Satellite
################################################################################

install_satellite() {
    log_info "Installing satellite tracking software..."

    safe_install "gpredict" "Gpredict" "gpredict" \
        "weather-clear-night" "X-HamRadio;X-HamRadio-Satellite;" || true

    log_info "Satellite tracking software installed!"
}

################################################################################
# 11. Utilities
################################################################################

install_utilities() {
    log_info "Installing general ham radio utilities..."

    safe_install "libhamlib-utils" "HamLib utilities" "rigctl" \
        "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" true || true

    # CHIRP — may be chirp or chirpnext on 26.04
    if ! safe_install "chirp" "CHIRP" "chirp" \
            "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;"; then
        safe_install "chirpnext" "CHIRP Next" "chirpnext" \
            "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" || true
    fi

    safe_install "freedv"      "FreeDV"             "freedv"  "audio-input-microphone" "X-HamRadio;X-HamRadio-Utilities;" || true
    safe_install "gpsd"        "GPS Daemon"          "gpsd"    "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" true || true
    safe_install "gpsd-clients" "GPS Clients"        "cgps"    "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" true || true
    # python3-gps is a library package with no launchable binary — install only, no menu entry
    package_exists "python3-gps" && sudo apt install -y python3-gps 2>/dev/null || true
    safe_install "xdx"         "DX Cluster client"   "xdx"     "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" || true
    safe_install "wwl"         "Maidenhead locator"  "wwl"     "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" true || true
    safe_install "splat"       "SPLAT RF terrain"    "splat"   "applications-utilities" "X-HamRadio;X-HamRadio-Utilities;" true || true

    # fccexam / hamexam may be dropped in 26.04; skip silently
    safe_install "fccexam" "FCC Exam study" "fccexam" \
        "applications-education" "X-HamRadio;X-HamRadio-Utilities;" true || true
    safe_install "hamexam" "Ham exam study" "hamexam" \
        "applications-education" "X-HamRadio;X-HamRadio-Utilities;" true || true

    log_info "General utilities installation complete!"
}

################################################################################
# 12. HamClock
################################################################################

install_hamclock() {
    log_info "Installing HamClock (builds from source, ~15 min)..."
    sudo apt install -y libx11-dev fonts-dejavu unzip || { log_warn "HamClock deps failed"; return 0; }

    mkdir -p ~/hamradio
    cd ~/hamradio

    if wget -q --show-progress https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.zip; then
        unzip -q -o ESPHamClock.zip
        cd ESPHamClock
        log_info "Building HamClock..."
        if make -j"$(nproc)" hamclock-800x480 2>/dev/null; then
            sudo cp hamclock-800x480 /usr/local/bin/
            sudo ln -sf /usr/local/bin/hamclock-800x480 /usr/local/bin/hamclock
            write_desktop "hamclock.desktop" \
                "HamClock" "Ham Radio clock and information display" \
                "/usr/local/bin/hamclock" "hamradio" \
                "X-HamRadio;X-HamRadio-Utilities;"
            log_info "HamClock installed! Run: hamclock"
        else
            log_warn "HamClock build failed."
        fi
        cd ~/hamradio; rm -f ESPHamClock.zip
    else
        log_warn "HamClock download failed. Manual: https://www.clearskyinstitute.com/ham/HamClock/"
    fi
}

################################################################################
# 13. DX Spider
################################################################################

install_dxspider() {
    log_info "Installing DX Spider Cluster server..."

    # Perl module names unchanged on 26.04
    sudo apt install -y \
        perl libnet-telnet-perl libcurses-perl \
        libtime-hires-perl libdigest-sha-perl || {
        log_warn "Failed to install DX Spider dependencies"
        return 0
    }
    log_info "DX Spider Perl deps installed. Visit http://www.dxcluster.org/ for configuration."
}

################################################################################
# 14. VarAC (Wine)
################################################################################

install_varac() {
    log_info "Installing VarAC (via Wine)..."
    log_warn "VarAC is a Windows application; it runs under Wine on Linux."
    echo ""
    echo "  Download the VarAC ZIP from: https://www.varac-hamradio.com/downloadlinux"
    echo "  (complete the form, check email, download the ZIP)"
    echo ""
    read -p "  Path to VarAC ZIP (Enter to skip): " VARAC_ZIP

    # Wine — use WineHQ stable; fall back to Ubuntu wine
    log_info "Setting up WineHQ stable..."
    sudo dpkg --add-architecture i386
    sudo mkdir -p /etc/apt/keyrings
    [ ! -f /etc/apt/keyrings/winehq-archive.key ] && \
        sudo wget -qO /etc/apt/keyrings/winehq-archive.key \
            https://dl.winehq.org/wine-builds/winehq.key
    [ ! -f "/etc/apt/sources.list.d/winehq-${UBUNTU_CODENAME}.sources" ] && \
        sudo wget -qNP /etc/apt/sources.list.d/ \
            "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_CODENAME}/winehq-${UBUNTU_CODENAME}.sources" \
            2>/dev/null || true
    sudo apt update
    sudo apt install -y --install-recommends winehq-stable 2>/dev/null || \
        sudo apt install -y wine winetricks || {
            log_warn "Wine install failed"; return 1; }
    sudo apt install -y winetricks cabextract || true

    export WINEPREFIX="$HOME/.wine_varac"
    export WINEARCH=win32
    wineboot --init 2>/dev/null || true

    log_info "Installing Wine components (dotnet462, vb6run, vcrun2015, pdh_nt4)..."
    log_warn "This may take 10–20 minutes..."
    WINEPREFIX="$HOME/.wine_varac" winetricks -q \
        dotnet462 vb6run vcrun2015 pdh_nt4 corefonts 2>/dev/null || \
        log_warn "Some Wine components failed — VarAC may still work"

    # Segoe Emoji font
    FONT_DIR="$HOME/.wine_varac/drive_c/windows/Fonts"
    mkdir -p "$FONT_DIR"
    if [ -f "$HOME/.wine/drive_c/windows/Fonts/seguiemj.ttf" ]; then
        cp "$HOME/.wine/drive_c/windows/Fonts/seguiemj.ttf" "$FONT_DIR/" 2>/dev/null || true
    fi
    if [ ! -f "$FONT_DIR/seguiemj.ttf" ]; then
        wget -q -O "$FONT_DIR/seguiemj.ttf" \
            "https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf" \
            2>/dev/null || log_warn "Emoji font download failed"
    fi

    # Wine registry tweaks for VARA graphics
    WINEPREFIX="$HOME/.wine_varac" wine reg add \
        "HKCU\\Software\\Wine\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f 2>/dev/null || true
    WINEPREFIX="$HOME/.wine_varac" wine reg add \
        "HKCU\\Software\\Wine\\X11 Driver" /v "Managed"   /t REG_SZ /d "Y" /f 2>/dev/null || true

    VARAC_DIR="$HOME/.wine_varac/drive_c/VarAC"
    if [ -n "$VARAC_ZIP" ] && [ -f "$VARAC_ZIP" ]; then
        mkdir -p "$VARAC_DIR"
        unzip -q -o "$VARAC_ZIP" -d "$VARAC_DIR" || log_warn "VarAC ZIP extraction failed"
        # Flatten one level of nesting if VarAC.exe is in a subdirectory
        SUBDIR=$(find "$VARAC_DIR" -maxdepth 2 -name "VarAC.exe" 2>/dev/null | head -1 | xargs -r dirname)
        if [ -n "$SUBDIR" ] && [ "$SUBDIR" != "$VARAC_DIR" ]; then
            mv "$SUBDIR"/* "$VARAC_DIR"/ 2>/dev/null || true
        fi
        log_info "VarAC files installed."
    else
        log_warn "No ZIP provided — skipping VarAC file install."
        log_info "Later: unzip your VarAC ZIP into $VARAC_DIR"
    fi

    write_desktop "varac.desktop" \
        "VarAC" "Ham Radio Chat over VARA modem (Wine)" \
        "env WINEPREFIX=$HOME/.wine_varac WINEDEBUG=-all wine $VARAC_DIR/VarAC.exe" \
        "wine" "X-HamRadio;X-HamRadio-Winlink;"

    sudo usermod -a -G dialout "$USER"
    log_info "VarAC installation complete!"
    echo "  Run: env WINEPREFIX=$HOME/.wine_varac WINEDEBUG=-all wine $VARAC_DIR/VarAC.exe"
    log_warn "Log out and back in for dialout group permissions."
}

################################################################################
# 15. D-Rats
################################################################################

install_drats() {
    log_info "Installing D-Rats (D-STAR data communications)..."

    sudo apt install -y \
        git python3 python3-dev python3-pip python3-venv \
        python3-gi python3-gi-cairo python3-serial \
        python3-feedparser python3-lxml python3-pil \
        python3-simplejson python3-geopy \
        libcairo2-dev libgirepository1.0-dev \
        libxml2-utils gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 \
        gir1.2-pango-1.0 gir1.2-soup-3.0 \
        aspell aspell-en pkg-config 2>/dev/null || \
    sudo apt install -y \
        git python3 python3-dev python3-pip python3-venv \
        python3-gi python3-gi-cairo python3-serial \
        libcairo2-dev libgirepository1.0-dev aspell aspell-en pkg-config || \
        log_warn "Some D-Rats apt deps failed"

    # On Python 3.13+ pyaudio needs portaudio header; try apt first
    sudo apt install -y python3-pyaudio 2>/dev/null || \
        sudo apt install -y portaudio19-dev || true

    DRATS_DIR="$HOME/hamradio/d-rats"
    if [ -d "$DRATS_DIR/.git" ]; then
        git -C "$DRATS_DIR" pull || true
    else
        git clone --depth=1 \
            https://github.com/ham-radio-software/D-Rats.git "$DRATS_DIR" || {
            log_warn "D-Rats clone failed."; return 1; }
    fi

    python3 -m venv "$DRATS_DIR/venv" || { log_warn "venv creation failed"; return 1; }
    "$DRATS_DIR/venv/bin/pip" install --upgrade pip 2>/dev/null || true
    "$DRATS_DIR/venv/bin/pip" install \
        feedparser geopy lxml Pillow pyaudio \
        simplejson pydub requests 2>/dev/null || \
        log_warn "Some D-Rats pip deps failed — may still work"
    [ -f "$DRATS_DIR/requirements.txt" ] && \
        "$DRATS_DIR/venv/bin/pip" install -r "$DRATS_DIR/requirements.txt" \
            2>/dev/null || true

    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/d-rats" <<LAUNCHER
#!/bin/bash
cd "$DRATS_DIR"
exec "$DRATS_DIR/venv/bin/python3" "$DRATS_DIR/d_rats/d_rats_ev.py" "\$@"
LAUNCHER
    chmod +x "$HOME/.local/bin/d-rats"

    cat > "$HOME/.local/bin/d-rats-repeater" <<LAUNCHER
#!/bin/bash
cd "$DRATS_DIR"
exec "$DRATS_DIR/venv/bin/python3" "$DRATS_DIR/d_rats/repeater.py" "\$@"
LAUNCHER
    chmod +x "$HOME/.local/bin/d-rats-repeater"

    grep -q '\.local/bin' "$HOME/.bashrc" || \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

    if [ -d "$DRATS_DIR/libexec" ] && [ -f "$DRATS_DIR/libexec/Makefile" ]; then
        make -C "$DRATS_DIR/libexec" 2>/dev/null && \
            make -C "$DRATS_DIR/libexec" install 2>/dev/null || \
            log_warn "libexec build failed — serial passthrough may not work"
    fi

    write_desktop "d-rats.desktop" \
        "D-Rats" "D-STAR low-speed data communications" \
        "$HOME/.local/bin/d-rats" "network-wireless" \
        "X-HamRadio;X-HamRadio-Utilities;"

    sudo usermod -a -G dialout "$USER" 2>/dev/null || true
    log_info "D-Rats installed! Run: d-rats"
    log_warn "Open a new terminal for PATH to take effect."
}

################################################################################
# 16. voacapl + pythonprop
################################################################################

install_voacapl() {
    log_info "Installing voacapl + pythonprop (HF propagation)..."

    sudo apt install -y \
        gfortran autoconf automake autoconf-archive libtool make \
        python3 python3-pip python3-dev python3-venv \
        python3-gi python3-gi-cairo \
        python3-matplotlib python3-numpy python3-scipy \
        libgeos-dev libproj-dev proj-data proj-bin \
        libcairo2-dev libgirepository1.0-dev pkg-config || \
        log_warn "Some voacapl deps failed"

    mkdir -p ~/hamradio; cd ~/hamradio

    # ── voacapl engine ───────────────────────────────────────────────────────
    if [ -d "voacapl/.git" ]; then
        git -C voacapl pull || true
    else
        git clone --depth=1 https://github.com/jawatson/voacapl.git voacapl || {
            log_warn "voacapl clone failed"; return 1; }
    fi

    cd ~/hamradio/voacapl
    # autoreconf is needed because Ubuntu 26.04's automake 1.17 breaks old configs
    autoreconf --install --force 2>/dev/null || \
        { automake --add-missing 2>/dev/null; autoreconf 2>/dev/null; } || true

    ./configure --prefix=/usr/local 2>/dev/null && \
        make -j"$(nproc)" 2>/dev/null && \
        sudo make install 2>/dev/null || { log_warn "voacapl build failed"; return 1; }

    makeitshfbc 2>/dev/null || log_warn "makeitshfbc failed — run it manually"
    log_info "voacapl engine installed."

    # ── pythonprop GUI ───────────────────────────────────────────────────────
    log_info "Installing pythonprop..."
    cd ~/hamradio

    if [ -d "pythonprop/.git" ]; then
        git -C pythonprop pull || true
    else
        git clone --depth=1 https://github.com/jawatson/pythonprop.git pythonprop || {
            log_warn "pythonprop clone failed — CLI still works"; return 0; }
    fi

    cd ~/hamradio/pythonprop
    python3 -m venv ~/hamradio/pythonprop/venv || { log_warn "pythonprop venv failed"; return 0; }
    ~/hamradio/pythonprop/venv/bin/pip install --upgrade pip 2>/dev/null || true
    ~/hamradio/pythonprop/venv/bin/pip install \
        matplotlib cartopy numpy scipy 2>/dev/null || \
        log_warn "Some pythonprop pip deps failed"

    ~/hamradio/pythonprop/venv/bin/pip install ./src 2>/dev/null || {
        cd src
        ~/hamradio/pythonprop/venv/bin/python3 setup.py install 2>/dev/null || \
            { log_warn "pythonprop setup failed"; cd ..; return 0; }
        cd ..
    }

    # Install voacapgui wrapper
    if [ -f src/voacapgui ]; then
        sudo install -m 755 src/voacapgui /usr/local/bin/voacapgui
    elif [ -f scripts/voacapgui ]; then
        sudo install -m 755 scripts/voacapgui /usr/local/bin/voacapgui
    else
        sudo tee /usr/local/bin/voacapgui > /dev/null <<'LAUNCHER'
#!/usr/bin/env bash
exec "$HOME/hamradio/pythonprop/venv/bin/python3" -m pythonprop.voacapgui "$@"
LAUNCHER
    fi
    sudo chmod +x /usr/local/bin/voacapgui
    # Point shebang at venv python so cartopy is on the path
    sudo sed -i "1s|.*python.*|#!${HOME}/hamradio/pythonprop/venv/bin/python3|" \
        /usr/local/bin/voacapgui 2>/dev/null || true

    write_desktop "voacapgui.desktop" \
        "VOACAP GUI" "HF propagation prediction (VOACAP/voacapl)" \
        "voacapgui" "applications-engineering" \
        "X-HamRadio;X-HamRadio-Utilities;"

    log_info "voacapl + pythonprop installed! Run GUI: voacapgui"
}

################################################################################
# 1. Install all
################################################################################

install_all() {
    log_warn "Full install — this will take a significant amount of time."
    echo ""

    local steps=(
        install_system_prep
        install_digital_modes
        install_aprs
        install_logging
        install_sdr
        install_morse
        install_antenna_modeling
        install_winlink
        install_satellite
        install_utilities
        install_hamclock
        install_drats
        install_voacapl
    )
    local total=${#steps[@]}
    local i=0

    for fn in "${steps[@]}"; do
        i=$((i+1))
        echo -e "${CYAN}── Step ${i}/${total}: ${fn/install_/} ──────────────────${NC}"
        $fn || true
        echo ""
    done

    echo -e "${CYAN}── Step $((total+1))/$((total+1)): VarAC (skipped in full install) ──${NC}"
    log_info "VarAC requires a manual download. Run menu option 14 separately."
    log_info "Download: https://www.varac-hamradio.com/downloadlinux"

    echo ""
    log_info "All installations complete!"
}

################################################################################
# Main loop
################################################################################

mkdir -p ~/hamradio

while true; do
    show_menu

    case $choice in
        1)  install_all || true
            echo ""
            log_info "Done. Check messages above for any failures."
            read -p "Press Enter to exit..."
            break ;;
        2)  install_system_prep     || true ;;
        3)  install_digital_modes   || true ;;
        4)  install_aprs            || true ;;
        5)  install_logging         || true ;;
        6)  install_sdr             || true ;;
        7)  install_morse           || true ;;
        8)  install_antenna_modeling || true ;;
        9)  install_winlink         || true ;;
        10) install_satellite       || true ;;
        11) install_utilities       || true ;;
        12) install_hamclock        || true ;;
        13) install_dxspider        || true ;;
        14) install_varac           || true ;;
        15) install_drats           || true ;;
        16) install_voacapl         || true ;;
        0)  log_info "Exiting..."; exit 0 ;;
        *)  log_error "Invalid option."; sleep 2 ;;
    esac

    [[ "$choice" != "0" && "$choice" != "1" ]] && { echo; read -p "Press Enter to continue..."; }
done

################################################################################
# Post-installation summary
################################################################################

echo ""
echo "========================================================"
echo "  Post-Installation Notes"
echo "========================================================"
echo ""
echo "GENERAL"
echo "  • Log out and back in for group permission changes"
echo "  • All apps appear under 'Ham Radio' in your applications menu"
echo "  • Station: $CALLSIGN  |  Grid: $GRID_SQUARE"
echo ""
echo "DIGITAL MODES"
echo "  • WSJT-X:      wsjtx        (configure station on first run)"
echo "  • GridTracker: gridtracker"
echo ""
echo "WINLINK / ARDOP"
echo "  • Edit config:   ~/.config/pat/config.json"
echo "  • Run ARDOP:     ardopcf 8515 <capture_dev> <playback_dev>"
echo "  • List devices:  aplay -l"
echo "  • As a service:  sudo systemctl enable --now ardop@$USER"
echo ""
echo "VARAC  (requires manual install — menu option 14)"
echo "  • Download ZIP:  https://www.varac-hamradio.com/downloadlinux"
echo "  • Enable 'Linux Compatible Mode' on first launch"
echo ""
echo "D-RATS"
echo "  • Run:    d-rats"
echo "  • Update: git -C ~/hamradio/d-rats pull"
echo ""
echo "VOACAPL / VOACAP GUI"
echo "  • GUI: voacapgui"
echo "  • CLI: voacapl ~/itshfbc"
echo "  • Missing data? Run: makeitshfbc"
echo ""
echo "SDR"
echo "  • Blacklist DVB-T if RTL-SDR isn't detected:"
echo "    echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf"
echo "  • SDRPlay drivers: https://www.sdrplay.com/downloads/"
echo ""
echo "========================================================"
echo "  73 de $CALLSIGN"
echo "========================================================"
echo ""
