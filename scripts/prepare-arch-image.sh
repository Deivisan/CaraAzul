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
KERNEL_BUNDLE_DEFAULT="${REPO_ROOT}/kernels/rk322x-kernel-6.6.22.tar.gz"
KERNEL_VERSION_DEFAULT="6.6.22-current-rockchip"

function ensure_rootfs_ready() {
  if [[ ! -d "${ROOTFS_DIR}" || ! -f "${ROOTFS_DIR}/etc/os-release" ]]; then
    echo "ERROR: rootfs ${ROOTFS_DIR} não encontrado/incompleto. Execute: extract" >&2
    exit 1
  fi
}

function ensure_line_in_file() {
  local line="$1"
  local file="$2"
  touch "${file}"
  if ! grep -Fqx "${line}" "${file}"; then
    printf '%s\n' "${line}" >> "${file}"
  fi
}

function set_or_append_kv() {
  local key="$1"
  local value="$2"
  local file="$3"
  touch "${file}"
  if grep -qE "^${key}[[:space:]]+" "${file}"; then
    sed -i -E "s|^${key}[[:space:]]+.*|${key} ${value}|" "${file}"
  elif grep -qE "^${key}=" "${file}"; then
    sed -i -E "s|^${key}=.*|${key}=${value}|" "${file}"
  else
    printf '%s %s\n' "${key}" "${value}" >> "${file}"
  fi
}

function sha512_hash_password() {
  local password="$1"
  ensure_command openssl
  local salt
  salt="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)"
  openssl passwd -6 -salt "${salt}" "${password}"
}

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

if test -e \${devtype} \${devnum} /boot/vmlinuz; then
  load \${devtype} \${devnum} \${kernel_addr_r} /boot/vmlinuz
  load \${devtype} \${devnum} \${ramdisk_addr_r} /boot/uInitrd
  load \${devtype} \${devnum} \${fdt_addr_r} /boot/dtb/rk322x-box.dtb
else
  load \${devtype} \${devnum} \${kernel_addr_r} /vmlinuz
  load \${devtype} \${devnum} \${ramdisk_addr_r} /uInitrd
  load \${devtype} \${devnum} \${fdt_addr_r} /dtb/rk322x-box.dtb
fi
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

function make_extlinux_conf() {
  local rootdev="$1"
  local rootfstype="$2"
  local console="${3:-ttyS2,115200n8}"
  local boot_dir="$4"

  mkdir -p "${boot_dir}/extlinux"
  cat > "${boot_dir}/extlinux/extlinux.conf" <<EOF
LABEL ArchLinuxARM-RK322x
  LINUX /zImage
  INITRD /uInitrd
  FDT /dtb/rk322x-box.dtb
  APPEND root=${rootdev} rootwait rootfstype=${rootfstype} console=${console} console=tty1 loglevel=1 consoleblank=0
EOF
}

function install_kernel_bundle() {
  local bundle="${1:-${KERNEL_BUNDLE_DEFAULT}}"
  local kver="${2:-${KERNEL_VERSION_DEFAULT}}"

  ensure_rootfs_ready
  ensure_command tar

  if [[ ! -f "${bundle}" ]]; then
    echo "ERROR: kernel bundle não encontrado: ${bundle}" >&2
    exit 1
  fi

  local tmp
  tmp="$(mktemp -d)"
  tar -xzf "${bundle}" -C "${tmp}"

  if [[ ! -f "${tmp}/extracted/vmlinuz-${kver}" ]]; then
    echo "ERROR: vmlinuz do kernel esperado não encontrado no bundle (${kver})" >&2
    rm -rf "${tmp}"
    exit 1
  fi

  mkdir -p "${ROOTFS_DIR}/boot/dtb" "${ROOTFS_DIR}/lib/modules/${kver}"

  cp -f "${tmp}/extracted/vmlinuz-${kver}" "${ROOTFS_DIR}/boot/vmlinuz"
  cp -f "${tmp}/extracted/vmlinuz-${kver}" "${ROOTFS_DIR}/boot/zImage"
  cp -f "${tmp}/extracted/uInitrd-${kver}" "${ROOTFS_DIR}/boot/uInitrd"
  cp -f "${tmp}/extracted/initrd.img-${kver}" "${ROOTFS_DIR}/boot/initrd.img-${kver}"
  cp -f "${tmp}/extracted/System.map-${kver}" "${ROOTFS_DIR}/boot/System.map-${kver}"
  cp -f "${tmp}/extracted/config-${kver}" "${ROOTFS_DIR}/boot/config-${kver}"

  if [[ -d "${tmp}/extracted/dtb" ]]; then
    cp -a "${tmp}/extracted/dtb/." "${ROOTFS_DIR}/boot/dtb/"
  fi
  if [[ ! -f "${ROOTFS_DIR}/boot/dtb/rk322x-box.dtb" ]]; then
    echo "WARNING: rk322x-box.dtb não encontrado após cópia de DTBs" >&2
  fi

  # Instala módulos no layout esperado por depmod/modprobe
  if [[ -d "${tmp}/extracted/modules" ]]; then
    cp -a "${tmp}/extracted/modules/." "${ROOTFS_DIR}/lib/modules/${kver}/"
  fi

  # Garante metadados mínimos de módulos
  if command -v depmod >/dev/null 2>&1; then
    depmod -b "${ROOTFS_DIR}" "${kver}" || true
  fi

  rm -rf "${tmp}"
  echo "Kernel bundle instalado em ${ROOTFS_DIR} (versão ${kver})"
}

