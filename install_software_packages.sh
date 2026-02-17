#!/bin/bash

################################################################################
# Ham Radio Package Installer for Ubuntu 24.04 on X86_64
#
# Installs the following:
# - Digital modes (WSJT-X, JS8Call, FLDigi suite)
# - APRS applications (Xastir, Direwolf, YAAC)
# - Logging applications (CQRLOG, KLog, TrustedQSL)
# - SDR applications (GQRX, CubicSDR, SDRAngel)
# - Morse code applications
# - Antenna modeling (NEC2, Yagiuda)
# - Winlink (Pat Winlink with ARDOP)
# - Satellite tracking (Gpredict, Predict)
# - General ham radio utilities
# - HamClock
# - DX Spider Cluster server
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    echo ""
    echo "0.  Exit"
    echo ""
    read -p "Enter your choice [0-13]: " choice
}

################################################################################
# Installation Functions
################################################################################

install_system_prep() {
    log_info "Installing system dependencies and core utilities..."
    
    sudo apt update
    
    # Core build tools and libraries
    sudo apt install -y \
        build-essential \
        cmake \
        git \
        wget \
        curl \
        ca-certificates \
        gnupg \
        software-properties-common \
        dkms \
        linux-headers-$(uname -r) \
        pkg-config \
        autoconf \
        automake \
        libtool \
        gfortran || true
    
    # Python 3 (default) and development tools
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-dev \
        python3-setuptools \
        python3-wheel \
        python3-venv \
        python3-numpy \
        python3-scipy \
        python3-serial \
        python3-requests \
        python3-yaml || true
    
    # Common libraries
    sudo apt install -y \
        libusb-1.0-0-dev \
        libssl-dev \
        libfftw3-dev \
        libsamplerate0-dev \
        libpulse-dev \
        portaudio19-dev \
        libasound2-dev \
        libsndfile1-dev \
        libxml2-dev \
        libxslt1-dev \
        libhamlib-dev \
        libhamlib4 \
        libhamlib-utils || true
    
    # GTK and Qt libraries for GUI apps
    sudo apt install -y \
        libgtk-3-dev \
        qtbase5-dev \
        qttools5-dev \
        qtmultimedia5-dev || true
    
    log_info "System preparation complete!"
    return 0
}

install_gridtracker() {
    log_info "Installing GridTracker..."
    
    # Install Node.js if not already installed
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
    
    # Determine the correct package based on architecture
    if [ "$ARCH" = "amd64" ]; then
        GT_PACKAGE="GridTracker2-2.250914.1-amd64.deb"
    elif [ "$ARCH" = "arm64" ]; then
        GT_PACKAGE="GridTracker2-2.250914.1-arm64.deb"
    elif [ "$ARCH" = "armhf" ] || [ "$ARCH" = "armv7l" ]; then
        GT_PACKAGE="GridTracker2-2.250914.1-armv7l.deb"
    else
        log_warn "GridTracker not available for architecture: $ARCH"
        log_info "Visit https://gridtracker.org/ for other options"
        return 0
    fi
    
    log_info "Downloading GridTracker for $ARCH..."
    
    # Download from the official download server
    if wget -q --show-progress "https://download2.gridtracker.org/${GT_PACKAGE}" 2>/dev/null; then
        log_info "Installing GridTracker..."
        
        # Install the package
        sudo dpkg -i "${GT_PACKAGE}" 2>/dev/null || {
            log_info "Fixing dependencies..."
            sudo apt --fix-broken install -y
        }
        
        # Clean up
        rm -f "${GT_PACKAGE}"
        
        log_info "GridTracker installed successfully!"
        log_info "You can launch it from your applications menu or run: gridtracker"
    else
        log_warn "Failed to download GridTracker"
        log_info "You can manually download from: https://gridtracker.org/index.php/downloads/gridtracker-downloads"
    fi
    
    return 0
}

install_digital_modes() {
    log_info "Installing digital mode applications..."
    
    # WSJT-X from Ubuntu repositories
    safe_install "wsjtx" "WSJT-X" || true
    
    # GridTracker (requires Node.js)
    install_gridtracker || true
    
    # FLDigi suite - check availability for each package
    log_info "Installing FLDigi suite..."
    safe_install "fldigi" "FLDigi" || true
    safe_install "flrig" "FLRig" || true
    safe_install "flmsg" "FLMsg" || true
    safe_install "flamp" "FLAmp" || true
    
    # Other digital modes - check each one
    log_info "Installing other digital mode applications..."
    safe_install "xlog" "XLog" || true
    
    # These older apps are not in 24.04
    log_warn "Some legacy apps (linpsk, psk31lx, twpsk, flarq) are not available in Ubuntu 24.04"
    
    # QSSTV
    safe_install "qsstv" "QSSTV" || true
    
    log_info "Digital mode applications installation complete!"
    return 0
}

