# CaraAzul Image Preparation Spec

## Objetivo

Fornecer um fluxo reproduzível para preparar um rootfs Arch Linux ARM `armv7` e um script U-Boot configurado para o board Rockchip RK322x.

## Escopo

- Baixar a imagem oficial `ArchLinuxARM-armv7-latest.tar.gz`
- Verificar integridade com MD5
- Extrair o rootfs em um workspace local (`work/rootfs`)
- Gerar `boot.cmd` e, se possível, `boot.scr` com os parâmetros de boot corretos
- Documentar o contexto do dispositivo e as dependências necessárias

## Requisitos

- Compatibilidade com chaves de cabeçalho tar desconhecidas (`LIBARCHIVE.xattr.security.SMACK64`)
- Kernel/DTB compatíveis com RK322x devem ser obtidos separadamente
- O script não grava a eMMC nem faz alterações no dispositivo diretamente

## Resultado esperado

- `work/rootfs` contendo o rootfs Arch Linux ARM extraído
- `work/boot/boot.cmd` com `root=/dev/mmcblk0p1`, `console=ttyS2,115200n8` e `rk322x-box.dtb`
- `work/boot/boot.scr` gerado quando `mkimage` está disponível
- Arquivos de documentação `DEVICE_CONTEXT.md`, `README.md`, `AGENTS.md`, `spec.md`
