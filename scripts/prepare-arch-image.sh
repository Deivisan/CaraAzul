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

function require_mounted_dir() {
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    echo "ERROR: mountpoint ${path} does not exist" >&2
    exit 1
  fi
  if command -v mountpoint >/dev/null 2>&1; then
    if ! mountpoint -q "${path}"; then
      echo "ERROR: ${path} is not a mountpoint" >&2
      exit 1
    fi
  else
    if ! findmnt -n "${path}" >/dev/null 2>&1; then
      echo "ERROR: ${path} is not a mountpoint" >&2
      exit 1
    fi
  fi
}

function get_mount_source() {
  local path="$1"
  if command -v findmnt >/dev/null 2>&1; then
    findmnt -n -o SOURCE --target "${path}"
  elif [[ -f /proc/mounts ]]; then
    awk -v target="${path}" '$2 == target {print $1}' /proc/mounts | head -n1
  else
    echo ""
  fi
}

function require_free_space() {
  local path="$1"
  local needed="$2"
  local avail
  if command -v df >/dev/null 2>&1; then
    avail=$(df --output=avail -B1 "${path}" 2>/dev/null | tail -n1)
  fi
  if [[ -z "${avail}" ]]; then
    echo "WARNING: unable to determine free space for ${path}" >&2
    return
  fi
  if (( avail < needed )); then
    echo "ERROR: not enough free space on ${path}. Need ${needed} bytes, available ${avail} bytes" >&2
    exit 1
  fi
}

function download() {
  ensure_command curl
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
  ensure_command curl
  echo "Removing previous rootfs directory ${ROOTFS_DIR}..."
  rm -rf "${ROOTFS_DIR:?}"
  mkdir -p "${ROOTFS_DIR}"
  echo "Extracting rootfs into ${ROOTFS_DIR}..."
  if [[ ! -f "${ARCH_TARBALL}" ]]; then
    echo "ERROR: tarball not found at ${ARCH_TARBALL}. Run download first." >&2
    exit 1
  fi
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
  local rootfstype="${2:-ext4}"
  local console="${3:-both}"
  local verbosity="${4:-1}"
  mkdir -p "${BOOT_DIR}"

  if [[ -z "${rootdev}" ]]; then
    echo "ERROR: rootdev is required" >&2
    exit 1
  fi

  cat > "${BOOT_DIR}/boot.cmd" <<EOF
# Arch Linux ARM RK322x generic boot script
# Adapt rootdev to the SD card/device you intend to boot.
setenv rootdev "${rootdev}"
setenv rootfstype "${rootfstype}"
setenv console "${console}"
setenv verbosity "${verbosity}"
setenv bootlogo "false"
setenv docker_optimizations "off"

setenv bootargs "console=ttyS2,115200n8 console=tty1 root=${rootdev} rootwait rootfstype=${rootfstype} consoleblank=0 loglevel=${verbosity}"

load \${devtype} \${devnum} \${kernel_addr_r} /boot/vmlinuz
load \${devtype} \${devnum} \${ramdisk_addr_r} /boot/uInitrd
load \${devtype} \${devnum} \${fdt_addr_r} /boot/dtb/rk322x-box.dtb
bootz \${kernel_addr_r} \${ramdisk_addr_r} \${fdt_addr_r}
EOF

  if [[ ! -f "${BOOT_DIR}/boot.cmd" ]]; then
    echo "ERROR: failed to write ${BOOT_DIR}/boot.cmd" >&2
    exit 1
  fi

  echo "boot.cmd created at ${BOOT_DIR}/boot.cmd"
  if command -v mkimage >/dev/null 2>&1; then
    echo "Generating boot.scr using mkimage..."
    mkimage -C none -A arm -T script -d "${BOOT_DIR}/boot.cmd" "${BOOT_DIR}/boot.scr"
    echo "boot.scr generated at ${BOOT_DIR}/boot.scr"
  else
    echo "mkimage not found. Install u-boot-tools to generate boot.scr." >&2
  fi
}

function install_device_boot() {
  local src="${1:-${REPO_ROOT}/work/device-boot}"
  if [[ ! -d "${src}" ]]; then
    echo "ERROR: source directory ${src} does not exist" >&2
    exit 1
  fi

  mkdir -p "${ROOTFS_DIR}/boot/dtb"

  if [[ -f "${src}/vmlinuz-4.4.194-rk322x" ]]; then
    cp -v "${src}/vmlinuz-4.4.194-rk322x" "${ROOTFS_DIR}/boot/vmlinuz"
    cp -v "${src}/vmlinuz-4.4.194-rk322x" "${ROOTFS_DIR}/boot/zImage"
  else
    echo "WARNING: kernel file not found in ${src}, expected vmlinuz-4.4.194-rk322x" >&2
  fi
  if [[ -f "${src}/uInitrd-4.4.194-rk322x" ]]; then
    cp -v "${src}/uInitrd-4.4.194-rk322x" "${ROOTFS_DIR}/boot/uInitrd"
  else
    echo "WARNING: initrd file not found in ${src}, expected uInitrd-4.4.194-rk322x" >&2
  fi
  if [[ -f "${src}/rk322x-box.dtb" ]]; then
    cp -v "${src}/rk322x-box.dtb" "${ROOTFS_DIR}/boot/dtb/rk322x-box.dtb"
  else
    echo "WARNING: DTB file not found in ${src}, expected rk322x-box.dtb" >&2
  fi

  if [[ -f "${src}/boot.cmd" ]]; then
    cp -v "${src}/boot.cmd" "${ROOTFS_DIR}/boot/boot.cmd"
  fi
  if [[ -f "${src}/boot.scr" ]]; then
    cp -v "${src}/boot.scr" "${ROOTFS_DIR}/boot/boot.scr"
  fi

  if [[ -f "${src}/armbianEnv.txt" ]]; then
    cp -v "${src}/armbianEnv.txt" "${ROOTFS_DIR}/boot/armbianEnv.txt"
  fi

  echo "Device boot files installed into ${ROOTFS_DIR}/boot"
  if command -v mkimage >/dev/null 2>&1 && [[ -f "${ROOTFS_DIR}/boot/boot.cmd" ]]; then
    echo "Generating boot.scr in ${ROOTFS_DIR}/boot..."
    mkimage -C none -A arm -T script -d "${ROOTFS_DIR}/boot/boot.cmd" "${ROOTFS_DIR}/boot/boot.scr"
    echo "boot.scr generated at ${ROOTFS_DIR}/boot/boot.scr"
  fi
}

