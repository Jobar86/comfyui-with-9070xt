#!/bin/bash

#===============================================================================
# ComfyUI Installation Script for Ubuntu 24.04 LTS with AMD RX 9070 XT (RDNA 4)
#===============================================================================
#
# This script is IDEMPOTENT - safe to run multiple times!
# It will:
#   - Check what's already installed
#   - Update existing components if needed
#   - Install only what's missing
#
# Components:
#   - AMD AMDGPU drivers (ROCm 7.1.1)
#   - ROCm software stack
#   - Python virtual environment with PyTorch ROCm (RDNA 4 optimized)
#   - ComfyUI with manager and dependencies
#
# Requirements:
#   - Ubuntu 24.04.3 LTS (Noble Numbat)
#   - AMD RX 9070 XT GPU
#   - Sudo privileges
#   - Internet connection
#
# Usage: 
#   chmod +x install_comfyui_rx9070xt.sh
#   ./install_comfyui_rx9070xt.sh
#
# Author: Antigravity AI Assistant
# Date: December 2024
#===============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
COMFYUI_DIR="${HOME}/ComfyUI"
VENV_DIR="${COMFYUI_DIR}/venv"
ROCM_VERSION="7.1.1"
ROCM_VERSION_SHORT="70101"
AMDGPU_INSTALL_PKG="amdgpu-install_${ROCM_VERSION}.${ROCM_VERSION_SHORT}-1_all.deb"
AMDGPU_INSTALL_URL="https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/${AMDGPU_INSTALL_PKG}"

# Installation state tracking
NEEDS_REBOOT=false
INSTALLED_ITEMS=()
UPDATED_ITEMS=()
SKIPPED_ITEMS=()

#===============================================================================
# Helper Functions
#===============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_check() {
    echo -e "${MAGENTA}[CHECK]${NC} $1"
}

print_skip() {
    echo -e "${CYAN}[SKIP]${NC} $1"
}

print_update() {
    echo -e "${YELLOW}[UPDATE]${NC} $1"
}

#===============================================================================
# Pip wrapper - ALWAYS use venv pip to avoid PEP 668 errors
#===============================================================================

# Run pip command using venv's pip directly (avoids externally-managed-environment error)
venv_pip() {
    if [ -f "${VENV_DIR}/bin/pip" ]; then
        "${VENV_DIR}/bin/pip" "$@"
    else
        print_error "Virtual environment pip not found at ${VENV_DIR}/bin/pip"
        return 1
    fi
}

# Run python command using venv's python directly
venv_python() {
    if [ -f "${VENV_DIR}/bin/python" ]; then
        "${VENV_DIR}/bin/python" "$@"
    else
        print_error "Virtual environment python not found at ${VENV_DIR}/bin/python"
        return 1
    fi
}

#===============================================================================
# Detection Functions
#===============================================================================

check_ubuntu_version() {
    print_check "Checking Ubuntu version..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$VERSION_ID" != "24.04" ]]; then
            print_warning "This script is designed for Ubuntu 24.04 LTS."
            print_warning "Detected: $PRETTY_NAME"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_success "Ubuntu 24.04 LTS detected"
        fi
    fi
}

check_gpu() {
    print_check "Detecting AMD GPU..."
    if lspci | grep -i "VGA\|Display" | grep -qi "AMD\|ATI"; then
        GPU_INFO=$(lspci | grep -i "VGA\|Display" | grep -i "AMD\|ATI")
        print_success "AMD GPU detected: $GPU_INFO"
        return 0
    else
        print_warning "No AMD GPU detected. The script will continue, but may not work correctly."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
}

