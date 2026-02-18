#!/bin/bash

################################################################################
# Ham Radio Package Installer for Ubuntu 24.04
# Based on HamPi package list, modernized for Ubuntu 24.04 compatibility
################################################################################

# Don't exit on errors - we want to continue installing other packages

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# XDG directories
APPS_DIR="$HOME/.local/share/applications"
DIRS_DIR="$HOME/.local/share/desktop-directories"

################################################################################
# Desktop menu grouping
#
# Groups:
#   HamRadio                  – top-level umbrella (X-HamRadio)
#   HamRadio-DigitalModes     – WSJT-X, JS8Call, GridTracker, FLDigi, QSSTV…
#   HamRadio-Logging          – CQRLOG, KLog, TrustedQSL…
#   HamRadio-SDR              – GQRX, CubicSDR, Quisk…
#   HamRadio-APRS             – Xastir, Direwolf…
#   HamRadio-Satellite        – Gpredict
#   HamRadio-Winlink          – Pat, VarAC
#   HamRadio-Antenna          – NEC2, xnec2c, yagiuda
#   HamRadio-Morse            – aldo, cwcp, xcwcp, qrq…
#   HamRadio-Utilities        – HamClock, CHIRP, FreeDV, splat…
################################################################################

install_desktop_directories() {
    mkdir -p "$APPS_DIR" "$DIRS_DIR"

    # Helper – write a .directory file
    # usage: write_dir_file <filename> <Name> <Icon> <Comment>
    write_dir_file() {
        cat > "$DIRS_DIR/$1" <<EOF
[Desktop Entry]
Type=Directory
Name=$2
Icon=$3
Comment=$4
EOF
    }

    write_dir_file "hamradio.directory" \
        "Ham Radio" "applications-hamradio" \
        "Amateur radio applications"

    write_dir_file "hamradio-digitalmodes.directory" \
        "Digital Modes" "network-wireless" \
        "Digital mode software (FT8, PSK, SSTV, etc.)"

    write_dir_file "hamradio-logging.directory" \
        "Logging" "x-office-address-book" \
        "QSO logging applications"

    write_dir_file "hamradio-sdr.directory" \
        "SDR" "audio-input-microphone" \
        "Software Defined Radio applications"

    write_dir_file "hamradio-aprs.directory" \
        "APRS" "network-transmit-receive" \
        "APRS and packet radio applications"

    write_dir_file "hamradio-satellite.directory" \
        "Satellite" "weather-clear-night" \
        "Satellite tracking applications"

    write_dir_file "hamradio-winlink.directory" \
        "Winlink" "mail-send-receive" \
        "Winlink email over radio"

    write_dir_file "hamradio-antenna.directory" \
        "Antenna Modeling" "applications-engineering" \
        "Antenna design and modeling software"

    write_dir_file "hamradio-morse.directory" \
        "Morse Code" "audio-speakers" \
        "Morse code training and tools"

    write_dir_file "hamradio-utilities.directory" \
        "Utilities" "applications-utilities" \
        "General ham radio utilities"

    # Register the directory tree with xdg-desktop-menu
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

# Helper – write a .desktop file and register it under a group
# usage: write_desktop <filename> <Name> <Comment> <Exec> <Icon> <Categories>
write_desktop() {
    local file="$APPS_DIR/$1"
    cat > "$file" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Comment=$3
Exec=$4
Icon=$5
Terminal=false
Categories=$6
EOF
    xdg-desktop-menu install --novendor "$file" 2>/dev/null || true
}

# Check if package exists in repositories
package_exists() {
    apt-cache show "$1" &>/dev/null
    return $?
}

# Install package with existence check
safe_install() {
    local package=$1
    local display_name=${2:-$package}

    if package_exists "$package"; then
        sudo apt install -y "$package" 2>/dev/null || {
            log_warn "Failed to install $display_name ($package)"
            return 1
        }
        log_info "$display_name installed!"
        return 0
    else
        log_warn "$display_name ($package) not available in repositories"
        return 1
    fi
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root. Run as regular user with sudo privileges."
   exit 1
fi

# Check Ubuntu version
if ! grep -q "24.04" /etc/os-release; then
    log_warn "This script is designed for Ubuntu 24.04. Your system may have compatibility issues."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get user information
log_info "Getting user information..."
read -p "Enter your ham radio callsign: " CALLSIGN
read -p "Enter your handle/name: " FULL_NAME
read -p "Enter your grid square (e.g., FN20): " GRID_SQUARE

CALLSIGN=${CALLSIGN^^}  # Convert to uppercase

log_info "Callsign: $CALLSIGN"
log_info "Name: $FULL_NAME"
log_info "Grid: $GRID_SQUARE"

# Installation menu
show_menu() {
    clear
    echo "================================================"
    echo "   Ham Radio Software Installer - Ubuntu 24.04"
    echo "================================================"
    echo "Callsign: $CALLSIGN | Grid: $GRID_SQUARE"
    echo "================================================"
    echo ""
    echo "1.  Install ALL packages (recommended for first-time setup)"
    echo "2.  System preparation & core utilities"
    echo "3.  Digital modes (WSJT-X, JS8Call, FLDigi suite)"
    echo "4.  APRS applications (Xastir, Direwolf, YAAC)"
    echo "5.  Logging applications (CQRLOG, KLog, TrustedQSL)"
    echo "6.  SDR applications (GQRX, CubicSDR, SDRAngel)"
    echo "7.  Morse code applications"
    echo "8.  Antenna modeling (NEC2, Yagiuda)"
    echo "9.  Winlink (Pat Winlink with ARDOP)"
    echo "10. Satellite tracking (Gpredict, Predict)"
    echo "11. General ham radio utilities"
    echo "12. Install HamClock"
    echo "13. Install DX Spider Cluster server"
    echo "14. Install VarAC (Wine-based chat over VARA)"
    echo "15. Install D-Rats (D-STAR data communications)"
    echo "16. Install voacapl + pythonprop (HF propagation prediction)"
    echo ""
    echo "0.  Exit"
    echo ""
    read -p "Enter your choice [0-16]: " choice
}

################################################################################
# Installation Functions
################################################################################

install_system_prep() {
    log_info "Installing system dependencies and core utilities..."

    sudo apt update

    sudo apt install -y \
        build-essential cmake git wget curl ca-certificates gnupg \
        software-properties-common dkms linux-headers-$(uname -r) \
        pkg-config autoconf automake libtool gfortran || true

    sudo apt install -y \
        python3 python3-pip python3-dev python3-setuptools python3-wheel \
        python3-venv python3-numpy python3-scipy python3-serial \
        python3-requests python3-yaml || true

    sudo apt install -y \
        libusb-1.0-0-dev libssl-dev libfftw3-dev libsamplerate0-dev \
        libpulse-dev portaudio19-dev libasound2-dev libsndfile1-dev \
        libxml2-dev libxslt1-dev libhamlib-dev libhamlib4 libhamlib-utils || true

    sudo apt install -y \
        libgtk-3-dev qtbase5-dev qttools5-dev qtmultimedia5-dev || true

    # Ensure xdg-utils is present for desktop integration
    sudo apt install -y xdg-utils || true

    # Create XDG menu groups
    install_desktop_directories

    log_info "System preparation complete!"
    return 0
}

install_gridtracker() {
    log_info "Installing GridTracker..."

    if ! command -v node &> /dev/null; then
        sudo mkdir -p /etc/apt/keyrings
        if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
                sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | \
                sudo tee /etc/apt/sources.list.d/nodesource.list
            sudo apt update
        fi
        sudo apt install -y nodejs
    fi

    log_info "Node.js is installed: $(node --version)"
    cd /tmp
    ARCH=$(dpkg --print-architecture)

    case "$ARCH" in
        amd64)  GT_PACKAGE="GridTracker2-2.250914.1-amd64.deb" ;;
        arm64)  GT_PACKAGE="GridTracker2-2.250914.1-arm64.deb" ;;
        armhf|armv7l) GT_PACKAGE="GridTracker2-2.250914.1-armv7l.deb" ;;
        *)
            log_warn "GridTracker not available for architecture: $ARCH"
            log_info "Visit https://gridtracker.org/ for other options"
            return 0 ;;
    esac

    if wget -q --show-progress "https://download2.gridtracker.org/${GT_PACKAGE}" 2>/dev/null; then
        sudo dpkg -i "${GT_PACKAGE}" 2>/dev/null || sudo apt --fix-broken install -y
        rm -f "${GT_PACKAGE}"
        # GridTracker installs its own .desktop; update its Categories to match our group
        GT_DESK=$(find /usr/share/applications ~/.local/share/applications \
            -name "*gridtracker*" -o -name "*GridTracker*" 2>/dev/null | head -1)
        if [ -n "$GT_DESK" ]; then
            cp "$GT_DESK" "$APPS_DIR/gridtracker.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-DigitalModes;/' \
                "$APPS_DIR/gridtracker.desktop" 2>/dev/null || true
        fi
        log_info "GridTracker installed!"
    else
        log_warn "Failed to download GridTracker"
        log_info "Manual download: https://gridtracker.org/index.php/downloads/gridtracker-downloads"
    fi
    return 0
}