function configure_arch_minimal() {
  local username="${1:-ufrb}"
  local password="${2:-desk@456.}"
  local hostname="${3:-carapreta-arch}"

  ensure_rootfs_ready

  local root_hash
  root_hash="$(sha512_hash_password "${password}")"
  local user_hash
  user_hash="$(sha512_hash_password "${password}")"

  # Hostname e hosts
  printf '%s\n' "${hostname}" > "${ROOTFS_DIR}/etc/hostname"
  cat > "${ROOTFS_DIR}/etc/hosts" <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${hostname}.localdomain ${hostname}
EOF

  # Locale/timezone mínimo
  ensure_line_in_file "en_US.UTF-8 UTF-8" "${ROOTFS_DIR}/etc/locale.gen"
  printf 'LANG=en_US.UTF-8\n' > "${ROOTFS_DIR}/etc/locale.conf"
  ln -sf /usr/share/zoneinfo/America/Bahia "${ROOTFS_DIR}/etc/localtime" || true

  # Root password
  if grep -q '^root:' "${ROOTFS_DIR}/etc/shadow"; then
    sed -i -E "s|^root:[^:]*:|root:${root_hash}:|" "${ROOTFS_DIR}/etc/shadow"
  fi

  # Usuário padrão
  if ! grep -q "^${username}:" "${ROOTFS_DIR}/etc/passwd"; then
    echo "${username}:x:1000:1000:${username}:/home/${username}:/bin/bash" >> "${ROOTFS_DIR}/etc/passwd"
  fi
  if ! grep -q "^${username}:" "${ROOTFS_DIR}/etc/shadow"; then
    echo "${username}:${user_hash}:19000:0:99999:7:::" >> "${ROOTFS_DIR}/etc/shadow"
  else
    sed -i -E "s|^${username}:[^:]*:|${username}:${user_hash}:|" "${ROOTFS_DIR}/etc/shadow"
  fi
  if ! grep -q "^${username}:" "${ROOTFS_DIR}/etc/group"; then
    echo "${username}:x:1000:" >> "${ROOTFS_DIR}/etc/group"
  fi
  if grep -q '^wheel:' "${ROOTFS_DIR}/etc/group"; then
    if ! grep -qE "^wheel:[^:]*:[^:]*:.*\b${username}\b" "${ROOTFS_DIR}/etc/group"; then
      sed -i -E "s|^wheel:x:([0-9]+):(.*)$|wheel:x:\1:\2,${username}|" "${ROOTFS_DIR}/etc/group"
      sed -i -E 's|:,+|:|; s|,,+|,|g; s|:,$|:|' "${ROOTFS_DIR}/etc/group"
    fi
  else
    echo "wheel:x:10:${username}" >> "${ROOTFS_DIR}/etc/group"
  fi

  mkdir -p "${ROOTFS_DIR}/home/${username}"

  # sudo para wheel
  if [[ -f "${ROOTFS_DIR}/etc/sudoers" ]]; then
    sed -i 's|^# \(%wheel ALL=(ALL:ALL) ALL\)|\1|' "${ROOTFS_DIR}/etc/sudoers" || true
    sed -i 's|^# \(%wheel ALL=(ALL) ALL\)|\1|' "${ROOTFS_DIR}/etc/sudoers" || true
  fi

  # SSH habilitado e root login por senha (pedido explícito)
  mkdir -p "${ROOTFS_DIR}/etc/ssh/sshd_config.d"
  cat > "${ROOTFS_DIR}/etc/ssh/sshd_config.d/01-carazul.conf" <<EOF
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
EOF

  # Networkd DHCP padrão
  mkdir -p "${ROOTFS_DIR}/etc/systemd/network"
  cat > "${ROOTFS_DIR}/etc/systemd/network/20-wired.network" <<EOF
[Match]
Name=e*

[Network]
DHCP=yes
EOF

  # Keyring bootstrap no primeiro boot
  mkdir -p "${ROOTFS_DIR}/usr/local/sbin"
  cat > "${ROOTFS_DIR}/usr/local/sbin/carazul-firstboot.sh" <<'EOF'
#!/usr/bin/env bash
set -e
if command -v pacman-key >/dev/null 2>&1; then
  pacman-key --init || true
  pacman-key --populate archlinuxarm || true
fi
systemctl disable carazul-firstboot.service || true
rm -f /etc/systemd/system/carazul-firstboot.service
EOF
  chmod +x "${ROOTFS_DIR}/usr/local/sbin/carazul-firstboot.sh"

  cat > "${ROOTFS_DIR}/etc/systemd/system/carazul-firstboot.service" <<EOF
[Unit]
Description=CaraAzul first boot bootstrap
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/carazul-firstboot.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

  mkdir -p "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
  ln -sf /etc/systemd/system/carazul-firstboot.service \
    "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/carazul-firstboot.service"

  # Habilitar serviços essenciais via symlink
  mkdir -p "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
  mkdir -p "${ROOTFS_DIR}/etc/systemd/system/getty.target.wants"
  ln -sf /usr/lib/systemd/system/sshd.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/sshd.service" || true
  ln -sf /usr/lib/systemd/system/systemd-networkd.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" || true
  ln -sf /usr/lib/systemd/system/systemd-resolved.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/systemd-resolved.service" || true
  ln -sf /usr/lib/systemd/system/systemd-timesyncd.service "${ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service" || true
  ln -sf /usr/lib/systemd/system/getty@.service "${ROOTFS_DIR}/etc/systemd/system/getty.target.wants/getty@tty1.service" || true

  ln -sf /run/systemd/resolve/stub-resolv.conf "${ROOTFS_DIR}/etc/resolv.conf" || true

  echo "Configuração minimal aplicada: user=${username}, hostname=${hostname}, SSH + networkd habilitados"
}

