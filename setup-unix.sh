#!/bin/sh
# HiDock Next - Simple Linux/Mac Setup
# Run: chmod +x setup-unix.sh && ./setup-unix.sh

set -e  # Exit on any error

echo ""
echo "================================"
echo "   HiDock Next - Quick Setup"
echo "================================"
echo ""
echo "This will set up HiDock apps for immediate use."
echo ""

# ----------------------------------------
# 1/4 – Python prüfen / installieren
# ----------------------------------------
echo "[1/4] Checking Python..."
if command -v python3 > /dev/null 2>&1; then
    PYTHON_CMD="python3"
    echo "✓ Python3 found!"
elif command -v python > /dev/null 2>&1; then
    PYTHON_CMD="python"
    echo "✓ Python found!"
else
    echo "❌ Python not found. Installing Python 3.12..."
    echo "Continue? (y/N)"
    read -r response
    if case "$response" in [Yy]*) true;; *) false;; esac; then
        if command -v apt > /dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3.12 python3.12-venv python3.12-pip
            PYTHON_CMD="python3.12"
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y python3.12 python3.12-pip python3.12-venv
            PYTHON_CMD="python3.12"
        else
            echo "❌ Cannot auto-install. Please install Python 3.12+ manually."
            exit 1
        fi
        echo "✓ Python 3.12 installed!"
    else
        echo "Setup cancelled."
        exit 1
    fi
fi

# Python-Version prüfen (min. 3.8)
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
PYTHON_VER_NUM=$((PYTHON_MAJOR * 10 + PYTHON_MINOR))

if [ "$PYTHON_VER_NUM" -lt 38 ]; then
    echo "❌ Python 3.8+ required, found $PYTHON_VERSION. Upgrading to 3.12..."
    echo "Continue? (y/N)"
    read -r response
    if case "$response" in [Yy]*) true;; *) false;; esac; then
        if command -v apt > /dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3.12 python3.12-venv python3.12-pip
            PYTHON_CMD="python3.12"
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y python3.12 python3.12-pip python3.12-venv
            PYTHON_CMD="python3.12"
        else
            echo "❌ Cannot auto-upgrade. Please install Python 3.12+ manually."
            exit 1
        fi
        echo "✓ Python 3.12 installed!"
    else
        echo "Setup cancelled."
        exit 1
    fi
fi

# ----------------------------------------
# 2/4 – Systemabhängigkeiten + Build-Toolchain
# ----------------------------------------
echo ""
echo "[2/4] Installing system and build dependencies (libusb, tkinter, SDL2, freetype, compiler)..."
echo "This may install development tools and libraries required for pygame."
echo "Continue? (y/N)"
read -r response
if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    if command -v apt > /dev/null 2>&1; then
        # Ubuntu/Debian
        sudo apt update
        sudo apt install -y \
            build-essential \
            python3-dev \
            libusb-1.0-0-dev \
            python3-tk \
            libsdl2-dev \
            libsdl2-image-dev \
            libsdl2-mixer-dev \
            libsdl2-ttf-dev \
            libfreetype6-dev \
            pkg-config
    elif command -v dnf > /dev/null 2>&1 || command -v dnf5 > /dev/null 2>&1; then
        # Fedora/RHEL 8+/dnf5
        DNF_CMD="dnf"
        command -v dnf5 > /dev/null 2>&1 && DNF_CMD="dnf5"
        # Install minimal toolchain (dnf5 may not support groupinstall yet)
        sudo "$DNF_CMD" install -y \
            gcc \
            python3-devel \
            libusb1-devel \
            python3-tkinter \
            SDL2-devel \
            SDL2_image-devel \
            SDL2_mixer-devel \
            SDL2_ttf-devel \
            freetype-devel \
            pkgconf-pkg-config
        sudo "$DNF_CMD" install -y python3-tkinter tk
    elif command -v yum > /dev/null 2>&1; then
        # CentOS/RHEL 7
        sudo yum groupinstall -y "Development Tools" || true
        sudo yum install -y \
            gcc \
            python3-devel \
            libusb1-devel \
            tkinter \
            SDL2-devel \
            SDL2_image-devel \
            SDL2_mixer-devel \
            SDL2_ttf-devel \
            freetype-devel \
            pkgconfig
    elif command -v pacman > /dev/null 2>&1; then
        # Arch Linux
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm \
            base-devel \
            python \
            libusb \
            python-tkinter \
            sdl2 \
            sdl2_image \
            sdl2_mixer \
            sdl2_ttf \
            freetype2 \
            pkgconf
    elif command -v brew > /dev/null 2>&1; then
        # macOS (Homebrew)
        brew update
        brew install \
            libusb \
            sdl2 \
            sdl2_image \
            sdl2_mixer \
            sdl2_ttf \
            freetype
        # tkinter kommt i.d.R. mit Python auf macOS
    else
        echo "⚠️  Cannot auto-install system packages."
        echo "Please install at least:"
        echo "  - C compiler + build tools"
        echo "  - python3-dev / python3-devel"
        echo "  - libusb dev libraries"
        echo "  - tkinter / python3-tk"
        echo "  - SDL2 (dev), SDL2_image, SDL2_mixer, SDL2_ttf"
        echo "  - freetype dev libraries"
        echo "  - pkg-config"
    fi
    echo "✅ System & build dependencies step finished (check above for any warnings)."