function sync_rootfs() {
  local target="$1"
  if [[ ! -d "${target}" ]]; then
    echo "ERROR: target rootfs mountpoint ${target} does not exist" >&2
    exit 1
  fi

  if [[ ! -f "${ROOTFS_DIR}/etc/os-release" ]]; then
    echo "ERROR: extracted rootfs at ${ROOTFS_DIR} looks incomplete" >&2
    exit 1
  fi

  if command -v rsync >/dev/null 2>&1; then
    rsync -aHAX --delete \
      --exclude='/dev/*' \
      --exclude='/proc/*' \
      --exclude='/sys/*' \
      --exclude='/tmp/*' \
      --exclude='/run/*' \
      --exclude='/mnt/*' \
      --exclude='/media/*' \
      --exclude='/lost+found' \
      "${ROOTFS_DIR}/" "${target}/"
  else
    cp -a "${ROOTFS_DIR}/." "${target}/"
  fi

  for dir in dev proc sys tmp run mnt media lost+found; do
    mkdir -p "${target}/${dir}"
  done
}

function install_sd() {
  local root_mount="${1:?root mountpoint required}"
  local boot_mount="${2:-${root_mount}}"
  local rootdev="${3:-/dev/mmcblk0p1}"

  require_mounted_dir "${root_mount}"
  require_mounted_dir "${boot_mount}"

  if [[ ! -d "${ROOTFS_DIR}" ]]; then
    echo "ERROR: extracted rootfs ${ROOTFS_DIR} does not exist. Run extract first." >&2
    exit 1
  fi

  local source_rootdev
  source_rootdev=$(get_mount_source "${root_mount}") || true

  install_device_boot "${REPO_ROOT}/work/device-boot"
  make_boot_cmd "${rootdev}"

  echo "Checking free space on ${root_mount}..."
  require_free_space "${root_mount}" 2000000000

  echo "Syncing Arch rootfs to ${root_mount}..."
  sync_rootfs "${root_mount}"

  local boot_target
  if [[ "${boot_mount}" == "${root_mount}" ]]; then
    boot_target="${boot_mount}/boot"
  else
    boot_target="${boot_mount}"
  fi

  echo "Copying boot files to ${boot_target}..."
  mkdir -p "${boot_target}"
  for f in vmlinuz zImage uInitrd armbianEnv.txt boot.cmd boot.scr; do
    if [[ -f "${ROOTFS_DIR}/boot/${f}" ]]; then
      cp -a "${ROOTFS_DIR}/boot/${f}" "${boot_target}/"
    fi
  done
  if [[ -d "${ROOTFS_DIR}/boot/dtb" ]]; then
    mkdir -p "${boot_target}/dtb"
    cp -a "${ROOTFS_DIR}/boot/dtb/." "${boot_target}/dtb/"
  fi

  if [[ ! -f "${boot_target}/boot.cmd" && ! -f "${boot_target}/boot.scr" ]]; then
    echo "WARNING: no boot.cmd or boot.scr copied to ${boot_target}. Verify boot files manually." >&2
  fi
  if [[ ! -f "${boot_target}/uInitrd" ]]; then
    echo "WARNING: uInitrd missing in ${boot_target}." >&2
  fi
  if [[ ! -f "${boot_target}/vmlinuz" && ! -f "${boot_target}/zImage" ]]; then
    echo "WARNING: kernel binary missing in ${boot_target}." >&2
  fi
  if [[ -n "${source_rootdev}" ]]; then
    echo "Source root mount is backed by ${source_rootdev}."
  fi

  echo "SD card installation prepared. Use ${rootdev} as root device in boot script for this card."
}

function usage() {
  cat <<EOF
Usage: $0 <command>
Commands:
  download              Download ArchLinuxARM-armv7-latest.tar.gz and checksums
  extract               Extract the downloaded rootfs into work/rootfs
  boot [rootdev]        Create a boot.cmd (and boot.scr if mkimage available)
  install-device-boot   Copy RK322x boot files from work/device-boot into work/rootfs/boot
  install-sd ROOT_MOUNT [BOOT_MOUNT] [rootdev]
                        Copy extracted rootfs and boot files onto a mounted SD card
                        ROOT_MOUNT: mounted SD root partition
                        BOOT_MOUNT: mounted SD boot partition (optional)
                        rootdev: device path to root partition on SD
  all [rootdev]         Run download, extract, and boot with optional rootdev
Notes:
  - This script does not format or partition the SD card.
  - Ensure the target SD partitions are mounted and empty enough to receive the rootfs.
  - If mkimage is not installed, only boot.cmd will be written.
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
  install-device-boot)
    install_device_boot "${2:-${REPO_ROOT}/work/device-boot}"
    ;;
  install-sd)
    install_sd "${2:?}" "${3:-}" "${4:-/dev/mmcblk0p1}"
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
