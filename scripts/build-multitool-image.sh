#!/usr/bin/env bash
set -euo pipefail

# Build de imagem eMMC compatível com Multitool 2022 usando método base-image patch.
# Não grava no dispositivo: apenas gera .img final.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${REPO_ROOT}/work"
ROOTFS_DIR="${WORK_DIR}/rootfs"
OUT_DIR="${REPO_ROOT}/images"

BASE_IMG=""
OUT_IMG="${OUT_DIR}/CaraAzul-rk322x-multitool2022-canary.img"

usage() {
  cat <<EOF
Uso:
  $0 --base /caminho/base-rk322x.img [--out /caminho/saida.img]

Descrição:
  Gera imagem para eMMC preservando layout/bootchain de uma imagem base RK322x
  comprovada para Multitool 2022, substituindo o conteúdo por payload CaraAzul.

Pré-requisitos:
  - rootfs já preparado em work/rootfs
  - imagem base RK322x válida
  - sudo disponível localmente
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_IMG="$2"
      shift 2
      ;;
    --out)
      OUT_IMG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${BASE_IMG}" ]]; then
  echo "ERRO: --base é obrigatório" >&2
  usage
  exit 1
fi

if [[ ! -f "${BASE_IMG}" ]]; then
  echo "ERRO: imagem base não encontrada: ${BASE_IMG}" >&2
  exit 1
fi

if [[ ! -d "${ROOTFS_DIR}" || ! -f "${ROOTFS_DIR}/etc/os-release" ]]; then
  echo "ERRO: rootfs não preparado em ${ROOTFS_DIR}. Rode prepare-arch-image.sh primeiro." >&2
  exit 1
fi

mkdir -p "${OUT_DIR}" "${WORK_DIR}/mnt-base"

echo "[1/7] Copiando imagem base..."
cp -f "${BASE_IMG}" "${OUT_IMG}"

echo "[2/7] Conectando loop device..."
sudo losetup -fP "${OUT_IMG}"
LOOP_DEV="$(sudo losetup -j "${OUT_IMG}" | awk -F: '{print $1}')"

cleanup() {
  set +e
  sudo umount "${WORK_DIR}/mnt-base" 2>/dev/null || true
  sudo losetup -d "${LOOP_DEV}" 2>/dev/null || true
}
trap cleanup EXIT

if [[ -b "${LOOP_DEV}p1" ]]; then
  ROOT_PART="${LOOP_DEV}p1"
elif [[ -b "${LOOP_DEV}p2" ]]; then
  ROOT_PART="${LOOP_DEV}p2"
else
  echo "ERRO: não encontrei partição de root no loop (${LOOP_DEV})" >&2
  exit 1
fi

echo "[3/7] Montando partição root da imagem base: ${ROOT_PART}"
sudo mount "${ROOT_PART}" "${WORK_DIR}/mnt-base"

echo "[4/7] Limpando rootfs da base (preservando lost+found)..."
sudo find "${WORK_DIR}/mnt-base" -mindepth 1 -maxdepth 1 ! -name "lost+found" -exec rm -rf {} +

echo "[5/7] Copiando rootfs CaraAzul para imagem..."
sudo rsync -aHAX --numeric-ids "${ROOTFS_DIR}/" "${WORK_DIR}/mnt-base/"

echo "[6/7] Sincronizando e desmontando..."
sync
sudo umount "${WORK_DIR}/mnt-base"
sudo losetup -d "${LOOP_DEV}"
trap - EXIT

echo "[7/7] Validando imagem final..."
file "${OUT_IMG}"
fdisk -l "${OUT_IMG}" | sed -n '1,80p'
sha256sum "${OUT_IMG}"

echo
echo "Imagem pronta: ${OUT_IMG}"
echo "Use essa imagem no /mnt/sd/images do Multitool 2022 para novo teste de burn em eMMC."