else
    echo "⚠️  Skipping system/build dependencies. pygame build may fail."
fi

# ----------------------------------------
# 2b/4 – Optional: install udev rule for HiDock USB access (Linux)
# ----------------------------------------
if [ "$(uname)" = "Linux" ]; then
    echo ""
    echo "[2b/4] Install udev rule for HiDock USB access (adds 99-hidock.rules, needs sudo)? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        # Consolidated rule covering all known PIDs
        UDEV_RULE_CONTENT='
# HiDock USB Device Access Rules
SUBSYSTEM=="usb", ATTR{idVendor}=="10d6", ATTR{idProduct}=="af0c", MODE="0666", GROUP="dialout", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="10d6", ATTR{idProduct}=="af0d", MODE="0666", GROUP="dialout", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="10d6", ATTR{idProduct}=="b00d", MODE="0666", GROUP="dialout", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="10d6", ATTR{idProduct}=="af0e", MODE="0666", GROUP="dialout", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="10d6", ATTR{idProduct}=="b00e", MODE="0666", GROUP="dialout", TAG+="uaccess"
# Fallback for any Actions Semiconductor HiDock devices
SUBSYSTEM=="usb", ATTR{idVendor}=="10d6", MODE="0666", GROUP="dialout", TAG+="uaccess"
'
        echo "Writing udev rule to /etc/udev/rules.d/99-hidock.rules ..."
        printf "%s" "$UDEV_RULE_CONTENT" | sudo tee /etc/udev/rules.d/99-hidock.rules >/dev/null || {
            echo "❌ Failed to write udev rule (sudo/permission issue)"; exit 1; }
        echo "Reloading udev rules..."
        sudo udevadm control --reload-rules && sudo udevadm trigger || \
            echo "⚠️  udev reload/trigger failed; you may need to replug the device or reboot"
        echo "✅ udev rule installed."
    else
        echo "ℹ️ Skipping udev rule install. You may need to run the app with sudo or add the rule manually for USB access."
    fi
fi

# ----------------------------------------
# Desktop-App: venv + Python-Dependencies
# ----------------------------------------
echo ""
echo "[3/4] Setting up Desktop App (virtualenv + Python deps)..."

cd apps/desktop || {
    echo "❌ Failed to navigate to apps/desktop directory"
    exit 1
}

echo "Setting up local virtual environment in apps/desktop/.venv.nix ..."
VENV_PATH=".venv.nix"

if [ ! -d "$VENV_PATH" ]; then
  echo "Creating virtual environment at: $PWD/$VENV_PATH"
  "$PYTHON_CMD" -m venv "$VENV_PATH" || {
    echo "❌ Failed to create virtual environment"; exit 1; }
fi

if [ ! -x "$VENV_PATH/bin/python" ]; then
  echo "❌ python executable missing inside venv (corrupted). Recreating..."
  rm -rf "$VENV_PATH"
  "$PYTHON_CMD" -m venv "$VENV_PATH" || {
    echo "❌ Recreate failed"; exit 1; }
fi

echo "Using environment: $PWD/$VENV_PATH"

# Ensure pip exists inside the venv (some distros disable ensurepip by default)
if ! "$VENV_PATH/bin/python" -m pip --version >/dev/null 2>&1; then
  echo "Bootstrapping pip inside the virtual environment..."
  "$VENV_PATH/bin/python" -m ensurepip --upgrade >/dev/null 2>&1 || true
fi
if ! "$VENV_PATH/bin/python" -m pip --version >/dev/null 2>&1; then
  echo "❌ pip is still unavailable inside the virtual environment."
  echo "Please install the system pip package (e.g., python3-pip) and rerun setup-unix.sh."
  exit 1
fi

echo "Upgrading pip and build tooling..."
"$VENV_PATH/bin/python" -m pip install --upgrade pip setuptools wheel || \
  echo "⚠️  pip upgrade failed (continuing)"

echo "Installing desktop dependencies (editable, dev extras)..."
# Wir sind in apps/desktop, daher reicht ".[dev]"
"$VENV_PATH/bin/python" -m pip install -e ".[dev]" || {
  echo "❌ Failed to install desktop dependencies"; exit 1; }

echo "✅ Desktop app setup complete!"

# ----------------------------------------
# Node.js / Web-Apps
# ----------------------------------------
echo ""
echo "[4/4] Checking Node.js for Web Apps..."
WEB_APP_READY=false