# Check if a package is installed
is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Get installed package version
get_package_version() {
    dpkg -l "$1" 2>/dev/null | grep "^ii" | awk '{print $3}'
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if user is in a group
user_in_group() {
    groups "$USER" | grep -qw "$1"
}

# Check ROCm installation
check_rocm_installed() {
    if [ -d "/opt/rocm" ] && [ -f "/opt/rocm/bin/rocminfo" ]; then
        return 0
    fi
    return 1
}

# Get ROCm version
get_rocm_version() {
    if [ -f "/opt/rocm/.info/version" ]; then
        cat /opt/rocm/.info/version
    elif [ -f "/opt/rocm/version" ]; then
        cat /opt/rocm/version
    else
        echo "unknown"
    fi
}

# Check AMDGPU-DKMS installation
check_amdgpu_dkms_installed() {
    is_package_installed "amdgpu-dkms"
}

# Check if ComfyUI is installed
check_comfyui_installed() {
    [ -d "${COMFYUI_DIR}" ] && [ -f "${COMFYUI_DIR}/main.py" ]
}

# Check if ComfyUI venv exists and is valid
check_comfyui_venv() {
    [ -d "${VENV_DIR}" ] && [ -f "${VENV_DIR}/bin/activate" ] && [ -f "${VENV_DIR}/bin/pip" ]
}

# Check if PyTorch is installed in venv
check_pytorch_installed() {
    if check_comfyui_venv; then
        "${VENV_DIR}/bin/python" -c "import torch" 2>/dev/null
        return $?
    fi
    return 1
}

# Check PyTorch ROCm version
get_pytorch_rocm_version() {
    if check_comfyui_venv; then
        local PYTORCH_VERSION=$("${VENV_DIR}/bin/python" -c "import torch; print(torch.__version__)" 2>/dev/null || echo "not installed")
        local HIP_VERSION=$("${VENV_DIR}/bin/python" -c "import torch; print(torch.version.hip if hasattr(torch.version, 'hip') else 'N/A')" 2>/dev/null || echo "N/A")
        echo "${PYTORCH_VERSION} (HIP: ${HIP_VERSION})"
    else
        echo "not installed"
    fi
}

# Check if ComfyUI-Manager is installed
check_comfyui_manager_installed() {
    [ -d "${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager" ]
}

#===============================================================================
# System Status Report
#===============================================================================

print_system_status() {
    print_header "System Status Check"
    
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}                     Current Installation Status                   ${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────┤${NC}"
    
    # Prerequisites
    local prereq_status="${GREEN}✓${NC}"
    if ! is_package_installed "git" || ! is_package_installed "python3-venv"; then
        prereq_status="${YELLOW}Partial${NC}"
    fi
    echo -e "${CYAN}│${NC}  Prerequisites              : $prereq_status"
    
    # AMDGPU-DKMS
    if check_amdgpu_dkms_installed; then
        local dkms_ver=$(get_package_version "amdgpu-dkms")
        echo -e "${CYAN}│${NC}  AMDGPU-DKMS                : ${GREEN}✓ Installed${NC} (v${dkms_ver})"
    else
        echo -e "${CYAN}│${NC}  AMDGPU-DKMS                : ${RED}✗ Not Installed${NC}"
    fi
    
    # ROCm
    if check_rocm_installed; then
        local rocm_ver=$(get_rocm_version)
        echo -e "${CYAN}│${NC}  ROCm                       : ${GREEN}✓ Installed${NC} (v${rocm_ver})"
    else
        echo -e "${CYAN}│${NC}  ROCm                       : ${RED}✗ Not Installed${NC}"
    fi
    
    # User Groups
    local groups_ok=true
    if user_in_group "render" && user_in_group "video"; then
        echo -e "${CYAN}│${NC}  User Groups (render/video) : ${GREEN}✓ Configured${NC}"
    else
        echo -e "${CYAN}│${NC}  User Groups (render/video) : ${YELLOW}⚠ Needs Configuration${NC}"
        groups_ok=false
    fi
    
    # ComfyUI
    if check_comfyui_installed; then
        echo -e "${CYAN}│${NC}  ComfyUI                    : ${GREEN}✓ Installed${NC}"
    else
        echo -e "${CYAN}│${NC}  ComfyUI                    : ${RED}✗ Not Installed${NC}"
    fi
    
    # Python venv
    if check_comfyui_venv; then
        echo -e "${CYAN}│${NC}  Python Virtual Environment : ${GREEN}✓ Created${NC}"
    else
        echo -e "${CYAN}│${NC}  Python Virtual Environment : ${RED}✗ Not Created${NC}"
    fi
    
    # PyTorch
    if check_pytorch_installed; then
        local pytorch_ver=$(get_pytorch_rocm_version)
        echo -e "${CYAN}│${NC}  PyTorch ROCm               : ${GREEN}✓ Installed${NC} (${pytorch_ver})"
    else
        echo -e "${CYAN}│${NC}  PyTorch ROCm               : ${RED}✗ Not Installed${NC}"
    fi
    
    # ComfyUI-Manager
    if check_comfyui_manager_installed; then
        echo -e "${CYAN}│${NC}  ComfyUI-Manager            : ${GREEN}✓ Installed${NC}"
    else
        echo -e "${CYAN}│${NC}  ComfyUI-Manager            : ${RED}✗ Not Installed${NC}"
    fi
    
    # Environment Variables
    if grep -q "HSA_OVERRIDE_GFX_VERSION" ~/.bashrc 2>/dev/null; then
        echo -e "${CYAN}│${NC}  ROCm Environment           : ${GREEN}✓ Configured${NC}"
    else
        echo -e "${CYAN}│${NC}  ROCm Environment           : ${YELLOW}⚠ Needs Configuration${NC}"
    fi
    
    # Launch Scripts
    if [ -x "${COMFYUI_DIR}/run_comfyui.sh" ]; then
        echo -e "${CYAN}│${NC}  Launch Scripts             : ${GREEN}✓ Created${NC}"
    else
        echo -e "${CYAN}│${NC}  Launch Scripts             : ${RED}✗ Not Created${NC}"
    fi
    
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

#===============================================================================
# Installation Functions (with checks)
#===============================================================================

install_prerequisites() {
    print_header "Prerequisites"
    
    local packages_to_install=()
    local required_packages=(
        "wget"
        "curl"
        "git"
        "python3"
        "python3-pip"
        "python3-venv"
        "python3-full"
        "python3-setuptools"
        "python3-wheel"
        "build-essential"
        "software-properties-common"
    )
    
    print_check "Checking required packages..."
    
    for pkg in "${required_packages[@]}"; do
        if is_package_installed "$pkg"; then
            print_skip "$pkg already installed"
        else
            packages_to_install+=("$pkg")
            print_info "$pkg needs to be installed"
        fi
    done
    
    # Check kernel headers
    local headers_pkg="linux-headers-$(uname -r)"
    local modules_pkg="linux-modules-extra-$(uname -r)"
    
    if ! is_package_installed "$headers_pkg"; then
        packages_to_install+=("$headers_pkg")
        print_info "$headers_pkg needs to be installed"
    else
        print_skip "$headers_pkg already installed"
    fi
    
    if ! is_package_installed "$modules_pkg"; then
        packages_to_install+=("$modules_pkg")
        print_info "$modules_pkg needs to be installed"
    else
        print_skip "$modules_pkg already installed"
    fi
    
    # Install missing packages
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        print_step "Updating package lists..."
        sudo apt update
        
        print_step "Installing missing packages: ${packages_to_install[*]}"
        sudo apt install -y "${packages_to_install[@]}"
        
        INSTALLED_ITEMS+=("Prerequisites: ${packages_to_install[*]}")
        print_success "Prerequisites installed!"
    else
        SKIPPED_ITEMS+=("Prerequisites (all already installed)")
        print_success "All prerequisites already installed!"
    fi
}

install_or_update_amdgpu_drivers() {
    print_header "AMD GPU Drivers"
    
    # Check if amdgpu-install utility is present
    if command_exists amdgpu-install; then
        local current_version=$(get_package_version "amdgpu-install" | grep -oP '^\d+\.\d+\.\d+' || echo "unknown")
        print_check "amdgpu-install found (version: $current_version)"
        
        if [[ "$current_version" == "$ROCM_VERSION" ]]; then
            print_skip "amdgpu-install is already at version $ROCM_VERSION"
        else
            print_update "Updating amdgpu-install from $current_version to $ROCM_VERSION..."
            cd /tmp
            wget -q --show-progress "${AMDGPU_INSTALL_URL}" -O "${AMDGPU_INSTALL_PKG}"
            sudo apt install -y "./${AMDGPU_INSTALL_PKG}"
            sudo apt update
            UPDATED_ITEMS+=("amdgpu-install: $current_version -> $ROCM_VERSION")
            NEEDS_REBOOT=true
        fi
    else
        print_step "Installing amdgpu-install utility..."
        cd /tmp
        wget -q --show-progress "${AMDGPU_INSTALL_URL}" -O "${AMDGPU_INSTALL_PKG}"
        sudo apt install -y "./${AMDGPU_INSTALL_PKG}"
        sudo apt update
        INSTALLED_ITEMS+=("amdgpu-install $ROCM_VERSION")
    fi
    
    # Check AMDGPU-DKMS
    if check_amdgpu_dkms_installed; then
        local dkms_version=$(get_package_version "amdgpu-dkms")
        print_check "amdgpu-dkms found (version: $dkms_version)"
        
        # Check if update is available
        print_step "Checking for amdgpu-dkms updates..."
        sudo apt update
        local available=$(apt-cache policy amdgpu-dkms | grep Candidate | awk '{print $2}')
        
        if [[ "$dkms_version" != "$available" ]] && [[ -n "$available" ]]; then
            print_update "Updating amdgpu-dkms from $dkms_version to $available..."
            sudo apt install -y amdgpu-dkms
            UPDATED_ITEMS+=("amdgpu-dkms: $dkms_version -> $available")
            NEEDS_REBOOT=true
        else
            print_skip "amdgpu-dkms is up to date"
            SKIPPED_ITEMS+=("amdgpu-dkms (already up to date)")
        fi
    else
        print_step "Installing amdgpu-dkms kernel driver..."
        sudo apt install -y amdgpu-dkms
        INSTALLED_ITEMS+=("amdgpu-dkms")
        NEEDS_REBOOT=true
    fi
    
    print_success "AMD GPU drivers configured!"
}

install_or_update_rocm() {
    print_header "ROCm Software Stack"
    
    # Configure user groups
    print_check "Checking user groups..."
    local groups_changed=false
    
    if ! user_in_group "render"; then
        print_step "Adding user to 'render' group..."
        sudo usermod -a -G render $USER
        groups_changed=true
    else
        print_skip "User already in 'render' group"
    fi
    
    if ! user_in_group "video"; then
        print_step "Adding user to 'video' group..."
        sudo usermod -a -G video $USER
        groups_changed=true
    else
        print_skip "User already in 'video' group"
    fi
    
    if $groups_changed; then
        INSTALLED_ITEMS+=("User groups: render, video")
        NEEDS_REBOOT=true
    fi
    
    # Check ROCm installation
    if check_rocm_installed; then
        local current_rocm=$(get_rocm_version)
        print_check "ROCm found (version: $current_rocm)"
        
        # Check for updates
        print_step "Checking for ROCm updates..."
        sudo apt update
        
        # Try to upgrade rocm metapackage
        local upgrade_output=$(apt list --upgradable 2>/dev/null | grep -i rocm || true)
        if [[ -n "$upgrade_output" ]]; then
            print_update "Updating ROCm packages..."
            sudo apt upgrade -y rocm 2>/dev/null || sudo apt install -y rocm
            local new_rocm=$(get_rocm_version)
            UPDATED_ITEMS+=("ROCm: $current_rocm -> $new_rocm")
            NEEDS_REBOOT=true
        else
            print_skip "ROCm is up to date"
            SKIPPED_ITEMS+=("ROCm (already up to date)")
        fi
    else
        print_step "Installing ROCm packages..."
        sudo apt install -y rocm
        INSTALLED_ITEMS+=("ROCm $ROCM_VERSION")
        NEEDS_REBOOT=true
    fi
    
    # Configure environment
    configure_rocm_environment
    
    print_success "ROCm configured!"
}

configure_rocm_environment() {
    print_check "Checking ROCm environment configuration..."
    
    local env_changed=false
    
    # Check if ROCm environment is already configured
    if ! grep -q "# ROCm Environment" ~/.bashrc 2>/dev/null; then
        print_step "Configuring ROCm environment in ~/.bashrc..."
        
        cat >> ~/.bashrc << 'EOF'

# ROCm Environment (Added by ComfyUI installer)
export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64
export HSA_OVERRIDE_GFX_VERSION=12.0.0
export HIP_VISIBLE_DEVICES=0
# RDNA 4 specific optimizations
export PYTORCH_TUNABLEOP_ENABLED=1
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
EOF
        env_changed=true
        INSTALLED_ITEMS+=("ROCm environment configuration")
    else
        print_skip "ROCm environment already configured in ~/.bashrc"
        
        # Check if RDNA 4 optimizations are present
        if ! grep -q "HSA_OVERRIDE_GFX_VERSION=12.0.0" ~/.bashrc; then
            print_update "Adding RDNA 4 GFX version override..."
            echo 'export HSA_OVERRIDE_GFX_VERSION=12.0.0' >> ~/.bashrc
            env_changed=true
        fi
        
        if ! grep -q "PYTORCH_TUNABLEOP_ENABLED" ~/.bashrc; then
            print_update "Adding RDNA 4 optimizations..."
            echo 'export PYTORCH_TUNABLEOP_ENABLED=1' >> ~/.bashrc
            echo 'export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1' >> ~/.bashrc
            env_changed=true
        fi
        
        if $env_changed; then
            UPDATED_ITEMS+=("ROCm environment configuration")
        else
            SKIPPED_ITEMS+=("ROCm environment (already configured)")
        fi
    fi
    
    # Source the updated environment
    export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64
    export HSA_OVERRIDE_GFX_VERSION=12.0.0
    export HIP_VISIBLE_DEVICES=0
    export PYTORCH_TUNABLEOP_ENABLED=1
    export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
}

install_or_update_comfyui() {
    print_header "ComfyUI"
    
    if check_comfyui_installed; then
        print_check "ComfyUI found at ${COMFYUI_DIR}"
        
        # Update ComfyUI
        print_step "Checking for ComfyUI updates..."
        cd "${COMFYUI_DIR}"
        
        # Fetch latest changes
        git fetch origin 2>/dev/null || true
        
        local LOCAL=$(git rev-parse HEAD 2>/dev/null)
        local REMOTE=$(git rev-parse origin/master 2>/dev/null || git rev-parse origin/main 2>/dev/null)
        
        if [ "$LOCAL" != "$REMOTE" ]; then
            print_update "Updating ComfyUI..."
            git pull origin master 2>/dev/null || git pull origin main 2>/dev/null
            UPDATED_ITEMS+=("ComfyUI")
        else
            print_skip "ComfyUI is up to date"
            SKIPPED_ITEMS+=("ComfyUI (already up to date)")
        fi
    else
        print_step "Cloning ComfyUI repository..."
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
        INSTALLED_ITEMS+=("ComfyUI")
    fi
    
    cd "${COMFYUI_DIR}"
}

setup_python_environment() {
    print_header "Python Environment & PyTorch"
    
    cd "${COMFYUI_DIR}"
    
    # Check/create virtual environment
    if check_comfyui_venv; then
        print_skip "Python virtual environment already exists"
    else
        print_step "Creating Python virtual environment..."
        python3 -m venv "${VENV_DIR}"
        
        if [ ! -f "${VENV_DIR}/bin/pip" ]; then
            print_error "Failed to create virtual environment properly"
            exit 1
        fi
        
        INSTALLED_ITEMS+=("Python virtual environment")
    fi
    
    # Upgrade pip using venv pip directly (avoids PEP 668 externally-managed-environment error)
    print_step "Ensuring pip is up to date..."
    "${VENV_DIR}/bin/pip" install --upgrade pip setuptools wheel --quiet
    
    # Check PyTorch installation
    if check_pytorch_installed; then
        local current_pytorch=$(get_pytorch_rocm_version)
        print_check "PyTorch found: $current_pytorch"
        
        print_step "Checking for PyTorch RDNA 4 updates..."
        # Get the latest version from the nightly index using venv pip
        "${VENV_DIR}/bin/pip" install --upgrade --pre torch torchvision torchaudio \
            --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/ \
            --quiet 2>/dev/null || true
        
        local new_pytorch=$(get_pytorch_rocm_version)
        if [ "$current_pytorch" != "$new_pytorch" ]; then
            UPDATED_ITEMS+=("PyTorch: $current_pytorch -> $new_pytorch")
        else
            SKIPPED_ITEMS+=("PyTorch (already up to date)")
        fi
    else
        print_step "Installing PyTorch with RDNA 4 (RX 9070 XT) support..."
        print_info "Using AMD's nightly builds for gfx120X architecture..."
        "${VENV_DIR}/bin/pip" install --pre torch torchvision torchaudio \
            --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/
        INSTALLED_ITEMS+=("PyTorch RDNA 4 (gfx120X)")
    fi
    
    # Install/update ComfyUI dependencies using venv pip
    print_step "Installing/updating ComfyUI dependencies..."
    "${VENV_DIR}/bin/pip" install -r requirements.txt --quiet
    
    print_success "Python environment configured!"
}

install_or_update_comfyui_manager() {
    print_header "ComfyUI-Manager"
    
    local manager_dir="${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager"
    
    if check_comfyui_manager_installed; then
        print_check "ComfyUI-Manager found"
        
        print_step "Checking for ComfyUI-Manager updates..."
        cd "$manager_dir"
        
        git fetch origin 2>/dev/null || true
        
        local LOCAL=$(git rev-parse HEAD 2>/dev/null)
        local REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
        
        if [ "$LOCAL" != "$REMOTE" ]; then
            print_update "Updating ComfyUI-Manager..."
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
            UPDATED_ITEMS+=("ComfyUI-Manager")
        else
            print_skip "ComfyUI-Manager is up to date"
            SKIPPED_ITEMS+=("ComfyUI-Manager (already up to date)")
        fi
    else
        print_step "Installing ComfyUI-Manager..."
        mkdir -p "${COMFYUI_DIR}/custom_nodes"
        cd "${COMFYUI_DIR}/custom_nodes"
        git clone https://github.com/Comfy-Org/ComfyUI-Manager.git
        INSTALLED_ITEMS+=("ComfyUI-Manager")
    fi
    
    # Install manager requirements if they exist (using venv pip)
    if [ -f "$manager_dir/requirements.txt" ]; then
        "${VENV_DIR}/bin/pip" install -r "$manager_dir/requirements.txt" --quiet 2>/dev/null || true
    fi
    
    cd "${COMFYUI_DIR}"
    print_success "ComfyUI-Manager configured!"
}

create_or_update_launch_scripts() {
    print_header "Launch Scripts"
    
    local scripts_updated=false
    
    # Main launch script
    if [ -f "${COMFYUI_DIR}/run_comfyui.sh" ]; then
        print_check "Launch script exists, updating to ensure latest optimizations..."
    fi
    
    print_step "Creating/updating launch scripts..."
    
    cat > "${COMFYUI_DIR}/run_comfyui.sh" << 'EOF'
#!/bin/bash

# ComfyUI Launch Script for AMD RX 9070 XT (RDNA 4)

# Set ROCm environment
export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64

# RDNA 4 specific environment variables
export HSA_OVERRIDE_GFX_VERSION=12.0.0
export HIP_VISIBLE_DEVICES=0
export PYTORCH_TUNABLEOP_ENABLED=1
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# Navigate to ComfyUI directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Activate virtual environment
source venv/bin/activate

# Run ComfyUI with optimal settings for RDNA 4
echo "Starting ComfyUI with RDNA 4 optimizations..."
echo "Access the web UI at: http://127.0.0.1:8188"
echo ""

python main.py --use-pytorch-cross-attention "$@"
EOF
    chmod +x "${COMFYUI_DIR}/run_comfyui.sh"
    
    # Low VRAM launch script
    cat > "${COMFYUI_DIR}/run_comfyui_lowvram.sh" << 'EOF'
#!/bin/bash

# ComfyUI Launch Script for AMD RX 9070 XT (Low VRAM Mode)

# Set ROCm environment
export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64

# RDNA 4 specific environment variables
export HSA_OVERRIDE_GFX_VERSION=12.0.0
export HIP_VISIBLE_DEVICES=0
export PYTORCH_TUNABLEOP_ENABLED=1
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# Navigate to ComfyUI directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Activate virtual environment
source venv/bin/activate

# Run ComfyUI with low VRAM settings
echo "Starting ComfyUI with Low VRAM mode..."
echo "Access the web UI at: http://127.0.0.1:8188"
echo ""

python main.py --lowvram --use-pytorch-cross-attention "$@"
EOF
    chmod +x "${COMFYUI_DIR}/run_comfyui_lowvram.sh"
    
    # Update script
    cat > "${COMFYUI_DIR}/update_comfyui.sh" << 'UPDATEEOF'
#!/bin/bash

# Update Script for ComfyUI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Updating ComfyUI ==="
git pull origin master 2>/dev/null || git pull origin main 2>/dev/null

echo ""
echo "=== Updating ComfyUI-Manager ==="
cd custom_nodes/ComfyUI-Manager
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
cd "$SCRIPT_DIR"

echo ""
echo "=== Updating Python Dependencies ==="
# Use venv pip directly to avoid PEP 668 externally-managed-environment error
./venv/bin/pip install --upgrade -r requirements.txt
echo ""
echo "=== Updating PyTorch RDNA 4 ==="
./venv/bin/pip install --upgrade --pre torch torchvision torchaudio --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/

echo ""
echo "=== Update Complete! ==="
UPDATEEOF
    chmod +x "${COMFYUI_DIR}/update_comfyui.sh"
    
    # Desktop shortcut
    mkdir -p ~/.local/share/applications
    cat > ~/.local/share/applications/comfyui.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ComfyUI
Comment=AI Image Generation with ComfyUI
Exec=bash -c 'cd ${COMFYUI_DIR} && ./run_comfyui.sh'
Icon=applications-graphics
Terminal=true
Categories=Graphics;
EOF
    
    UPDATED_ITEMS+=("Launch scripts")
    print_success "Launch scripts created/updated!"
}

create_model_directories() {
    print_header "Model Directories"
    
    local dirs_created=false
    local model_dirs=(
        "models/checkpoints"
        "models/vae"
        "models/loras"
        "models/controlnet"
        "models/upscale_models"
        "models/embeddings"
        "models/clip"
        "models/clip_vision"
        "models/diffusion_models"
        "models/text_encoders"
        "input"
        "output"
    )
    
    for dir in "${model_dirs[@]}"; do
        if [ ! -d "${COMFYUI_DIR}/${dir}" ]; then
            mkdir -p "${COMFYUI_DIR}/${dir}"
            dirs_created=true
        fi
    done
    
    if $dirs_created; then
        INSTALLED_ITEMS+=("Model directories")
        print_success "Model directories created!"
    else
        SKIPPED_ITEMS+=("Model directories (already exist)")
        print_skip "All model directories already exist"
    fi
}

#===============================================================================
# Summary Functions
#===============================================================================

print_installation_summary() {
    print_header "Installation Summary"
    
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐${NC}"
    
    if [ ${#INSTALLED_ITEMS[@]} -gt 0 ]; then
        echo -e "${CYAN}│${NC}  ${GREEN}✓ INSTALLED:${NC}"
        for item in "${INSTALLED_ITEMS[@]}"; do
            echo -e "${CYAN}│${NC}    • $item"
        done
    fi
    
    if [ ${#UPDATED_ITEMS[@]} -gt 0 ]; then
        echo -e "${CYAN}│${NC}  ${YELLOW}↑ UPDATED:${NC}"
        for item in "${UPDATED_ITEMS[@]}"; do
            echo -e "${CYAN}│${NC}    • $item"
        done
    fi
    
    if [ ${#SKIPPED_ITEMS[@]} -gt 0 ]; then
        echo -e "${CYAN}│${NC}  ${BLUE}○ SKIPPED (already up to date):${NC}"
        for item in "${SKIPPED_ITEMS[@]}"; do
            echo -e "${CYAN}│${NC}    • $item"
        done
    fi
    
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
}

print_final_instructions() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${CYAN}INSTALLATION/UPDATE COMPLETE!${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if $NEEDS_REBOOT; then
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${RED}IMPORTANT: A REBOOT IS REQUIRED!${NC}                                    ${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  Driver or group changes were made that require a reboot.           ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}To run ComfyUI:${NC}"
    if $NEEDS_REBOOT; then
        echo -e "  1. Reboot your system: ${YELLOW}sudo reboot${NC}"
        echo -e "  2. After reboot, run: ${YELLOW}${COMFYUI_DIR}/run_comfyui.sh${NC}"
    else
        echo -e "  ${YELLOW}${COMFYUI_DIR}/run_comfyui.sh${NC}"
    fi
    echo -e "  Open browser to: ${YELLOW}http://127.0.0.1:8188${NC}"
    echo ""
    echo -e "${CYAN}Other Commands:${NC}"
    echo -e "  • Low VRAM mode: ${COMFYUI_DIR}/run_comfyui_lowvram.sh"
    echo -e "  • Update all:    ${COMFYUI_DIR}/update_comfyui.sh"
    echo ""
    echo -e "${CYAN}Verify ROCm:${NC}"
    echo -e "  • rocminfo"
    echo -e "  • rocm-smi"
    echo ""
    
    if $NEEDS_REBOOT; then
        read -p "Would you like to reboot now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Rebooting system..."
            sudo reboot
        else
            print_info "Remember to reboot before using ComfyUI!"
        fi
    fi
}

#===============================================================================
# Main Script Execution
#===============================================================================

main() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║     ComfyUI Installer for AMD RX 9070 XT (RDNA 4)                   ║"
    echo "║                    Ubuntu 24.04 LTS + ROCm ${ROCM_VERSION}                      ║"
    echo "║                                                                      ║"
    echo "║     ✓ Checks existing installations                                 ║"
    echo "║     ✓ Updates outdated components                                   ║"
    echo "║     ✓ Installs only what's missing                                  ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check system
    check_ubuntu_version
    check_gpu
    
    # Show current status
    print_system_status
    
    echo ""
    read -p "Continue with installation/update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Run installation/update steps
    install_prerequisites
    install_or_update_amdgpu_drivers
    install_or_update_rocm
    install_or_update_comfyui
    setup_python_environment
    install_or_update_comfyui_manager
    create_model_directories
    create_or_update_launch_scripts
    
    # Print summary
    print_installation_summary
    print_final_instructions
}

# Run main function
main "$@"
