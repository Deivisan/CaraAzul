# Pendências para completar a migração Arch Linux ARM RK322x

## O que já está pronto

- Script de preparação do Arch Linux ARM em `scripts/prepare-arch-image.sh`
- Fluxo de download, verificação e extração do rootfs (`work/rootfs`)
- Geração de `work/boot/boot.cmd` com parâmetros de boot do RK322x
- Documentação de projeto: `README.md`, `DEVICE_CONTEXT.md`, `AGENTS.md`, `spec.md`
- `.gitignore` configurado para excluir `work/` e o tarball baixado em `images/`

## O que falta

- Obter e incluir kernel compatível RK322x + `uInitrd` / `vmlinuz` e `dtb` específicos do board
- Instalar `u-boot-tools` para gerar `boot.scr` automaticamente
- Validar o boot script no dispositivo físico / cartão SD
- Definir se o rootfs deve ser colocado em eMMC (`/dev/mmcblk2p1`) ou em cartão SD (`/dev/mmcblk0p1`) no hardware específico
- Ajustar `boot.args` se precisar de `root=UUID=...` em vez de `root=/dev/mmcblk0p1`
- Criar um processo de gravação da imagem no dispositivo físico, incluindo backup da eMMC existente
- Testar e, se necessário, adaptar o kernel Bootargs para o console serial `ttyS2` e DTB `rk322x-box.dtb`

## Dependências técnicas

- `bsdtar` para extrair o tarball Arch Linux ARM com xattrs desconhecidos
- `curl` para baixar arquivos
- `md5sum` para verificação de checksum
- `mkimage` (opcional, mas recomendado) para gerar `boot.scr`
- Acesso ao dispositivo RK322x ou leitor de cartão SD para testes de boot

## Próximos passos recomendados

1. Instalar `u-boot-tools` no host de preparação
2. Obter kernel e DTB do board atual ou de um build compatível RK322x
3. Montar `work/rootfs` e copiar `boot.cmd`/`boot.scr` para o dispositivo de boot
4. Testar boot em modo serial e ajustar os parâmetros de U-Boot conforme necessário
