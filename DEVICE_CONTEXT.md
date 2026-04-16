# CaraAzul Device Context

Este repositório documenta um TV box Rockchip RK322x com 1 GB de RAM e armazenamento eMMC.

## Estado atual do dispositivo

- CPU: ARM Cortex-A7 quad-core, arquitetura `armv7l`
- Kernel: `4.4.194-rk322x`
- Distribuição: Armbian/Bullseye
  - `/etc/os-release` mostra `Armbian 25.2.3 bullseye`
  - Banner de inicialização indica `Armbian 21.08.8`, possivelmente um rótulo de build antigo
- Memória total: ~962 MB
- Disco eMMC: 7,2 GB total
- Particionamento visível:
  - `mmcblk2` (7,2G)
  - `mmcblk2p1` (7,1G) montado como `/` em `ext4`
  - `mmcblk2boot0` e `mmcblk2boot1` de 4 MB cada (partições de boot Rockchip)
  - `mmcblk2rpmb` de 4 MB

## Layout de boot e sistema de arquivos

- `/boot` está na mesma partição raiz `/`
- Arquivos de boot presentes:
  - `armbianEnv.txt`
  - `boot.cmd`
  - `boot.scr`
  - `vmlinuz-4.4.194-rk322x`
  - `uInitrd-4.4.194-rk322x`
  - `dtb` symlink para `dtb-4.4.194-rk322x`
- Device tree disponível em `/boot/dtb-4.4.194-rk322x`
  - Inclui `rk322x-box.dtb` e outras DTBs Rockchip
- `boot.scr` e `boot.cmd` sugerem uso de U-Boot script de inicialização
- `cmdline` do kernel:
  - `root=UUID=213d2a8b-27c6-447e-8f51-38cdda32f4d3`
  - `console=ttyS2,115200n8`
  - `console=tty1`
  - `rootwait rootfstype=ext4`
  - `ubootpart=70529070-01`
  - `usb-storage.quirks=0x2537:0x1066:u,0x2537:0x1068:u`

## Configuração de logs e zram

- `/var/log` está montado em uma partição zram (`/dev/zram1`)
- `/var/log.hdd` é um ponto de montagem em `ext4` no mesmo `mmcblk2p1`
- `/tmp` e `/run` usam `tmpfs`

## Drivers e subsistema Rockchip

- Módulos importantes carregados:
  - `snd_soc_rk3228`
- Mensagens do kernel mostram suporte a Rockchip:
  - `rockchip-thermal`
  - `dwmmc_rockchip` para controladores MMC
  - `rk_iommu_domain` e `rkvdec`
- Isso indica suporte ao subsistema de MMC e áudio Rockchip no kernel atual

## Observações críticas

- A eMMC está quase cheia: `6,1G` usados de `6,9G` (91% ocupado)
- Há apenas uma partição root ext4 detectada, o que significa que instalar um novo sistema provavelmente precisará reconfigurar/formatar a eMMC
- A infraestrutura de boot atual parece depender de U-Boot e dos arquivos em `/boot`
- O sistema já suporta boot completo em eMMC e não está usando apenas cartão SD

## Versão exata e base do Armbian

O arquivo `/etc/armbian-release` mostra que o build é legacy:
- `VERSION=21.08.8`
- `BRANCH=legacy`
- `BOARD=rk322x-box`
- `BOARD_NAME="rk322x-box"`
- `LINUXFAMILY=rk322x`
- `IMAGE_TYPE=user-built`
- `BOARD_TYPE=tvb`

Isso indica que o boot/kernel vêm de um BSP Armbian 21.08.x antigo, mesmo com a base de usuários sendo Debian Bullseye.

## Atualização e pacotes disponíveis

No sistema atual:
- `armbian-bsp-cli-rk322x-box` instalado: `21.08.8`, candidato: `26.2.1`
- `linux-image-legacy-rk322x` instalado e candidato: `21.08.1`
- `linux-dtb-legacy-rk322x` instalado e candidato: `21.08.1`
- `linux-u-boot-rk322x-box-legacy` instalado e candidato: `21.08.1`

Portanto, embora o repositório Armbian ofereça um BSP CLI mais recente, o kernel/U-Boot para este board permanece no ramo legacy 21.08.x.

Isso torna a migração para Arch Linux ARM uma opção mais segura do que tentar atualizar o stack Armbian em cima do sistema atual.

## Próximos passos recomendados

1. Fazer backup completo da eMMC antes de qualquer troca de sistema.
2. Coletar `boot.cmd` / `boot.scr` e `armbianEnv.txt` para entender exatamente como o U-Boot monta o rootfs.
3. Avaliar se o novo Arch Linux ARM pode ser instalado apenas substituindo o rootfs ou se será preciso regravar a eMMC inteira.
4. Liberar espaço em disco ou usar armazenamento externo antes de gerar imagens grandes no dispositivo.

## Comandos úteis já executados

- `uname -a`
- `cat /etc/os-release`
- `cat /proc/cpuinfo`
- `lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT,FSTYPE,LABEL`
- `mount`
- `df -h`
- `cat /proc/cmdline`
- `ls -l /boot`
- `find / -maxdepth 2 -name 'u-boot*' -o -name 'boot.scr' -o -name 'uEnv.txt'`
- `lsmod | grep -i rk`
- `dmesg | grep -i rockchip | tail -n 40`