function validate_rootfs_layout() {
  local rootdev="${1:-/dev/mmcblk0p2}"
  local rootfstype="${2:-ext4}"
  ensure_rootfs_ready

  local failed=0
  local required=(
    "${ROOTFS_DIR}/boot/zImage"
    "${ROOTFS_DIR}/boot/uInitrd"
    "${ROOTFS_DIR}/boot/dtb/rk322x-box.dtb"
    "${ROOTFS_DIR}/boot/boot.cmd"
    "${ROOTFS_DIR}/etc/passwd"
    "${ROOTFS_DIR}/etc/shadow"
    "${ROOTFS_DIR}/etc/systemd/network/20-wired.network"
  )

  for f in "${required[@]}"; do
    if [[ ! -e "${f}" ]]; then
      echo "ERRO validação: ausente ${f}" >&2
      failed=1
    fi
  done

  if [[ ! -f "${ROOTFS_DIR}/boot/boot.scr" ]]; then
    echo "AVISO validação: boot.scr ausente (extlinux.conf presente pode ser suficiente)" >&2
  fi

  if ! grep -q "^ufrb:" "${ROOTFS_DIR}/etc/passwd"; then
    echo "ERRO validação: usuário ufrb não encontrado" >&2
    failed=1
  fi
  if ! grep -q "^root:" "${ROOTFS_DIR}/etc/shadow"; then
    echo "ERRO validação: root shadow ausente" >&2
    failed=1
  fi
  if ! grep -q "root=${rootdev}" "${ROOTFS_DIR}/boot/boot.cmd"; then
    echo "ERRO validação: boot.cmd sem rootdev esperado (${rootdev})" >&2
    failed=1
  fi
  if [[ -f "${ROOTFS_DIR}/boot/extlinux/extlinux.conf" ]] && ! grep -q "root=${rootdev}" "${ROOTFS_DIR}/boot/extlinux/extlinux.conf"; then
    echo "ERRO validação: extlinux.conf sem rootdev esperado (${rootdev})" >&2
    failed=1
  fi

  if [[ ${failed} -ne 0 ]]; then
    echo "Validação falhou." >&2
    exit 1
  fi
  echo "Validação OK: layout pronto para SD boot (root=${rootdev}, fs=${rootfstype})"
}