install_js8call() {
    log_info "Installing JS8Call..."

    if safe_install "js8call" "JS8Call"; then
        # Patch the Categories in the system .desktop if present
        JS_DESK=$(find /usr/share/applications -name "*js8call*" 2>/dev/null | head -1)
        if [ -n "$JS_DESK" ]; then
            cp "$JS_DESK" "$APPS_DIR/js8call.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-DigitalModes;/' \
                "$APPS_DIR/js8call.desktop" 2>/dev/null || true
        fi
        return 0
    fi

    log_info "JS8Call not in repositories, trying GitHub release..."
    cd /tmp
    ARCH=$(dpkg --print-architecture)
    JS8_VERSION=$(curl -s https://api.github.com/repos/js8call/js8call/releases/latest \
        | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)

    if [ -z "$JS8_VERSION" ]; then
        log_warn "Could not determine JS8Call version"
        log_info "Visit https://github.com/js8call/js8call/releases for manual download"
        return 0
    fi

    case "$ARCH" in
        amd64) JS8_PACKAGE="js8call_${JS8_VERSION}_amd64.deb" ;;
        armhf) JS8_PACKAGE="js8call_${JS8_VERSION}_armhf.deb" ;;
        *)
            log_warn "JS8Call not available for architecture: $ARCH"
            return 0 ;;
    esac

    if wget -q --show-progress \
        "https://github.com/js8call/js8call/releases/download/v${JS8_VERSION}/${JS8_PACKAGE}" \
        2>/dev/null; then
        sudo dpkg -i "${JS8_PACKAGE}" 2>/dev/null || sudo apt --fix-broken install -y
        rm -f "${JS8_PACKAGE}"
        write_desktop "js8call.desktop" \
            "JS8Call" "JS8 keyboard-to-keyboard messaging" \
            "js8call" "applications-internet" \
            "X-HamRadio;X-HamRadio-DigitalModes;"
        log_info "JS8Call installed!"
    else
        log_warn "Failed to download JS8Call"
        log_info "Manual download: https://github.com/js8call/js8call/releases"
    fi
    return 0
}

