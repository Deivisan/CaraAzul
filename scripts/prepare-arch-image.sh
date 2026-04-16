#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/images"
WORK_DIR="${REPO_ROOT}/work"
ARCH_URL="https://archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz"
ARCH_MD5_URL="${ARCH_URL}.md5"
ARCH_SIG_URL="${ARCH_URL}.sig"
ARCH_TARBALL="${OUT_DIR}/ArchLinuxARM-armv7-latest.tar.gz"
ARCH_MD5_FILE="${OUT_DIR}/ArchLinuxARM-armv7-latest.tar.gz.md5"
ARCH_SIG_FILE="${OUT_DIR}/ArchLinuxARM-armv7-latest.tar.gz.sig"
ROOTFS_DIR="${WORK_DIR}/rootfs"
BOOT_DIR="${WORK_DIR}/boot"

function ensure_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

function download() {
  mkdir -p "${OUT_DIR}"
  echo "Downloading Arch Linux ARM rootfs to ${OUT_DIR}..."
  curl -L -o "${ARCH_TARBALL}" "${ARCH_URL}"
  curl -L -o "${ARCH_MD5_FILE}" "${ARCH_MD5_URL}"
  curl -L -o "${ARCH_SIG_FILE}" "${ARCH_SIG_URL}"
  echo "Download complete. Verifying checksum..."
  verify_checksum
}

function verify_checksum() {
  ensure_command md5sum
  cd "${OUT_DIR}"
  local expected
  expected="$(cut -d' ' -f1 "${ARCH_MD5_FILE}")"
  local actual
  actual="$(md5sum "${ARCH_TARBALL}" | cut -d' ' -f1)"
  if [[ "${expected}" != "${actual}" ]]; then
    echo "ERROR: MD5 mismatch" >&2
    echo "expected: ${expected}" >&2
    echo "actual:   ${actual}" >&2
    exit 1
  fi
  echo "Checksum verified."
}

function extract() {
  mkdir -p "${ROOTFS_DIR}"
  echo "Cleaning existing rootfs directory ${ROOTFS_DIR}..."
  rm -rf "${ROOTFS_DIR:?}"/* "${ROOTFS_DIR:?}/".[!.]* "${ROOTFS_DIR:?}/"..?* 2>/dev/null || true
  echo "Extracting rootfs into ${ROOTFS_DIR}..."
  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar --no-xattrs --no-same-owner -xzf "${ARCH_TARBALL}" -C "${ROOTFS_DIR}"
  else
    ensure_command tar
    tar --warning=no-unknown-keyword --no-xattrs --no-same-owner --no-same-permissions -xzf "${ARCH_TARBALL}" -C "${ROOTFS_DIR}"
  fi
  echo "Extraction complete."
}

function make_boot_cmd() {
  local rootdev="${1:-/dev/mmcblk0p1}"
  mkdir -p "${BOOT_DIR}"
  cat > "${BOOT_DIR}/boot.cmd" <<EOF
# Arch Linux ARM RK322x generic boot script
# Adapt rootdev to the SD card/device you intend to boot.
setenv rootdev "${rootdev}"
setenv rootfstype "ext4"
setenv console "both"
setenv verbosity "1"
setenv bootlogo "false"
setenv docker_optimizations "off"

setenv bootargs "console=ttyS2,115200n8 console=tty1 root=${rootdev} rootwait rootfstype=${rootfstype} consoleblank=0 loglevel=${verbosity}"

load mmc 0:1 ${kernel_addr_r} /boot/vmlinuz
load mmc 0:1 ${ramdisk_addr_r} /boot/uInitrd
load mmc 0:1 ${fdt_addr_r} /boot/dtb/rk322x-box.dtb
bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
EOF
  echo "boot.cmd created at ${BOOT_DIR}/boot.cmd"
  if command -v mkimage >/dev/null 2>&1; then
    echo "Generating boot.scr using mkimage..."
    mkimage -C none -A arm -T script -d "${BOOT_DIR}/boot.cmd" "${BOOT_DIR}/boot.scr"
    echo "boot.scr generated at ${BOOT_DIR}/boot.scr"
  else
    echo "mkimage not found. Install u-boot-tools to generate boot.scr." >&2
  fi
}

function usage() {
  cat <<EOF
Usage: $0 <command>
Commands:
  download        Download ArchLinuxARM-armv7-latest.tar.gz and checksums
  extract         Extract the downloaded rootfs into work/rootfs
  boot [rootdev] Create a boot.cmd (and boot.scr if mkimage available)
  all [rootdev]   Run download, extract, and boot with optional rootdev
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

case "$1" in
  download)
    download
    ;;
  extract)
    extract
    ;;
  boot)
    make_boot_cmd "${2:-/dev/mmcblk0p1}"
    ;;
  all)
    download
    extract
    make_boot_cmd "${2:-/dev/mmcblk0p1}"
    ;;
  *)
    usage
    ;;
esac