function prepare_arch_minimal() {
  local rootdev="${1:-/dev/mmcblk0p2}"
  local rootfstype="${2:-ext4}"
  local kernel_bundle="${3:-${KERNEL_BUNDLE_DEFAULT}}"
  local kernel_version="${4:-${KERNEL_VERSION_DEFAULT}}"

  extract
  install_kernel_bundle "${kernel_bundle}" "${kernel_version}"
  make_boot_cmd "${rootdev}" "${rootfstype}" "both" "1"
  cp -f "${BOOT_DIR}/boot.cmd" "${ROOTFS_DIR}/boot/boot.cmd"
  if [[ -f "${BOOT_DIR}/boot.scr" ]]; then
    cp -f "${BOOT_DIR}/boot.scr" "${ROOTFS_DIR}/boot/boot.scr"
  elif command -v mkimage >/dev/null 2>&1; then
    mkimage -C none -A arm -T script -d "${ROOTFS_DIR}/boot/boot.cmd" "${ROOTFS_DIR}/boot/boot.scr"
  fi

  make_extlinux_conf "${rootdev}" "${rootfstype}" "ttyS2,115200n8" "${ROOTFS_DIR}/boot"
  configure_arch_minimal "ufrb" "desk@456." "carapreta-arch"
  validate_rootfs_layout "${rootdev}" "${rootfstype}"
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
  local rootdev="${3:-/dev/mmcblk0p2}"

  require_mounted_dir "${root_mount}"
  require_mounted_dir "${boot_mount}"

  if [[ ! -d "${ROOTFS_DIR}" ]]; then
    echo "ERROR: extracted rootfs ${ROOTFS_DIR} does not exist. Run extract first." >&2
    exit 1
  fi

  local source_rootdev
  source_rootdev=$(get_mount_source "${root_mount}") || true

  # Não sobrescreve kernel preparado no rootfs. Apenas garante boot.cmd/extlinux coerentes.
  make_boot_cmd "${rootdev}"
  cp -f "${BOOT_DIR}/boot.cmd" "${ROOTFS_DIR}/boot/boot.cmd"
  if [[ -f "${BOOT_DIR}/boot.scr" ]]; then
    cp -f "${BOOT_DIR}/boot.scr" "${ROOTFS_DIR}/boot/boot.scr"
  fi
  make_extlinux_conf "${rootdev}" "ext4" "ttyS2,115200n8" "${ROOTFS_DIR}/boot"

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
  if [[ -d "${ROOTFS_DIR}/boot/extlinux" ]]; then
    mkdir -p "${boot_target}/extlinux"
    cp -a "${ROOTFS_DIR}/boot/extlinux/." "${boot_target}/extlinux/"
  fi

  if [[ ! -f "${boot_target}/boot.cmd" && ! -f "${boot_target}/boot.scr" && ! -f "${boot_target}/extlinux/extlinux.conf" ]]; then
    echo "WARNING: nenhum boot.cmd/boot.scr/extlinux.conf em ${boot_target}. Verifique boot manualmente." >&2
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

  echo "SD card installation prepared. Use ${rootdev} as root device in boot scripts for this card."
}

function usage() {
  cat <<EOF
Usage: $0 <command>
Commands:
  download              Download ArchLinuxARM-armv7-latest.tar.gz and checksums
  extract               Extract the downloaded rootfs into work/rootfs
  boot [rootdev]        Create a boot.cmd (and boot.scr if mkimage available)
  install-device-boot   Copy RK322x boot files from work/device-boot into work/rootfs/boot
  install-kernel-bundle [bundle] [kver]
                        Install kernel+dtb+modules bundle into work/rootfs
                        defaults: kernels/rk322x-kernel-6.6.22.tar.gz and 6.6.22-current-rockchip
  configure-minimal [user] [password] [hostname]
                        Apply minimal Arch config (SSH, networkd, user, root password)
  prepare-arch-minimal [rootdev] [rootfstype] [bundle] [kver]
                        Full prep in work/rootfs for SD boot (extract + kernel bundle + boot + config + validate)
                        defaults: rootdev=/dev/mmcblk0p2 rootfstype=ext4
  validate [rootdev] [rootfstype]
                        Validate prepared layout in work/rootfs
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
  install-kernel-bundle)
    install_kernel_bundle "${2:-${KERNEL_BUNDLE_DEFAULT}}" "${3:-${KERNEL_VERSION_DEFAULT}}"
    ;;
  configure-minimal)
    configure_arch_minimal "${2:-ufrb}" "${3:-desk@456.}" "${4:-carapreta-arch}"
    ;;
  prepare-arch-minimal)
    prepare_arch_minimal "${2:-/dev/mmcblk0p2}" "${3:-ext4}" "${4:-${KERNEL_BUNDLE_DEFAULT}}" "${5:-${KERNEL_VERSION_DEFAULT}}"
    ;;
  validate)
    validate_rootfs_layout "${2:-/dev/mmcblk0p2}" "${3:-ext4}"
    ;;
  install-sd)
    install_sd "${2:?}" "${3:-}" "${4:-/dev/mmcblk0p2}"
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
