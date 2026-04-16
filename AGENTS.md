# 🧠 CARAAZUL AGENTS SPEC

Este repositório contém scripts e documentação para migração de um TV box Rockchip RK322x para Arch Linux ARM.

## Objetivo

- Preparar imagem Arch Linux ARM `armv7` para RK322x
- Gerar script de boot U-Boot compatível com RK322x
- Documentar dependências e fluxo de preparação de imagem

## Arquivos principais

- `scripts/prepare-arch-image.sh` - baixa, verifica, extrai e gera `boot.cmd` / `boot.scr`
- `images/ArchLinuxARM-armv7-latest.tar.gz` - tarball rootfs Arch Linux ARM
- `DEVICE_CONTEXT.md` - dados do dispositivo e layout de boot
- `README.md` - contexto do projeto e próximos passos

## Requisitos

- `curl`
- `bsdtar` preferível, `tar` compatível com `--warning=no-unknown-keyword` caso contrário
- `mkimage` (opcional, para gerar `boot.scr`)

## Fluxo de trabalho

1. `bash scripts/prepare-arch-image.sh download`
2. `bash scripts/prepare-arch-image.sh extract`
3. `bash scripts/prepare-arch-image.sh boot /dev/mmcblk0p1`
4. Ajustar kernel/DTB/U-Boot no dispositivo conforme necessário

## Observações

- O tarball contém extended headers com chaves desconhecidas (`LIBARCHIVE.xattr.security.SMACK64`) que exigem extração tolerante.
- O boot no hardware RK322x depende de kernel/DTB compatíveis; o script gera apenas a camada de initramfs rootfs / boot script.
- O workspace já extraiu o rootfs em `work/rootfs` e criou `work/boot/boot.cmd`, mas o kernel/DTB final ainda precisa ser obtido do BSP Armbian/Rockchip ou build customizado.
- A pesquisa web não retornou uma imagem Arch Linux ARM pronta para RK322x; o caminho mais confiável é reaproveitar o BSP/Rockchip existente e testar no hardware.
