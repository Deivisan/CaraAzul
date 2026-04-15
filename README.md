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