if command -v node > /dev/null 2>&1; then
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -ge 18 ]; then
        echo "✓ Node.js found! Setting up web apps..."
        WEB_APP_READY=true

        echo "Setting up HiDock Web App..."
        cd ../web || {
            echo "⚠️  WARNING: Failed to navigate to apps/web"
            WEB_APP_READY=false
        }
        if [ "$WEB_APP_READY" != false ]; then
            npm install || {
                echo "⚠️  WARNING: Web app setup failed"
                WEB_APP_READY=false
            }
            echo "✅ Web app setup complete!"
            cd ../desktop
        fi

        echo "Setting up Audio Insights Extractor..."
        cd ../audio-insights || {
            echo "⚠️  WARNING: Failed to navigate to apps/audio-insights"
            WEB_APP_READY=false
        }
        if [ "$WEB_APP_READY" != false ]; then
            npm install || {
                echo "⚠️  WARNING: Audio Insights Extractor setup failed"
                WEB_APP_READY=false
            }
            echo "✅ Audio Insights Extractor setup complete!"
            cd ../desktop
        fi
    else
        echo "⚠️  Node.js version $NODE_VERSION found, but 18+ required"
        echo "Update Node.js if you want the web apps"
        WEB_APP_READY=false
    fi
else
    echo "ℹ️  Node.js not found. Installing Node.js 18+ for web apps..."
    echo "Continue? (y/N)"
    read -r response
    if case "$response" in [Yy]*) true;; *) false;; esac; then
        if command -v apt > /dev/null 2>&1; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y nodejs npm
        else
            echo "❌ Cannot auto-install Node.js. Please install manually."
            WEB_APP_READY=false
        fi

        if command -v node > /dev/null 2>&1; then
            NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
            if [ "$NODE_VERSION" -ge 18 ]; then
                echo "✓ Node.js installed! Setting up web apps..."
                WEB_APP_READY=true

                echo "Setting up HiDock Web App..."
                cd ../web || {
                    echo "⚠️  WARNING: Failed to navigate to apps/web"
                    WEB_APP_READY=false
                }
                if [ "$WEB_APP_READY" != false ]; then
                    npm install || {
                        echo "⚠️  WARNING: Web app setup failed"
                        WEB_APP_READY=false
                    }
                    echo "✅ Web app setup complete!"
                    cd ../desktop
                fi

                echo "Setting up Audio Insights Extractor..."
                cd ../audio-insights || {
                    echo "⚠️  WARNING: Failed to navigate to apps/audio-insights"
                    WEB_APP_READY=false
                }
                if [ "$WEB_APP_READY" != false ]; then
                    npm install || {
                        echo "⚠️  WARNING: Audio Insights Extractor setup failed"
                        WEB_APP_READY=false
                    }
                    echo "✅ Audio Insights Extractor setup complete!"
                    cd ../desktop
                fi
            else
                echo "⚠️  Node.js installation failed or version too old"
                WEB_APP_READY=false
            fi
        else
            echo "⚠️  Node.js installation failed"
            WEB_APP_READY=false
        fi
    else
        echo "(Desktop app will work without Node.js)"
        WEB_APP_READY=false
    fi
fi

# ----------------------------------------
# Abschluss / Hinweise
# ----------------------------------------
echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo ""
echo "🚀 HOW TO RUN:"
echo ""
echo "Desktop App:"
echo "  1. cd apps/desktop"
echo "  2. . .venv.nix/bin/activate"
echo "  3. python main.py"
echo ""

if [ "$WEB_APP_READY" = true ]; then
    echo "Web App:"
    echo "  1. cd apps/web"
    echo "  2. npm run dev"
    echo "  3. Open: http://localhost:5173"
    echo ""
fi

echo "💡 FIRST TIME TIPS:"
echo "• Configure AI providers in app Settings for transcription"
echo "• Connect your HiDock device via USB"
echo "• Check README.md and docs/TROUBLESHOOTING.md for help"

# Linux USB permissions check
if [ "$(uname)" = "Linux" ]; then
    if ! groups "$USER" | grep -q "dialout"; then
        echo ""
        echo "⚠️  Setting up USB permissions for HiDock device access..."
        echo "Continue? (y/N)"
        read -r response
        if case "$response" in [Yy]*) true;; *) false;; esac; then
            sudo usermod -a -G dialout "$USER"
            echo "✅ USB permissions configured. Please log out and back in for changes to take effect."
        else
            echo "⚠️  USB permissions not configured. You may need to run manually:"
            echo "  sudo usermod -a -G dialout \$USER"
        fi
    fi
fi

echo ""
echo "🔧 NEED MORE? Run (optional, outside venv): $PYTHON_CMD setup.py"
echo ""
echo "Enjoy using HiDock! 🎵"
echo ""
