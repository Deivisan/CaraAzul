#!/bin/bash
# =============================================================================
# KERNEL BUILD SCRIPT - Build kernel Linux para RK322x (ARMv7)
# =============================================================================
# Suporta build de kernel 6.6 LTS (legado), 6.12, 6.18 e 6.19 (edge)
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Cores
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# Configurações padrão
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"
OUTPUT_DIR="${PROJECT_ROOT}/output"

# Versões de kernel disponíveis
KERNEL_VERSIONS=("6.6.22" "6.12.16" "6.18.18" "6.19.0")
KERNEL_DEFAULT="6.6.22"

# -----------------------------------------------------------------------------
# Parse argumentos
# -----------------------------------------------------------------------------
VERSION="${KERNEL_DEFAULT}"
JOBS=$(nproc)
CLEAN=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN=1
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [opções]"
            echo ""
            echo "Opções:"
            echo "  -v, --version VERSION  Versão do kernel (padrão: $KERNEL_DEFAULT)"
            echo "  -j, --jobs N           Número de jobs paralelo (padrão: $JOBS)"
            echo "  -c, --clean           Limpar build anterior"
            echo "  -h, --help            Mostrar esta ajuda"
            echo ""
            echo "Versões disponíveis:"
            printf "  - %s\\n" "${KERNEL_VERSIONS[@]}"
            exit 0
            ;;
        *)
            log_error "Opção desconhecida: $1"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Verificar dependências
# -----------------------------------------------------------------------------
check_dependencies() {
    log_info "Verificando dependências..."

    local MISSING=()

    for cmd in arm-linux-gnueabihf-gcc make git; do
        if ! command -v $cmd &> /dev/null; then
            MISSING+=($cmd)
        fi
    done

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        log_error "Faltando dependências: ${MISSING[*]}"
        log_info "Execute: ./toolchain/setup-rk322x.sh full"
        exit 1
    fi

    log_success "Todas as dependências estão instaladas"
}

# -----------------------------------------------------------------------------
# Baixar kernel sources
# -----------------------------------------------------------------------------
download_kernel() {
    local KERNEL_VERSION="$1"
    local KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"

    if [[ -d "$KERNEL_DIR" ]] && [[ $CLEAN -eq 0 ]]; then
        log_info "Kernel sources já existem em $KERNEL_DIR"
        return 0
    fi

    log_info "Baixando kernel ${KERNEL_VERSION}..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Tentar clone do kernel mainline estável
    if [[ -d "linux-${KERNEL_VERSION}" ]] && [[ $CLEAN -eq 0 ]]; then
        log_info "Fonte já disponível: linux-${KERNEL_VERSION}"
        return 0
    fi

    rm -rf "linux-${KERNEL_VERSION}"
    git clone --depth=1 --branch="v${KERNEL_VERSION}" https://github.com/torvalds/linux.git "linux-${KERNEL_VERSION}"

    log_success "Kernel sources baixadas"
}

# -----------------------------------------------------------------------------
# Aplicar patches para RK322x
# -----------------------------------------------------------------------------
apply_patches() {
    local KERNEL_VERSION="$1"

    log_info "Aplicando patches para RK322x..."

    # Aplicar patches específicos do RK322x
    # (Aqui entrariam os patches específicos do Armbian)
    # Por enquanto, usamos a config existente

    log_success "Patches aplicados"
}

# -----------------------------------------------------------------------------
# Configurar build
# -----------------------------------------------------------------------------
configure_kernel() {
    local KERNEL_VERSION="$1"
    local KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
    local CONFIG_FILE="multi_v7_defconfig"  # Para ARMv7

    cd "$KERNEL_DIR"

    log_info "Gerando configuração base para ARMv7/Rockchip..."
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- ${CONFIG_FILE}
    yes "" | make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- oldconfig

    # Configurar com menu (opcional)
    # make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig

    log_success "Kernel configurado"
}

# -----------------------------------------------------------------------------
# Compilar kernel
# -----------------------------------------------------------------------------
build_kernel() {
    local KERNEL_VERSION="$1"
    local KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
    local KERNEL="${KERNEL_DIR}/arch/arm/boot/zImage"
    cd "$KERNEL_DIR"

    log_info "Compilando kernel ${KERNEL_VERSION} para RK322x..."
    log_info "Usando $JOBS jobs paralelos..."

    # Compilar kernel zImage
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
        -j${JOBS} \
        zImage

    # Compilar DTBs (device trees)
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
        -j${JOBS} \
        dtbs

    # Compilar módulos
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
        -j${JOBS} \
        modules

    log_success "Kernel compilado: $KERNEL"
}

# -----------------------------------------------------------------------------
# Instalar output
# -----------------------------------------------------------------------------
install_output() {
    local KERNEL_VERSION="$1"
    local KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"

    mkdir -p "${OUTPUT_DIR}/boot"
    mkdir -p "${OUTPUT_DIR}/lib/modules"
    mkdir -p "${OUTPUT_DIR}/lib/dtb"

    # Copiar kernel
    cp "${KERNEL_DIR}/arch/arm/boot/zImage" "${OUTPUT_DIR}/boot/"
    log_info "Kernel copiado para ${OUTPUT_DIR}/boot/"

    mkdir -p "${OUTPUT_DIR}/dtb"
    # Copiar DTBs
    find "${KERNEL_DIR}/arch/arm/boot/dts" -name "rk322*.dtb" -exec cp {} "${OUTPUT_DIR}/dtb/" \;
    find "${KERNEL_DIR}/arch/arm/boot/dts" -name "rk322x-box.dtb" -exec cp {} "${OUTPUT_DIR}/dtb/" \;
    log_info "DTBs copiados para ${OUTPUT_DIR}/dtb/"

    # Copiar módulos
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
        INSTALL_MOD_PATH="${OUTPUT_DIR}" modules_install
    log_info "Módulos copiados para ${OUTPUT_DIR}/lib/modules/"

    # Copiar System.map e config
    cp "${KERNEL_DIR}/System.map" "${OUTPUT_DIR}/boot/"
    cp "${KERNEL_DIR}/.config" "${OUTPUT_DIR}/boot/config-${KERNEL_VERSION}"

    log_success "Output instalado em ${OUTPUT_DIR}/"

    # Listar arquivos
    echo ""
    echo "Arquivos gerados:"
    ls -lah "${OUTPUT_DIR}/boot/"
    ls -lah "${OUTPUT_DIR}/dtb/"

    # SHA256
    echo ""
    echo "Checksums:"
    sha256sum "${OUTPUT_DIR}/boot/zImage"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  KERNEL BUILD - RK322x (ARMv7)"
    echo "=========================================="
    echo ""
    log_info "Versão do kernel: $VERSION"
    log_info "Jobs paralelos: $JOBS"
    echo ""

    # Verificar dependências
    check_dependencies

    # Criar diretórios
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

    # Build
    download_kernel "$VERSION"
    configure_kernel "$VERSION"
    build_kernel "$VERSION"
    install_output "$VERSION"

    echo ""
    echo "=========================================="
    log_success "BUILD CONCLUÍDO!"
    echo "=========================================="
    echo ""
    log_info "Próximos passos:"
    echo "  1. Copie os arquivos para o dispositivo:"
    echo "     - boot/zImage -> /boot/"
    echo "     - dtb/*.dtb   -> /boot/dtb/"
    echo "     - lib/modules/ -> /lib/"
    echo ""
    echo "  2. Configure o boot (boot.scr)"
    echo ""
}

main "$@"