install_aprs() {
    log_info "Installing APRS applications..."
    
    # Xastir
    safe_install "xastir" "Xastir" || true
    
    # Direwolf - available in Ubuntu 24.04
    safe_install "direwolf" "Direwolf" || true
    
    # YAAC - requires Java
    sudo apt install -y default-jre || true
    
    # Other APRS tools
    safe_install "aprx" "APRx" || true
    safe_install "aprsdigi" "APRS Digi" || true
    
    log_info "APRS applications installed!"
    return 0
}

install_logging() {
    log_info "Installing logging applications..."
    
    # CQRLOG - from repositories
    safe_install "cqrlog" "CQRLOG" || true
    
    # KLog
    safe_install "klog" "KLog" || true
    
    # TrustedQSL for LotW
    safe_install "trustedqsl" "TrustedQSL" || true
    
    # PyQSO
    safe_install "pyqso" "PyQSO" || true
    
    # Contest logging
    safe_install "tlf" "TLF Contest Logger" || true
    
    log_info "Logging applications installed!"
    return 0
}

install_sdr() {
    log_info "Installing SDR applications and drivers..."
    
    # SoapySDR framework
    sudo apt install -y \
        soapysdr-tools \
        soapysdr-module-all || true
    
    # RTL-SDR support
    sudo apt install -y \
        rtl-sdr \
        librtlsdr-dev || true
    
    # Add user to plugdev group for USB access
    sudo usermod -a -G plugdev $USER
    
    # SDR applications
    safe_install "gqrx-sdr" "GQRX" || true
    safe_install "cubicsdr" "CubicSDR" || true
    safe_install "quisk" "Quisk" || true
    safe_install "cutesdr" "CuteSDR" || true
    
    log_info "SDR applications installed!"
    log_warn "You may need to log out and back in for USB permissions to take effect."
    log_info "Note: SDRPlay drivers must be downloaded manually from https://www.sdrplay.com/downloads/"
    return 0
}

install_morse() {
    log_info "Installing Morse code applications..."
    
    # Install available morse packages
    safe_install "aldo" "Aldo Morse trainer" || true
    safe_install "cw" "CW sound generator" || true
    safe_install "cwcp" "CW text trainer" || true
    safe_install "xcwcp" "XCW graphical trainer" || true
    safe_install "morse" "Morse code trainer" || true
    safe_install "morse2ascii" "Morse decoder" || true
    safe_install "morsegen" "Morse generator" || true
    safe_install "qrq" "High speed Morse trainer" || true
    safe_install "xdemorse" "Morse decoder" || true
    
    log_info "Morse code applications installation complete!"
    return 0
}

install_antenna_modeling() {
    log_info "Installing antenna modeling software..."
    
    safe_install "nec2c" "NEC2 antenna modeler" || true
    safe_install "xnec2c" "NEC2 GUI" || true
    safe_install "yagiuda" "Yagi antenna analysis" || true
    
    log_info "Antenna modeling software installation complete!"
    return 0
}

