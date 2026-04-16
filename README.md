# CaraAzul

Repo público para pesquisa e desenvolvimento sobre TV box Rockchip RK322x (ARMv7 32-bit) com 1 GB de RAM.

## Objetivo

Documentar e melhorar o software do dispositivo:
- RK322x / RK3228 family
- Armbian 21.08.8 com kernel 4.4.194-rk322x
- 1 GB RAM, armazenamento em eMMC/MMC
- Uso como dispositivo multimídia, câmera e roteador

## Contexto inicial

O dispositivo é um TV box barato baseado em Rockchip RK322x, arquitetura ARMv7 32-bit.

Problemas atuais:
- `bun` não é compatível porque binário oficial é x86_64
- `node`/`npm` não estão instalados
- Kernel antigo (4.4) e Armbian 21.08.8
- `/var/log` por vezes em zram está cheio

## Pesquisa inicial

- RK322x é uma série Rockchip usada em dispositivos baratos de multimídia e TV box.
- O dispositivo já está rodando Armbian 21.08.8, mas o suporte a Arch Linux ARM para RK322x não é claro.
- Arch Linux ARM lista vários dispositivos ARMv7, mas RK322x/RK3228 não aparecem explicitamente.
- O principal bloqueio para `bun` é arquitetura: o box é `armv7l`, o `bun` oficial baixado era x86_64.

## Próximos passos

- Verificar se roda melhor com Debian/Armbian atualizados ou com outra distro ARMv7 compatível.
- Testar `nodejs`/`npm` via pacote Debian para desenvolvimento local.
- Avaliar se há imagens Arch Linux ARM genéricas ou builds para Rockchip ARMv7.
- Documentar hardware e configuração de boot.

## Contexto do dispositivo conectado

O dispositivo já inicializa em Armbian (atual `Armbian 25.2.3 bullseye`) com kernel `4.4.194-rk322x`.
- CPU: ARMv7 quad-core Cortex-A7
- Memória: 962 MB
- Armazenamento: 7,2 GB eMMC com rootfs único `/dev/mmcblk2p1`
- Boot atual: U-Boot script em `/boot/boot.scr`
- `/boot` está na partição raiz e contém `vmlinuz`, `uInitrd`, DTBs e `armbianEnv.txt`
- Sistema já usa zram para `/var/log`
- Espaço livre atual em eMMC: ~654 MB (91% usado)

A documentação de boot e o layout atual do sistema estão no arquivo `DEVICE_CONTEXT.md`.

## O que é necessário para trocar o sistema totalmente

1. Backup completo da eMMC antes de qualquer alteração.
2. A imagem rootfs do Arch Linux ARM para `armv7l`.
3. Kernel e DTB compatíveis com RK322x, ou um kernel customizado que suporte o hardware.
4. Configuração de boot U-Boot adaptada para `root=/dev/mmcblk0p1` ou para o dispositivo `/dev/mmcblk2p1`.
5. Método de instalação:
   - preferível: regravar a eMMC a partir de um host via modo Rockchip USB (rkdeveloptool + loader)
   - alternativa: montar o novo rootfs em outra partição ou cartão SD e ajustar boot para ele
6. Espaço livre e armazenamento externo para preparar imagens, pois a eMMC atual está quase cheia.

## Versão atual e base do sistema

O sistema atual mostra:
- `Armbian 25.2.3 bullseye` no `/etc/os-release`
- pacotes de suporte do RK322x em versão `21.08.8` (`armbian-bsp-cli-rk322x-box`, `linux-image-legacy-rk322x`, `linux-u-boot-rk322x-box-legacy`)
- kernel `4.4.194-rk322x`, que é antigo e faz parte do ramo legacy Armbian para RK322x.

Isso significa que o dispositivo está rodando uma instalação Armbian baseada em Debian Bullseye, mas com BSP/kernel legado 21.08.x. Para mudar totalmente, o melhor é partir para uma instalação limpa em vez de tentar adaptar o sistema atual.