install_flarq() {
    log_info "Installing FLArq..."

    if safe_install "flarq" "FLArq"; then
        FLARQ_DESK=$(find /usr/share/applications -name "*flarq*" 2>/dev/null | head -1)
        if [ -n "$FLARQ_DESK" ]; then
            cp "$FLARQ_DESK" "$APPS_DIR/flarq.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-DigitalModes;/' \
                "$APPS_DIR/flarq.desktop" 2>/dev/null || true
        fi
        return 0
    fi

    log_info "FLArq not in repositories, building from source..."

    sudo apt install -y \
        libfltk1.3-dev libsndfile1-dev libsamplerate0-dev libpulse-dev \
        libasound2-dev portaudio19-dev libhamlib-dev libudev-dev \
        libxi-dev libxfixes-dev libxft-dev libxinerama-dev libxcursor-dev || {
        log_warn "Failed to install FLArq build dependencies"
        return 1
    }

    cd /tmp
    FLARQ_VERSION=$(curl -s "https://sourceforge.net/projects/flarq/files/" \
        | grep -oP 'flarq-\K[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)
    [ -z "$FLARQ_VERSION" ] && FLARQ_VERSION="4.3.9"

    log_info "Downloading FLArq v${FLARQ_VERSION} source..."
    FLARQ_TARBALL="flarq-${FLARQ_VERSION}.tar.gz"
    FLARQ_URL="https://sourceforge.net/projects/flarq/files/flarq-${FLARQ_VERSION}/${FLARQ_TARBALL}/download"

    if wget -q --show-progress -O "${FLARQ_TARBALL}" "${FLARQ_URL}" 2>/dev/null; then
        tar -xzf "${FLARQ_TARBALL}"
        cd "flarq-${FLARQ_VERSION}"

        ./configure --prefix=/usr/local 2>/dev/null && \
        make -j$(nproc) 2>/dev/null && \
        sudo make install 2>/dev/null || {
            log_warn "FLArq build failed"
            cd /tmp; rm -rf "flarq-${FLARQ_VERSION}" "${FLARQ_TARBALL}"
            return 1
        }

        cd /tmp; rm -rf "flarq-${FLARQ_VERSION}" "${FLARQ_TARBALL}"

        write_desktop "flarq.desktop" \
            "FLArq" "ARQ file transfer for FLDigi" \
            "flarq" "applications-internet" \
            "X-HamRadio;X-HamRadio-DigitalModes;"
        log_info "FLArq built and installed from source!"
    else
        log_warn "Failed to download FLArq source"
        log_info "Manual download: https://sourceforge.net/projects/flarq/files/"
        return 1
    fi
    return 0
}

install_digital_modes() {
    log_info "Installing digital mode applications..."

    safe_install "wsjtx" "WSJT-X" || true
    if find /usr/share/applications -name "*wsjtx*" &>/dev/null; then
        cp /usr/share/applications/wsjtx.desktop "$APPS_DIR/wsjtx.desktop" 2>/dev/null || true
        sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-DigitalModes;/' \
            "$APPS_DIR/wsjtx.desktop" 2>/dev/null || true
    fi

    safe_install "jtdx" "JTDX" || true

    install_js8call || true
    install_gridtracker || true

    log_info "Installing FLDigi suite..."
    for pkg in fldigi flrig flmsg flamp; do
        safe_install "$pkg" "$pkg" || true
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-DigitalModes;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    install_flarq || true

    safe_install "xlog" "XLog" || true
    safe_install "qsstv" "QSSTV" || true
    for pkg in xlog qsstv; do
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-DigitalModes;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_info "Digital mode applications installation complete!"
    return 0
}

install_aprs() {
    log_info "Installing APRS applications..."

    safe_install "xastir" "Xastir" || true
    safe_install "direwolf" "Direwolf" || true
    sudo apt install -y default-jre || true
    safe_install "aprx" "APRx" || true
    safe_install "aprsdigi" "APRS Digi" || true

    for pkg in xastir direwolf; do
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-APRS;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_info "APRS applications installed!"
    return 0
}

install_logging() {
    log_info "Installing logging applications..."

    for pkg in cqrlog klog trustedqsl pyqso tlf; do
        safe_install "$pkg" "$pkg" || true
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-Logging;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_info "Logging applications installed!"
    return 0
}

install_sdr() {
    log_info "Installing SDR applications and drivers..."

    sudo apt install -y soapysdr-tools soapysdr-module-all || true
    sudo apt install -y rtl-sdr librtlsdr-dev || true
    sudo usermod -a -G plugdev $USER

    for pkg in gqrx-sdr cubicsdr quisk cutesdr; do
        safe_install "$pkg" "$pkg" || true
        DESK=$(find /usr/share/applications -name "*${pkg%%-*}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-SDR;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_info "SDR applications installed!"
    log_warn "You may need to log out and back in for USB permissions to take effect."
    log_info "Note: SDRPlay drivers must be downloaded manually from https://www.sdrplay.com/downloads/"
    return 0
}

install_morse() {
    log_info "Installing Morse code applications..."

    for pkg in aldo cw cwcp xcwcp morse morse2ascii morsegen qrq xdemorse; do
        safe_install "$pkg" "$pkg" || true
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-Morse;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_info "Morse code applications installation complete!"
    return 0
}

install_antenna_modeling() {
    log_info "Installing antenna modeling software..."

    for pkg in nec2c xnec2c yagiuda; do
        safe_install "$pkg" "$pkg" || true
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-Antenna;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_info "Antenna modeling software installation complete!"
    return 0
}

install_ardop() {
    log_info "Installing ardopcf (ARDOP TNC)..."

    sudo apt install -y libasound2-dev libpulse-dev portaudio19-dev || true

    cd /tmp
    ARCH=$(dpkg --print-architecture)
    ARDOP_VERSION=$(curl -s https://api.github.com/repos/pflarue/ardop/releases/latest \
        | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)
    [ -z "$ARDOP_VERSION" ] && ARDOP_VERSION="1.0.4.1.3"

    log_info "ardopcf latest release: v${ARDOP_VERSION}"

    case "$ARCH" in
        amd64)  ARDOP_BIN="ardopcf_amd64_Linux_64"  ;;
        arm64)  ARDOP_BIN="ardopcf_arm_Linux_64"    ;;
        armhf)  ARDOP_BIN="ardopcf_arm_Linux_32"    ;;
        *)      ARDOP_BIN=""                         ;;
    esac

    INSTALLED=false

    if [ -n "$ARDOP_BIN" ]; then
        ARDOP_URL="https://github.com/pflarue/ardop/releases/download/v${ARDOP_VERSION}/${ARDOP_BIN}"
        log_info "Downloading ardopcf binary for ${ARCH}..."
        if wget -q --show-progress -O ardopcf "${ARDOP_URL}" 2>/dev/null; then
            chmod +x ardopcf
            sudo mv ardopcf /usr/local/bin/ardopcf
            sudo ln -sf /usr/local/bin/ardopcf /usr/local/bin/ardopc
            log_info "ardopcf binary installed to /usr/local/bin/ardopcf"
            INSTALLED=true
        else
            log_warn "Binary download failed, will try building from source"
            rm -f ardopcf
        fi
    else
        log_warn "No pre-built binary for architecture: $ARCH, building from source"
    fi

    if [ "$INSTALLED" = false ]; then
        log_info "Building ardopcf from source..."
        sudo apt install -y git build-essential cmake || { log_warn "Build deps failed"; return 1; }
        rm -rf /tmp/ardop
        if git clone --depth=1 https://github.com/pflarue/ardop.git /tmp/ardop 2>/dev/null; then
            cd /tmp/ardop
            if [ -f CMakeLists.txt ]; then
                mkdir -p build && cd build
                cmake .. -DCMAKE_BUILD_TYPE=Release 2>/dev/null && \
                make -j$(nproc) 2>/dev/null && \
                sudo cmake --install . 2>/dev/null && INSTALLED=true
            else
                make -j$(nproc) 2>/dev/null && \
                sudo install -m 755 ardopcf /usr/local/bin/ardopcf && \
                sudo ln -sf /usr/local/bin/ardopcf /usr/local/bin/ardopc && \
                INSTALLED=true
            fi
            cd /tmp; rm -rf /tmp/ardop
            if [ "$INSTALLED" = true ]; then
                log_info "ardopcf built and installed from source!"
            else
                log_warn "ardopcf source build failed"
                log_info "See https://github.com/pflarue/ardop/blob/master/docs/BUILDING.md"
                return 1
            fi
        else
            log_warn "Failed to clone ardopcf repository"
            return 1
        fi
    fi

    cat > /tmp/ardop.service <<'ARDOP_SERVICE_EOF'
