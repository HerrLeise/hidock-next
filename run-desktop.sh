#!/bin/bash
echo "Starting HiDock Desktop Application..."
echo

# --------------------------------------------------------
# Detect project root (where apps/desktop lives)
# Works whether this script is in:
#   - <root>/run-desktop.sh
#   - <root>/scripts/run-desktop.sh
# and regardless of current working directory.
# --------------------------------------------------------
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

ROOT_DIR=""
CANDIDATE="$SCRIPT_DIR"

# Walk up a few levels to find apps/desktop
for _ in 1 2 3 4; do
    if [ -d "$CANDIDATE/apps/desktop" ]; then
        ROOT_DIR="$CANDIDATE"
        break
    fi
    NEW_CANDIDATE="$(cd "$CANDIDATE/.." && pwd 2>/dev/null || echo "")"
    if [ -z "$NEW_CANDIDATE" ] || [ "$NEW_CANDIDATE" = "$CANDIDATE" ]; then
        break
    fi
    CANDIDATE="$NEW_CANDIDATE"
done

# Fallback: maybe we were started *from* the root directory
if [ -z "$ROOT_DIR" ] && [ -d "apps/desktop" ]; then
    ROOT_DIR="$(pwd)"
fi

if [ -z "$ROOT_DIR" ]; then
    echo "Error: Could not locate project root (directory containing apps/desktop)."
    echo "Script path:  $SCRIPT_PATH"
    echo "Script dir:   $SCRIPT_DIR"
    echo "Current dir:  $(pwd)"
    printf "Press Enter to continue..."; read
    exit 1
fi

cd "$ROOT_DIR" || {
    echo "Error: Failed to navigate to project root at $ROOT_DIR"
    printf "Press Enter to continue..."; read
    exit 1
}

# --------------------------------------------------------
# Check project structure
# --------------------------------------------------------
if [ ! -d "apps/desktop" ]; then
    echo "Error: apps/desktop directory not found in project root!"
    echo "Project root: $ROOT_DIR"
    printf "Press Enter to continue..."; read
    exit 1
fi

VENV_PATH="$ROOT_DIR/apps/desktop/.venv.nix"

# --------------------------------------------------------
# Ensure venv exists (or run setup-unix.sh)
# --------------------------------------------------------
if [ ! -d "$VENV_PATH" ]; then
    echo "Virtual environment not found at:"
    echo "  $VENV_PATH"
    echo
    if [ -f "$ROOT_DIR/setup-unix.sh" ]; then
        echo "It looks like setup has not been run yet."
        echo "Run setup-unix.sh now? (y/N)"
        read -r response
        if case "$response" in [Yy]*) true;; *) false;; esac; then
            cd "$ROOT_DIR" || {
                echo "Error: cannot cd back to project root."
                printf "Press Enter to continue..."; read
                exit 1
            }
            chmod +x ./setup-unix.sh 2>/dev/null || true
            ./setup-unix.sh || {
                echo "Error: setup-unix.sh failed."
                printf "Press Enter to continue..."; read
                exit 1
            }
        else
            echo "Aborting. Please run ./setup-unix.sh manually from the project root."
            printf "Press Enter to continue..."; read
            exit 1
        fi
    else
        echo "Error: virtual environment missing and setup-unix.sh not found."
        echo "Project root: $ROOT_DIR"
        echo "Please ensure you are in the hidock-next project root and run the setup first."
        printf "Press Enter to continue..."; read
        exit 1
    fi
fi

# --------------------------------------------------------
# Activate venv
# --------------------------------------------------------
if [ -f "$VENV_PATH/bin/activate" ]; then
    echo "Activating environment: $VENV_PATH"
    # shellcheck disable=SC1090
    . "$VENV_PATH/bin/activate"
else
    echo "Activation script missing ($VENV_PATH/bin/activate)."
    echo "You may need to recreate the environment by running ./setup-unix.sh"
    printf "Press Enter to continue..."; read
    exit 1
fi

# --------------------------------------------------------
# Go to desktop app and run it
# --------------------------------------------------------
cd "$ROOT_DIR/apps/desktop" || {
    echo "Error: failed to navigate to apps/desktop"
    printf "Press Enter to continue..."; read
    exit 1
}

echo "Checking if main.py exists..."
if [ ! -f "main.py" ]; then
    echo "Error: main.py not found in apps/desktop directory!"
    printf "Press Enter to continue..."; read
    exit 1
fi

echo "Launching HiDock Desktop Application..."
echo
echo "================================"
echo "HiDock Desktop Application"
echo "================================"
echo
echo "To stop the application, close the GUI window or press Ctrl+C here."
echo

# Set UTF-8 encoding to handle emoji characters
export PYTHONIOENCODING=utf-8

PYTHON_IN_VENV="$VENV_PATH/bin/python"
if [ -x "$PYTHON_IN_VENV" ]; then
    "$PYTHON_IN_VENV" main.py
else
    # Fallback: should still be venv python because of 'activate'
    python main.py
fi

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo
    echo "Application exited with an error (exit code: $EXIT_CODE)."
    printf "Press Enter to continue..."; read
fi
