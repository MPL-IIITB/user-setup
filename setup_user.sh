#!/bin/bash

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}── $1 ──────────────────────────────────────${NC}"; }

[[ $EUID -ne 0 ]] && error "Run as root: sudo $0"

# ── Inputs ────────────────────────────────────────────────────
section "User"
read -rp "Username: " USERNAME
[[ -z "$USERNAME" ]] && error "Username is required"

while true; do
    read -rsp "Password: " PASSWORD; echo
    [[ -z "$PASSWORD" ]] && { warn "Password cannot be empty"; continue; }
    read -rsp "Confirm password: " PASSWORD2; echo
    [[ "$PASSWORD" == "$PASSWORD2" ]] && break
    warn "Passwords do not match, try again"
done

read -rp "Grant sudo access? [y/N]: " GRANT_SUDO

section "SSH Key"
read -rp "SSH key name (e.g. lab_key): " SSH_KEY_NAME
[[ -z "$SSH_KEY_NAME" ]] && error "SSH key name is required"

section "Miniconda"
read -rp "Install Miniconda? [y/N]: " INSTALL_CONDA
CONDA_ENVS_DIR=""
if [[ "${INSTALL_CONDA,,}" == "y" ]]; then
    read -rp "Conda envs directory (full path): " CONDA_ENVS_DIR
    [[ -z "$CONDA_ENVS_DIR" ]] && error "Conda envs directory is required"
fi

section "switch-cuda"
read -rp "CUDA version [11.8]: " CUDA_VERSION
CUDA_VERSION="${CUDA_VERSION:-11.8}"

section "Extra Paths"
read -rp "Extra data/code paths (comma-separated, blank to skip): " EXTRA_PATHS_INPUT

# ── Derived ───────────────────────────────────────────────────
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
BASHRC="$USER_HOME/.bashrc"

# ── Create user ───────────────────────────────────────────────
section "Creating user"
if id "$USERNAME" &>/dev/null; then
    warn "User '$USERNAME' already exists, skipping creation"
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    info "User '$USERNAME' created"
fi

if [[ "${GRANT_SUDO,,}" == "y" ]]; then
    usermod -aG sudo "$USERNAME"
    info "Added '$USERNAME' to sudo group"
fi

# ── SSH key pair ──────────────────────────────────────────────
section "SSH key pair"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

KEY_PATH="$SSH_DIR/$SSH_KEY_NAME"
if [[ -f "$KEY_PATH" ]]; then
    warn "Key '$SSH_KEY_NAME' already exists, skipping generation"
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$USERNAME@$(hostname)"
    cat "${KEY_PATH}.pub" >> "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
    info "Key pair created: $KEY_PATH"
fi
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# ── Extra paths ───────────────────────────────────────────────
if [[ -n "$EXTRA_PATHS_INPUT" ]]; then
    section "Extra paths"
    IFS=',' read -ra EXTRA_DIRS <<< "$EXTRA_PATHS_INPUT"
    for DIR in "${EXTRA_DIRS[@]}"; do
        DIR="$(echo "$DIR" | xargs)"
        [[ -z "$DIR" ]] && continue
        mkdir -p "$DIR"
        chown "$USERNAME:$USERNAME" "$DIR"
        info "Ready: $DIR"
    done
fi

# ── Miniconda ─────────────────────────────────────────────────
if [[ "${INSTALL_CONDA,,}" == "y" ]]; then
    section "Miniconda"
    CONDA_INSTALL_DIR="$USER_HOME/miniconda3"
    MINICONDA_SCRIPT="/tmp/Miniconda3-latest-Linux-x86_64.sh"

    if [[ -d "$CONDA_INSTALL_DIR" ]]; then
        warn "Miniconda already present at $CONDA_INSTALL_DIR, skipping install"
    else
        info "Downloading Miniconda..."
        curl -fL -o "$MINICONDA_SCRIPT" \
            https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

        info "Installing to $CONDA_INSTALL_DIR..."
        runuser -l "$USERNAME" -c "bash \"$MINICONDA_SCRIPT\" -b -p \"$CONDA_INSTALL_DIR\""
        rm -f "$MINICONDA_SCRIPT"
        info "Miniconda installed"
    fi

    info "Running conda init..."
    runuser -l "$USERNAME" -c "\"$CONDA_INSTALL_DIR/bin/conda\" init bash"

    mkdir -p "$CONDA_ENVS_DIR"

    cat > "$USER_HOME/.condarc" << EOF
envs_dirs:
  - $CONDA_ENVS_DIR
EOF
    chown "$USERNAME:$USERNAME" "$USER_HOME/.condarc"
    info "Conda envs directory: $CONDA_ENVS_DIR"
fi

# ── switch-cuda ───────────────────────────────────────────────
section "switch-cuda"
SWITCH_CUDA_DIR="$USER_HOME/switch-cuda"

if [[ -d "$SWITCH_CUDA_DIR" ]]; then
    warn "switch-cuda already present, skipping clone"
else
    runuser -l "$USERNAME" -c "git clone https://github.com/phohenecker/switch-cuda.git \"$SWITCH_CUDA_DIR\""
    info "switch-cuda cloned to $SWITCH_CUDA_DIR"
fi

SWITCH_LINE="source ~/switch-cuda/switch-cuda.sh $CUDA_VERSION"
if grep -qF "switch-cuda.sh" "$BASHRC" 2>/dev/null; then
    warn "switch-cuda already in .bashrc, skipping"
else
    echo "$SWITCH_LINE" >> "$BASHRC"
    info "Added to .bashrc: $SWITCH_LINE"
fi

# ── Summary & checklist ───────────────────────────────────────
echo
echo "════════════════════════════════════════════════════════"
echo "  Setup complete: $USERNAME"
echo "════════════════════════════════════════════════════════"
echo
echo "  Private key: $KEY_PATH"
echo "  Public key:  ${KEY_PATH}.pub"
echo
echo "  Developer Checklist"
echo "  ────────────────────────────────────────────────────"
echo "  [ ] Copy private key to your machine:"
echo "      scp root@<host>:$KEY_PATH ~/.ssh/$SSH_KEY_NAME"
echo "      chmod 600 ~/.ssh/$SSH_KEY_NAME"
echo
echo "  [ ] SSH in:"
echo "      ssh -i ~/.ssh/$SSH_KEY_NAME $USERNAME@<host>"
echo
echo "  [ ] Reload shell environment:"
echo "      source ~/.bashrc"
echo
echo "  [ ] Verify CUDA switch:"
echo "      nvcc --version   # should reflect CUDA $CUDA_VERSION"
echo
if [[ "${INSTALL_CONDA,,}" == "y" ]]; then
    echo "  [ ] Verify conda:"
    echo "      conda --version"
    echo
    echo "  [ ] Create your conda environment:"
    echo "      conda create -n <env_name> python=3.x"
    echo "      # Will be created under: $CONDA_ENVS_DIR"
    echo
    echo "  [ ] Activate and verify:"
    echo "      conda activate <env_name>"
    echo "      conda env list   # confirm path"
    echo
fi
if [[ -n "$EXTRA_PATHS_INPUT" ]]; then
    echo "  [ ] Verify extra paths are accessible:"
    IFS=',' read -ra EXTRA_DIRS <<< "$EXTRA_PATHS_INPUT"
    for DIR in "${EXTRA_DIRS[@]}"; do
        DIR="$(echo "$DIR" | xargs)"
        [[ -z "$DIR" ]] && continue
        echo "      ls $DIR"
    done
    echo
fi
echo "════════════════════════════════════════════════════════"