[Unit]
Description=ARDOP TNC (ardopcf)
After=sound.target

[Service]
ExecStart=/usr/local/bin/ardopcf 8515
Restart=on-failure
User=%i

[Install]
WantedBy=default.target
ARDOP_SERVICE_EOF
    sudo mv /tmp/ardop.service /etc/systemd/system/ardop@.service
    sudo systemctl daemon-reload

    log_info "ardopcf systemd unit installed (ardop@<username>.service)"
    log_info "Enable with: sudo systemctl enable ardop@$USER"
    log_info "Start with:  sudo systemctl start ardop@$USER"
    log_info "Or run manually: ardopcf 8515 <capture_device> <playback_device>"
    log_info "List audio devices with: aplay -l"
    return 0
}

install_winlink() {
    log_info "Installing Pat Winlink..."

    install_ardop || true

    cd /tmp
    PAT_VERSION=$(curl -s https://api.github.com/repos/la5nta/pat/releases/latest \
        | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)
    [ -z "$PAT_VERSION" ] && PAT_VERSION="0.15.1"

    log_info "Installing Pat v${PAT_VERSION}..."
    ARCH=$(dpkg --print-architecture)

    if wget -q "https://github.com/la5nta/pat/releases/download/v${PAT_VERSION}/pat_${PAT_VERSION}_linux_${ARCH}.deb" \
        -O pat.deb 2>/dev/null; then
        sudo dpkg -i pat.deb || sudo apt --fix-broken install -y
        rm -f pat.deb
        mkdir -p ~/.config/pat
        pat configure || log_info "Pat config created at ~/.config/pat/config.json"

        write_desktop "pat-winlink.desktop" \
            "Pat Winlink" "Winlink email over radio" \
            "pat http" "mail-send-receive" \
            "X-HamRadio;X-HamRadio-Winlink;"
        log_info "Pat Winlink installed!"
    else
        log_warn "Failed to download Pat"
        log_info "Manual download: https://github.com/la5nta/pat/releases"
    fi

    sudo apt install -y ax25-tools ax25-apps || log_warn "AX.25 tools not available"
    return 0
}

install_satellite() {
    log_info "Installing satellite tracking software..."

    safe_install "gpredict" "Gpredict" || true
    DESK=$(find /usr/share/applications -name "*gpredict*" 2>/dev/null | head -1)
    if [ -n "$DESK" ]; then
        cp "$DESK" "$APPS_DIR/gpredict.desktop" 2>/dev/null || true
        sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-Satellite;/' \
            "$APPS_DIR/gpredict.desktop" 2>/dev/null || true
    fi

    log_info "Satellite tracking software installation complete!"
    return 0
}

install_utilities() {
    log_info "Installing general ham radio utilities..."

    safe_install "libhamlib-utils" "HamLib utilities" || true
    safe_install "chirp" "CHIRP radio programmer" || true
    safe_install "freedv" "FreeDV digital voice" || true
    safe_install "gpsd" "GPS daemon" || true
    safe_install "gpsd-clients" "GPS clients" || true
    safe_install "python3-gps" "Python GPS support" || true
    safe_install "xdx" "DX Cluster client" || true
    safe_install "fccexam" "FCC exam study" || true
    safe_install "hamexam" "Ham exam study" || true
    safe_install "wwl" "Maidenhead locator calculator" || true
    safe_install "splat" "RF terrain analysis" || true

    for pkg in chirp freedv xdx splat fccexam hamexam; do
        DESK=$(find /usr/share/applications -name "*${pkg}*" 2>/dev/null | head -1)
        if [ -n "$DESK" ]; then
            cp "$DESK" "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
            sed -i 's/^Categories=.*/Categories=X-HamRadio;X-HamRadio-Utilities;/' \
                "$APPS_DIR/${pkg}.desktop" 2>/dev/null || true
        fi
    done

    log_warn "Some utilities (gcb, colrconv, d-rats, voacapl) are not available in Ubuntu 24.04"
    log_info "General utilities installation complete!"
    return 0
}