install_winlink() {
    log_info "Installing Pat Winlink..."
    
    # Install Pat from releases
    cd /tmp
    PAT_VERSION=$(curl -s https://api.github.com/repos/la5nta/pat/releases/latest | grep -oP '"tag_name": "v\K[^"]+' 2>/dev/null)
    
    if [ -z "$PAT_VERSION" ]; then
        log_warn "Could not determine Pat version"
        PAT_VERSION="0.15.1"  # Fallback version
    fi
    
    log_info "Installing Pat v${PAT_VERSION}..."
    
    ARCH=$(dpkg --print-architecture)
    if wget -q "https://github.com/la5nta/pat/releases/download/v${PAT_VERSION}/pat_${PAT_VERSION}_linux_${ARCH}.deb" -O pat.deb 2>/dev/null; then
        sudo dpkg -i pat.deb || sudo apt --fix-broken install -y
        rm -f pat.deb
        
        # Configure Pat
        mkdir -p ~/.config/pat
        pat configure || log_info "Pat configuration file created at ~/.config/pat/config.json"
        
        log_info "Pat Winlink installed!"
    else
        log_warn "Failed to download Pat"
        log_info "You can manually download from: https://github.com/la5nta/pat/releases"
    fi
    
    # Install AX.25 tools
    sudo apt install -y ax25-tools ax25-apps || log_warn "AX.25 tools not available"
    
    return 0
}

install_satellite() {
    log_info "Installing satellite tracking software..."
    
    safe_install "gpredict" "Gpredict" || true
    
    log_info "Satellite tracking software installation complete!"
    return 0
}

install_utilities() {
    log_info "Installing general ham radio utilities..."
    
    # HamLib tools
    safe_install "libhamlib-utils" "HamLib utilities" || true
    
    # CHIRP for radio programming
    safe_install "chirp" "CHIRP radio programmer" || true
    
    # FreeDV
    safe_install "freedv" "FreeDV digital voice" || true
    
    # GPS support
    safe_install "gpsd" "GPS daemon" || true
    safe_install "gpsd-clients" "GPS clients" || true
    safe_install "python3-gps" "Python GPS support" || true
    
    # DX Cluster client
    safe_install "xdx" "DX Cluster client" || true
    
    # Other utilities
    safe_install "fccexam" "FCC exam study" || true
    safe_install "hamexam" "Ham exam study" || true
    safe_install "wwl" "Maidenhead locator calculator" || true
    safe_install "splat" "RF terrain analysis" || true
    
    log_warn "Some utilities (gcb, colrconv, d-rats, voacapl) are not available in Ubuntu 24.04"
    
    log_info "General utilities installation complete!"
    return 0
}

install_hamclock() {
    log_info "Installing HamClock..."
    log_warn "HamClock requires building from source and may take 10-15 minutes"
    
    # Install dependencies
    sudo apt install -y \
        libx11-dev \
        fonts-dejavu \
        unzip || {
        log_warn "Failed to install HamClock dependencies"
        return 0
    }
    
    mkdir -p ~/hamradio
    cd ~/hamradio
    
    # Download HamClock
    if wget -q --show-progress https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.zip; then
        unzip -q -o ESPHamClock.zip
        cd ESPHamClock
        
        log_info "Building HamClock (this may take a while)..."
        
        # Build 800x480 version (common for small displays)
        if make -j$(nproc) hamclock-800x480 2>/dev/null; then
            sudo cp hamclock-800x480 /usr/local/bin/ 2>/dev/null
            sudo ln -sf /usr/local/bin/hamclock-800x480 /usr/local/bin/hamclock
            
            # Create desktop launcher
            mkdir -p ~/.local/share/applications
            cat > ~/.local/share/applications/hamclock.desktop <<'HAMCLOCK_EOF'
[Desktop Entry]
Type=Application
Name=HamClock
Comment=Ham Radio Clock and Information Display
Exec=/usr/local/bin/hamclock
Icon=hamradio
Terminal=false
Categories=HamRadio;Utility;
HAMCLOCK_EOF
            
            log_info "HamClock installed successfully!"
            log_info "Run with: hamclock"
        else
            log_warn "HamClock build failed"
        fi
        
        cd ~/hamradio
        rm -f ESPHamClock.zip
    else
        log_warn "Failed to download HamClock"
        log_info "You can manually download from: https://www.clearskyinstitute.com/ham/HamClock/"
    fi
    
    return 0
}

install_dxspider() {
    log_info "Installing DX Spider Cluster server..."
    
    # Install Perl and dependencies
    sudo apt install -y \
        perl \
        libnet-telnet-perl \
        libcurses-perl \
        libtime-hires-perl \
        libdigest-sha-perl || {
        log_warn "Failed to install DX Spider dependencies"
        return 0
    }
    
    log_info "DX Spider requires manual configuration"
    log_info "Visit http://www.dxcluster.org/ for installation instructions"
    
    return 0
}

install_all() {
    log_info "Installing all ham radio software packages..."
    log_warn "This will take a significant amount of time. Please be patient."
    echo ""
    
    local total_steps=11
    local current_step=0
    
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}]${NC}"
    install_system_prep || true
    
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
    echo -e "${CYAN}Progress: [${current_step}/${total_steps}] - Complete!${NC}"
    
    log_info "All installations complete!"
    return 0
}

################################################################################
# Main Script
################################################################################

# Create hamradio directory
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
        2) install_system_prep || true ;;
        3) install_digital_modes || true ;;
        4) install_aprs || true ;;
        5) install_logging || true ;;
        6) install_sdr || true ;;
        7) install_morse || true ;;
        8) install_antenna_modeling || true ;;
        9) install_winlink || true ;;
        10) install_satellite || true ;;
        11) install_utilities || true ;;
        12) install_hamclock || true ;;
        13) install_dxspider || true ;;
        0) log_info "Exiting..."; exit 0 ;;
        *) log_error "Invalid option. Please try again."; sleep 2 ;;
    esac
    
    if [ "$choice" != "0" ] && [ "$choice" != "1" ]; then
        echo ""
        read -p "Press Enter to continue..."
    fi
done

################################################################################
# Post-installation
################################################################################

log_info "Installation complete!"
echo ""
echo "================================================"
echo "  Post-Installation Notes"
echo "================================================"
echo ""
echo "1. Some applications may require logout/login for group permissions"
echo "2. Configure applications with your callsign: $CALLSIGN"
echo "3. Your grid square: $GRID_SQUARE"
echo "4. RTL-SDR users: Blacklist DVB-T drivers if needed:"
echo "   echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf"
echo "5. For WSJT-X: Run 'wsjtx' and configure your station details"
echo "6. For Pat Winlink: Edit ~/.config/pat/config.json with your info"
echo "7. For GridTracker: Launch from applications menu or run 'gridtracker'"
echo "8. Check ~/hamradio/ for additional installed applications"
echo ""
echo "================================================"
echo "  73 and happy hamming, $CALLSIGN!"
echo "================================================"
echo ""
