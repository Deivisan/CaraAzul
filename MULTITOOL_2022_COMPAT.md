# Compatibilidade com Multitool 2022 (RK322x)

## Problema identificado

Imagem `.img` gerada apenas com rootfs pode gravar "com sucesso" no Multitool e ainda assim resultar em **tela preta** no eMMC.

## Por quê

No RK322x, o fluxo de boot em eMMC geralmente depende de layout de disco/bootloader esperado pela cadeia Rockchip/U-Boot usada pelo Multitool.

Se a imagem não preserva essa estrutura, o boot pode falhar antes mesmo de inicializar vídeo/LED.

## Estratégia correta para Multitool 2022

### Método recomendado: **Base Image Patch**

1. usar uma imagem RK322x comprovadamente bootável e aceitada no Multitool 2022
2. montar partições dessa imagem base
3. substituir conteúdo de rootfs e payload boot do CaraAzul
4. manter layout de partições e bootchain da base

## Evidências de alinhamento

- Multitool atual observado no SD é da linha 2022
- imagens históricas já aceitas em `/mnt/sd/images` têm formato típico de imagem disco RK

## Implementação no repo

Este repositório passa a adotar geração de imagem eMMC por compatibilidade de layout, não por rootfs cru.

Script alvo:
- `scripts/build-multitool-image.sh`

Exemplo real gerado:
- `images/CaraAzul-rk322x-multitool2022-canary-r1.img`
- SHA256: `9e87ef10a03659cbe14516b56dc55c9abac3b60c68fddd8878322b43f2413437`

## Checklist mínimo antes de burn

- `fdisk -l imagem.img` com partições esperadas
- `file imagem.img` apontando MBR/partição Linux
- hash SHA256 registrado
- validação em SD canário antes de burn final