install_hamclock() {
    log_info "Installing HamClock..."
    log_warn "HamClock requires building from source and may take 10-15 minutes"

    sudo apt install -y libx11-dev fonts-dejavu unzip || {
        log_warn "Failed to install HamClock dependencies"
        return 0
    }

    mkdir -p ~/hamradio
    cd ~/hamradio

    if wget -q --show-progress https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.zip; then
        unzip -q -o ESPHamClock.zip
        cd ESPHamClock
        log_info "Building HamClock (this may take a while)..."

        if make -j$(nproc) hamclock-800x480 2>/dev/null; then
            sudo cp hamclock-800x480 /usr/local/bin/
            sudo ln -sf /usr/local/bin/hamclock-800x480 /usr/local/bin/hamclock

            write_desktop "hamclock.desktop" \
                "HamClock" "Ham Radio Clock and Information Display" \
                "/usr/local/bin/hamclock" "hamradio" \
                "X-HamRadio;X-HamRadio-Utilities;"

            log_info "HamClock installed! Run with: hamclock"
        else
            log_warn "HamClock build failed"
        fi

        cd ~/hamradio
        rm -f ESPHamClock.zip
    else
        log_warn "Failed to download HamClock"
        log_info "Manual download: https://www.clearskyinstitute.com/ham/HamClock/"
    fi
    return 0
}

install_drats() {
    log_info "Installing D-Rats (D-STAR data communications)..."

    # ── Step 1: apt dependencies ──────────────────────────────────────────────
    log_info "Installing D-Rats system dependencies..."
    sudo apt install -y \
        git \
        python3 python3-dev python3-pip python3-venv \
        python3-gi python3-gi-cairo python3-serial \
        python3-feedparser python3-lxml python3-pil \
        python3-simplejson python3-geopy python3-pyaudio \
        libcairo2-dev libgirepository1.0-dev \
        libxml2-utils gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0 \
        gir1.2-pango-1.0 gir1.2-soup-2.4 \
        aspell aspell-en \
        pkg-config || {
        log_warn "Some D-Rats apt dependencies failed to install"
    }

    # ── Step 2: Clone the repository ─────────────────────────────────────────
    DRATS_DIR="$HOME/hamradio/d-rats"
    log_info "Cloning D-Rats from GitHub into $DRATS_DIR ..."

    if [ -d "$DRATS_DIR/.git" ]; then
        log_info "D-Rats repository already exists, pulling latest..."
        git -C "$DRATS_DIR" pull || log_warn "Git pull failed, using existing copy"
    else
        git clone --depth=1 \
            https://github.com/ham-radio-software/D-Rats.git \
            "$DRATS_DIR" || {
            log_warn "Failed to clone D-Rats repository"
            log_info "Manual clone: git clone https://github.com/ham-radio-software/D-Rats.git"
            return 1
        }
    fi

    # ── Step 3: Create a Python virtual environment and install pip deps ──────
    log_info "Creating Python virtual environment for D-Rats..."
    python3 -m venv "$DRATS_DIR/venv" || {
        log_warn "Failed to create virtual environment"
        return 1
    }

    log_info "Installing D-Rats Python dependencies into venv..."
    "$DRATS_DIR/venv/bin/pip" install --upgrade pip 2>/dev/null || true
    "$DRATS_DIR/venv/bin/pip" install \
        feedparser geopy lxml Pillow pyaudio \
        simplejson pydub requests 2>/dev/null || {
        log_warn "Some pip dependencies failed - D-Rats may still work"
    }

    # requirements.txt if present
    if [ -f "$DRATS_DIR/requirements.txt" ]; then
        "$DRATS_DIR/venv/bin/pip" install -r "$DRATS_DIR/requirements.txt" \
            2>/dev/null || log_warn "requirements.txt install had errors"
    fi

    # ── Step 4: Create launcher wrapper script ────────────────────────────────
    log_info "Creating D-Rats launcher script..."
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/d-rats" <<DRATS_LAUNCHER
#!/bin/bash
# D-Rats launcher — uses the dedicated venv
cd "$DRATS_DIR"
exec "$DRATS_DIR/venv/bin/python3" "$DRATS_DIR/d_rats/d_rats_ev.py" "\$@"
DRATS_LAUNCHER
    chmod +x "$HOME/.local/bin/d-rats"

    # Also create a repeater launcher
    cat > "$HOME/.local/bin/d-rats-repeater" <<DRATS_REP_LAUNCHER
#!/bin/bash
cd "$DRATS_DIR"
exec "$DRATS_DIR/venv/bin/python3" "$DRATS_DIR/d_rats/repeater.py" "\$@"
DRATS_REP_LAUNCHER
    chmod +x "$HOME/.local/bin/d-rats-repeater"

    # Ensure ~/.local/bin is on PATH
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        log_info "Added ~/.local/bin to PATH in ~/.bashrc"
    fi

    # ── Step 5: Install the libexec helpers (ax25 serial port support) ────────
    if [ -d "$DRATS_DIR/libexec" ] && [ -f "$DRATS_DIR/libexec/Makefile" ]; then
        log_info "Building D-Rats libexec helpers..."
        make -C "$DRATS_DIR/libexec" 2>/dev/null && \
        make -C "$DRATS_DIR/libexec" install 2>/dev/null || \
        log_warn "libexec build failed — serial port passthrough may not work"
    fi

    # ── Step 6: Desktop entry in Ham Radio → Utilities ───────────────────────
    write_desktop "d-rats.desktop" \
        "D-Rats" "D-STAR low-speed data communications" \
        "$HOME/.local/bin/d-rats" "network-wireless" \
        "X-HamRadio;X-HamRadio-Utilities;"

    # ── Step 7: Add user to dialout group for serial/RF access ───────────────
    sudo usermod -a -G dialout $USER 2>/dev/null || true

    log_info "D-Rats installed successfully!"
    echo ""
    echo "  Run D-Rats with:  d-rats"
    echo "  Or launch from:   Ham Radio → Utilities → D-Rats"
    echo "  Source location:  $DRATS_DIR"
    echo "  To update later:  git -C $DRATS_DIR pull"
    echo "                    $DRATS_DIR/venv/bin/pip install -r $DRATS_DIR/requirements.txt"
    log_warn "You may need to open a new terminal for the PATH change to take effect."

    return 0
}

