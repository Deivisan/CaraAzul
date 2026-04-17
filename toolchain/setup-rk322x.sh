#!/bin/bash
# =============================================================================
# TOOLCHAIN SETUP SCRIPT - Cross-compilation para RK322x (ARMv7 32-bit)
# =============================================================================
# Objetivo: Preparar ambiente de build para:
#   - Kernel Linux (6.6+)
#   - Zig (build native e cross-compile)
#   - Rust (cross-compile para ARMv7)
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Cores para output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Detecção de arquitetura host
# -----------------------------------------------------------------------------
ARCH=$(uname -m)
OS=$(uname -s)

log_info "Host architecture: $ARCH-$OS"

# -----------------------------------------------------------------------------
# Instalação de dependências do sistema
# -----------------------------------------------------------------------------
install_system_deps() {
    log_info "Instalando dependências do sistema..."

    # Atualizar repositórios
    sudo apt update

    # Ferramentas de build básicas
    sudo apt install -y \
        build-essential \
        git \
        wget \
        curl \
        rsync \
        bc \
        bison \
        flex \
        libssl-dev \
        libelf-dev \
        python3 \
        python3-pip \
        kmod \
        fakeroot \
        zstd \
        xz-utils \
        zip \
        unzip \
        strace \
        file

    # Cross-compiler ARM (32-bit ARMv7 with NEON)
    sudo apt install -y \
        gcc-arm-linux-gnueabihf \
        g++-arm-linux-gnueabihf \
        binutils-arm-linux-gnueabihf

    # Cross-compiler ARM64 (opcional, para outros dispositivos)
    sudo apt install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu

    # Ferramentas de build de kernel
    sudo apt install -y \
        kmod \
        libncurses-dev \
        libssl-dev

    log_success "Dependências do sistema instaladas"
}

# -----------------------------------------------------------------------------
# Setup ARM交叉编译器 (GCC)
# -----------------------------------------------------------------------------
setup_arm_toolchain() {
    log_info "Verificando cross-toolchain ARM..."

    # Teste se o compilador está disponível
    if command -v arm-linux-gnueabihf-gcc &> /dev/null; then
        local VERSION=$(arm-linux-gnueabihf-gcc --version | head -1)
        log_success "Cross-compiler já instalado: $VERSION"
    else
        log_warn "Cross-compiler não encontrado, tente: sudo apt install gcc-arm-linux-gnueabihf"
    fi

    # Variáveis de ambiente
    export CROSS_COMPILE=arm-linux-gnueabihf-
    export ARCH=arm
    export CC="${CROSS_COMPILE}gcc"
    export LD="${CROSS_COMPILE}ld"
    export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard"
    export LDFLAGS="-march=armv7-a"

    log_success "Variáveis de ambiente configuradas"
}

# -----------------------------------------------------------------------------
# Setup Rust para ARMv7
# -----------------------------------------------------------------------------
setup_rust_armv7() {
    log_info "Configurando Rust para ARMv7..."

    # Verificar se rustup está instalado
    if ! command -v rustup &> /dev/null; then
        log_info "Instalando rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    # Adicionar target ARMv7
    log_info "Adicionando target armv7-unknown-linux-gnueabihf..."
    rustup target add armv7-unknown-linux-gnueabihf

    # Instalar binutils para ARM
    sudo apt install -y binutils-arm-linux-gnueabihf

    # Criar config.toml para cross-compilation
    mkdir -p "$HOME/.cargo"
    if ! grep -q "\[target.armv7-unknown-linux-gnueabihf\]" "$HOME/.cargo/config.toml" 2>/dev/null; then
        cat >> "$HOME/.cargo/config.toml" << 'EOF'
[target.armv7-unknown-linux-gnueabihf]
linker = "arm-linux-gnueabihf-gcc"

[build]
target = "armv7-unknown-linux-gnueabihf"
EOF
    fi

    log_success "Rust configurado para ARMv7"
    log_info "Para compilar: cargo build --target armv7-unknown-linux-gnueabihf"
}

# -----------------------------------------------------------------------------
# Setup Zig para ARM
# -----------------------------------------------------------------------------
setup_zig() {
    log_info "Verificando Zig..."

    # Verificar se Zig está instalado
    if ! command -v zig &> /dev/null; then
        log_info "Instalando Zig..."

        # Baixar a versão estável mais recente
        local ZIG_VERSION="0.15.2"
        local ZIG_DIR="/tmp/zig-linux-x86_64-${ZIG_VERSION}"

        wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" -O /tmp/zig.tar.xz
        tar -xf /tmp/zig.tar.xz -C /tmp/
        sudo mv ${ZIG_DIR} /opt/zig
        sudo ln -sf /opt/zig/zig /usr/local/bin/zig
        rm -f /tmp/zig.tar.xz
    fi

    local VERSION=$(zig version)
    log_success "Zig instalado: $VERSION"

    # Teste cross-compilation para ARM
    log_info "Testando cross-compilation ARM..."
    echo 'const std = @import("std"); pub fn main() void {}' > /tmp/test.zig
    zig build-exe /tmp/test.zig -target arm-linux-gnueabihf --quiet && rm -f /tmp/test.zig /tmp/test

    log_success "Zig configurado para ARMv7"
    log_info "Para compilar: zig build-exe main.zig -target arm-linux-gnueabihf"
}

# -----------------------------------------------------------------------------
# Menu principal
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  TOOLCHAIN SETUP - RK322x (ARMv7)"
    echo "=========================================="
    echo ""

    case "${1:-menu}" in
        full)
            log_info "Instalando ambiente completo..."
            install_system_deps
            setup_arm_toolchain
            setup_rust_armv7
            setup_zig
            ;;
        deps)
            install_system_deps
            ;;
        arm)
            setup_arm_toolchain
            ;;
        rust)
            setup_rust_armv7
            ;;
        zig)
            setup_zig
            ;;
        menu|*)
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos disponíveis:"
            echo "  full   - Instalar ambiente completo (todas as opções)"
            echo "  deps   - Instalar dependências do sistema"
            echo "  arm    - Configurar cross-compiler ARM"
            echo "  rust   - Configurar Rust para ARMv7"
            echo "  zig    - Configurar Zig para ARM"
            echo ""
            ;;
    esac

    echo ""
    echo "=========================================="
    log_success "Setup concluído!"
    echo "=========================================="
}

main "$@"