install_voacapl() {
    log_info "Installing voacapl (VOACAP HF propagation prediction engine)..."
    log_warn "This build requires gfortran and autotools — it may take a few minutes."

    # ── Step 1: System dependencies ──────────────────────────────────────────
    log_info "Installing voacapl build dependencies..."
    sudo apt install -y \
        gfortran \
        autoconf automake autoconf-archive libtool make \
        python3 python3-pip python3-dev python3-venv \
        python3-gi python3-gi-cairo \
        python3-matplotlib python3-numpy python3-scipy \
        libgeos-dev libproj-dev proj-data proj-bin \
        libcairo2-dev libgirepository1.0-dev \
        pkg-config || {
        log_warn "Some voacapl dependencies failed — build may still succeed"
    }

    mkdir -p ~/hamradio
    cd ~/hamradio

    # ════════════════════════════════════════════════════════════════════════
    # Part 1 — voacapl engine
    # ════════════════════════════════════════════════════════════════════════
    log_info "Cloning voacapl from GitHub..."
    if [ -d "voacapl/.git" ]; then
        log_info "voacapl repository already exists, pulling latest..."
        git -C voacapl pull || true
    else
        git clone --depth=1 https://github.com/jawatson/voacapl.git voacapl || {
            log_warn "Failed to clone voacapl"
            log_info "Manual clone: https://github.com/jawatson/voacapl"
            return 1
        }
    fi

    cd ~/hamradio/voacapl

    log_info "Bootstrapping voacapl build system..."
    # Regenerate always — the repo's configure was built with automake 1.15
    # but Ubuntu 24.04 ships 1.16, which causes "missing aclocal-1.15" errors.
    autoreconf --install --force 2>/dev/null || {
        log_warn "autoreconf failed — trying automake --add-missing fallback"
        automake --add-missing 2>/dev/null || true
        autoreconf 2>/dev/null || true
    }

    log_info "Configuring voacapl..."
    ./configure --prefix=/usr/local 2>/dev/null || {
        log_warn "voacapl configure failed"
        return 1
    }

    log_info "Compiling voacapl..."
    make -j$(nproc) 2>/dev/null || {
        log_warn "voacapl make failed"
        return 1
    }

    log_info "Installing voacapl..."
    sudo make install 2>/dev/null || {
        log_warn "voacapl make install failed"
        return 1
    }

    log_info "Building voacapl data files (makeitshfbc)..."
    # makeitshfbc creates ~/itshfbc — required data hierarchy
    makeitshfbc 2>/dev/null || {
        log_warn "makeitshfbc failed — run it manually after installation"
        log_info "Run: makeitshfbc"
    }

    log_info "voacapl engine installed successfully!"
    log_info "Data files created in: ~/itshfbc"
    log_info "Test run: voacapl ~/itshfbc"

    # ════════════════════════════════════════════════════════════════════════
    # Part 2 — pythonprop GUI frontend
    # ════════════════════════════════════════════════════════════════════════
    log_info "Installing pythonprop (VOACAP GUI and plotting utilities)..."

    cd ~/hamradio

    if [ -d "pythonprop/.git" ]; then
        log_info "pythonprop repository already exists, pulling latest..."
        git -C pythonprop pull || true
    else
        git clone --depth=1 https://github.com/jawatson/pythonprop.git pythonprop || {
            log_warn "Failed to clone pythonprop — GUI will not be available"
            log_info "Manual clone: https://github.com/jawatson/pythonprop"
            # voacapl CLI still works without the GUI, so return 0
            return 0
        }
    fi

    cd ~/hamradio/pythonprop

    # Install cartopy and matplotlib via pip into a venv (cartopy has complex
    # C extensions that are easier to get right via pip than apt on 24.04)
    log_info "Creating Python venv for pythonprop..."
    python3 -m venv ~/hamradio/pythonprop/venv || {
        log_warn "Failed to create pythonprop venv"
        return 0
    }

    log_info "Installing pythonprop Python dependencies (cartopy, matplotlib)..."
    ~/hamradio/pythonprop/venv/bin/pip install --upgrade pip 2>/dev/null || true
    ~/hamradio/pythonprop/venv/bin/pip install \
        matplotlib cartopy numpy scipy 2>/dev/null || {
        log_warn "Some pythonprop pip dependencies failed"
    }

    log_info "Installing pythonprop Python package directly (bypassing broken autotools)..."
    # The autotools build chain requires yelp-tools and has a broken docs/Makefile.
    # pythonprop is a pure Python package — install it straight from source with pip.
    ~/hamradio/pythonprop/venv/bin/pip install ./src 2>/dev/null || {
        log_warn "pip install ./src failed, trying setup.py directly"
        cd src
        ~/hamradio/pythonprop/venv/bin/python3 setup.py install 2>/dev/null || {
            log_warn "setup.py install failed"
            cd ..
            return 0
        }
        cd ..
    }

    # Install the voacapgui launcher script manually
    if [ -f src/voacapgui ]; then
        sudo install -m 755 src/voacapgui /usr/local/bin/voacapgui
        log_info "voacapgui launcher installed to /usr/local/bin/voacapgui"
    elif [ -f scripts/voacapgui ]; then
        sudo install -m 755 scripts/voacapgui /usr/local/bin/voacapgui
        log_info "voacapgui launcher installed to /usr/local/bin/voacapgui"
    else
        log_warn "voacapgui launcher not found in repo — writing one"
        sudo tee /usr/local/bin/voacapgui > /dev/null <<LAUNCHER
#!/usr/bin/env bash
exec "$HOME/hamradio/pythonprop/venv/bin/python3" \
    -m pythonprop.voacapgui "\$@"
LAUNCHER
        sudo chmod +x /usr/local/bin/voacapgui
    fi

    # Patch the voacapgui wrapper to use the venv python so cartopy is found
    if [ -f /usr/local/bin/voacapgui ]; then
        sudo sed -i "1s|.*python.*|#!${HOME}/hamradio/pythonprop/venv/bin/python3|" \
            /usr/local/bin/voacapgui 2>/dev/null || true
    fi

    # ── Desktop entry — Ham Radio → Utilities ────────────────────────────────
    write_desktop "voacapgui.desktop" \
        "VOACAP GUI" "HF propagation prediction (VOACAP/voacapl)" \
        "voacapgui" "applications-engineering" \
        "X-HamRadio;X-HamRadio-Utilities;"

    log_info "pythonprop installed successfully!"
    echo ""
    echo "  Run the GUI with:  voacapgui"
    echo "  Or launch from:    Ham Radio → Utilities → VOACAP GUI"
    echo "  CLI engine:        voacapl ~/itshfbc [input.dat] [output.out]"
    echo "  Data directory:    ~/itshfbc"
    echo "  Source locations:  ~/hamradio/voacapl"
    echo "                     ~/hamradio/pythonprop"
    echo ""
    log_info "voacapl + pythonprop installation complete!"
    return 0
}

install_dxspider() {
    log_info "Installing DX Spider Cluster server..."

    sudo apt install -y \
        perl libnet-telnet-perl libcurses-perl \
        libtime-hires-perl libdigest-sha-perl || {
        log_warn "Failed to install DX Spider dependencies"
        return 0
    }

    log_info "DX Spider requires manual configuration"
    log_info "Visit http://www.dxcluster.org/ for installation instructions"
    return 0
}

install_varac() {
    log_info "Installing VarAC (via Wine)..."
    log_warn "VarAC is a Windows application that runs under Wine on Linux."
    log_warn "NOTE: VarAC requires a manual download due to an email-gated download page."
    echo ""
    echo "  Before continuing, download the VarAC ZIP package from:"
    echo "  https://www.varac-hamradio.com/downloadlinux"
    echo "  (fill in the form, check your email, download the ZIP)"
    echo ""
    read -p "  Enter the full path to the VarAC ZIP file (or press Enter to skip): " VARAC_ZIP

    # ── Step 1: Install WineHQ stable ────────────────────────────────────────
    log_info "Setting up WineHQ stable repository..."
    sudo dpkg --add-architecture i386
    sudo mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/winehq-archive.key ]; then
        sudo wget -qO /etc/apt/keyrings/winehq-archive.key \
            https://dl.winehq.org/wine-builds/winehq.key
    fi
    if [ ! -f /etc/apt/sources.list.d/winehq-noble.sources ]; then
        sudo wget -qNP /etc/apt/sources.list.d/ \
            https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
    fi
    sudo apt update
    sudo apt install -y --install-recommends winehq-stable || {
        log_warn "WineHQ stable not available, falling back to Ubuntu wine"
        sudo apt install -y wine winetricks || {
            log_warn "Failed to install Wine - cannot continue VarAC installation"
            return 1
        }
    }
    sudo apt install -y winetricks cabextract || true

    # ── Step 2: Configure a 32-bit Wine prefix ───────────────────────────────
    log_info "Configuring Wine prefix..."
    export WINEPREFIX="$HOME/.wine_varac"
    export WINEARCH=win32
    wineboot --init 2>/dev/null || true

    # ── Step 3: Install required Windows components via winetricks ───────────
    log_info "Installing Wine components (dotnet462, vb6run, vcrun2015, pdh_nt4)..."
    log_warn "This may take 10-20 minutes on first run..."
    WINEPREFIX="$HOME/.wine_varac" winetricks -q dotnet462 vb6run vcrun2015 pdh_nt4 corefonts \
        2>/dev/null || log_warn "Some Wine components may have failed - VarAC might still work"

    # ── Step 4: Install Segoe Emoji font (required by VarAC) ─────────────────
    log_info "Installing Segoe Emoji font (required for VarAC to start)..."
    FONT_DIR="$HOME/.wine_varac/drive_c/windows/Fonts"
    mkdir -p "$FONT_DIR"
    if [ -f "$HOME/.wine/drive_c/windows/Fonts/seguiemj.ttf" ]; then
        cp "$HOME/.wine/drive_c/windows/Fonts/seguiemj.ttf" "$FONT_DIR/" 2>/dev/null || true
    fi
    if [ ! -f "$FONT_DIR/seguiemj.ttf" ]; then
        log_warn "Segoe Emoji not found - downloading Noto Emoji as substitute"
        wget -q -O "$FONT_DIR/seguiemj.ttf" \
            "https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf" \
            2>/dev/null || log_warn "Could not download emoji font - VarAC icons may appear as boxes"
    fi

    # ── Step 5: Fix VARA graphics glitches ───────────────────────────────────
    log_info "Applying Wine registry tweaks for VARA graphics..."
    WINEPREFIX="$HOME/.wine_varac" wine reg add \
        "HKCU\\Software\\Wine\\X11 Driver" /v "Decorated" /t REG_SZ /d "Y" /f 2>/dev/null || true
    WINEPREFIX="$HOME/.wine_varac" wine reg add \
        "HKCU\\Software\\Wine\\X11 Driver" /v "Managed" /t REG_SZ /d "Y" /f 2>/dev/null || true

    # ── Step 6: Install VarAC from user-supplied ZIP ─────────────────────────
    VARAC_DIR="$HOME/.wine_varac/drive_c/VarAC"
    if [ -n "$VARAC_ZIP" ] && [ -f "$VARAC_ZIP" ]; then
        log_info "Installing VarAC from: $VARAC_ZIP"
        mkdir -p "$VARAC_DIR"
        unzip -q -o "$VARAC_ZIP" -d "$VARAC_DIR" || log_warn "Failed to extract VarAC ZIP"
        INNER=$(find "$VARAC_DIR" -maxdepth 1 -name "VarAC.exe" 2>/dev/null | head -1)
        if [ -z "$INNER" ]; then
            SUBDIR=$(find "$VARAC_DIR" -maxdepth 2 -name "VarAC.exe" 2>/dev/null \
                | head -1 | xargs dirname 2>/dev/null)
            if [ -n "$SUBDIR" ] && [ "$SUBDIR" != "$VARAC_DIR" ]; then
                mv "$SUBDIR"/* "$VARAC_DIR"/ 2>/dev/null || true
            fi
        fi
        log_info "VarAC files installed to Wine C: drive"
    else
        log_warn "No VarAC ZIP provided - skipping VarAC file installation"
        log_info "To install later: unzip your VarAC ZIP into $VARAC_DIR"
    fi

    # ── Step 7: Create desktop entry in Ham Radio > Winlink group ────────────
    write_desktop "varac.desktop" \
        "VarAC" "Ham Radio Chat over VARA modem (Wine)" \
        "env WINEPREFIX=$HOME/.wine_varac WINEDEBUG=-all wine $VARAC_DIR/VarAC.exe" \
        "wine" \
        "X-HamRadio;X-HamRadio-Winlink;"

    # ── Step 8: Add user to dialout group for COM/PTT access ─────────────────
    sudo usermod -a -G dialout $USER

    log_info "VarAC installation complete!"
    echo ""
    echo "  To run VarAC:"
    echo "    env WINEPREFIX=$HOME/.wine_varac WINEDEBUG=-all wine $VARAC_DIR/VarAC.exe"
    echo "  Or launch from: Ham Radio > Winlink > VarAC in your applications menu."
    echo ""
    echo "  First-run tips:"
    echo "  - Enable 'Linux Compatible Mode' under Settings"
    echo "  - Set VARA modem path under Settings -> RIG control & VARA Configuration"
    echo "  - COM port PTT: check ~/.wine_varac/dosdevices for your /dev/ttyUSB* mapping"
    log_warn "You may need to log out and back in for dialout group permissions."
    return 0
}

install_all() {
    log_info "Installing all ham radio software packages..."
    log_warn "This will take a significant amount of time. Please be patient."
    echo ""

    local total_steps=14
    local current_step=0

    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_system_prep || true   # also calls install_desktop_directories

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_digital_modes || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_aprs || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_logging || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_sdr || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_morse || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_antenna_modeling || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_winlink || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_satellite || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_utilities || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_hamclock || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_drats || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_voacapl || true

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    log_info "Skipping VarAC in full install (requires manual ZIP download)."
    log_info "Run option 14 separately after downloading VarAC from https://www.varac-hamradio.com/downloadlinux"

    current_step=$((current_step + 1))
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}] - Complete!${NC}"

    log_info "All installations complete!"
    return 0
}

################################################################################
# Main Script
################################################################################

mkdir -p ~/hamradio

while true; do
    show_menu

    case $choice in
        1)
            install_all || true
            echo ""
            log_info "Installation process completed. Check messages above for any failures."
            read -p "Press Enter to exit..."
            break
            ;;
        2)  install_system_prep || true ;;
        3)  install_digital_modes || true ;;
        4)  install_aprs || true ;;
        5)  install_logging || true ;;
        6)  install_sdr || true ;;
        7)  install_morse || true ;;
        8)  install_antenna_modeling || true ;;
        9)  install_winlink || true ;;
        10) install_satellite || true ;;
        11) install_utilities || true ;;
        12) install_hamclock || true ;;
        13) install_dxspider || true ;;
        14) install_varac || true ;;
        15) install_drats || true ;;
        16) install_voacapl || true ;;
        0)  log_info "Exiting..."; exit 0 ;;
        *)  log_error "Invalid option. Please try again."; sleep 2 ;;
    esac

    if [ "$choice" != "0" ] && [ "$choice" != "1" ] && [ "$choice" != "14" ] && [ "$choice" != "15" ]; then
        echo ""
        read -p "Press Enter to continue..."
    fi
done

################################################################################
# Post-installation
################################################################################

log_info "Installation complete!"
echo ""
echo "========================================================"
echo "  Post-Installation Notes"
echo "========================================================"
echo ""
echo "GENERAL"
echo "  • Log out and back in for group permission changes to take effect"
echo "  • All apps appear under 'Ham Radio' in your applications menu"
echo "  • Station: $CALLSIGN  |  Grid: $GRID_SQUARE"
echo ""
echo "DIGITAL MODES"
echo "  • WSJT-X:      wsjtx  (configure station details on first run)"
echo "  • GridTracker: gridtracker"
echo ""
echo "WINLINK / ARDOP"
echo "  • Edit config:  ~/.config/pat/config.json"
echo "  • Run ARDOP:    ardopcf 8515 <capture_dev> <playback_dev>"
echo "  • List devices: aplay -l"
echo "  • As a service: sudo systemctl enable --now ardop@$USER"
echo ""
echo "VARAC  (requires manual install — run menu option 14)"
echo "  • Download ZIP: https://www.varac-hamradio.com/downloadlinux"
echo "  • Enable 'Linux Compatible Mode' on first launch"
echo ""
echo "D-RATS"
echo "  • Run:    d-rats"
echo "  • Update: git -C ~/hamradio/d-rats pull"
echo ""
echo "VOACAPL / VOACAP GUI"
echo "  • GUI: voacapgui"
echo "  • CLI: voacapl ~/itshfbc"
echo "  • If data files are missing, run: makeitshfbc"
echo ""
echo "SDR"
echo "  • RTL-SDR — blacklist DVB-T driver if needed:"
echo "    echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf"
echo "  • SDRPlay drivers: https://www.sdrplay.com/downloads/"
echo ""
echo "========================================================"
echo "  73 de $CALLSIGN"
echo "========================================================"
echo ""
