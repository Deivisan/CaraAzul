# Guia técnico — MULTITOOL + Arch Linux ARM no RK322x (planejamento)

> Escopo: **somente entendimento e preparação**. Sem escrita no dispositivo nesta fase.

## 1) Como funciona hoje no seu SD (confirmado)

No cartão SD montado em `/mnt/sd` (label `MULTITOOL`) existe:

- `kernel.img`
- `rk322x-box.dtb`
- `extlinux/extlinux.conf`
- `bsp/` com `uboot.img`, `trustos.img`, `legacy-uboot.img`
- `images/` com imagens Armbian

`extlinux.conf` atual:

```conf
LABEL Multitool
  LINUX /kernel.img
  FDT /rk322x-box.dtb
  APPEND boot=UUID=FC0F-3936 root=PARTUUID=270918b3-02 rootwait console=ttyS2,115200 verbose=1 consoleblank=0
```

Interpretação:
- O SD é um “starter env” de manutenção/multitool.
- O kernel e DTB usados pelo SD estão na FAT (`p1`).
- O root do multitool está em `PARTUUID=270918b3-02` (`mmcblk0p2`, squashfs).

## 2) Como o boot atual da eMMC funciona

No sistema em produção (eMMC):
- Root em `mmcblk2p1`
- `/boot` dentro da própria root
- U-Boot carrega `boot.scr` -> lê `armbianEnv.txt` -> carrega `zImage`, `uInitrd` e DTB
- `armbianEnv.txt` define `fdtfile=rk322x-box.dtb` e overlay `led-conf-default`

Conclusão prática:
- Você **não precisa instalar no eMMC agora**.
- Dá para preparar boot funcional de Arch no SD e só depois migrar com segurança.

## 3) “Eu boto Arch ou instalo?” — decisão correta

Para seu cenário, a ordem ideal é:

1. **Bootar Arch no SD primeiro (canário)**
2. Validar tudo (boot/rede/storage/estabilidade)
3. Só depois clonar/migrar para eMMC

Isso reduz drasticamente risco de brick.

## 4) Estrutura recomendada para SD com Arch (alvo)

### Partições

- `mmcblk0p1` (FAT32): boot
- `mmcblk0p2` (ext4): rootfs Arch

### Conteúdo mínimo de boot

Em `p1`:
- `zImage` (ou `vmlinuz` + link)
- `uInitrd`
- `dtb/rk322x-box.dtb`
- `dtb/overlay/*` necessário
- `armbianEnv.txt`
- `boot.cmd` + `boot.scr`

### Conteúdo rootfs em `p2`

- Arch Linux ARM rootfs completo
- `/lib/modules/<versao-kernel>` compatível com kernel de boot

## 5) Bootargs recomendados para canário

Manter próximo do legado para reduzir surpresa:

- `console=ttyS2,115200n8`
- `console=tty1`
- `rootwait`
- `rootfstype=ext4`
- `root=UUID=<UUID_DO_P2_ARCH>`
- `ubootpart=${partuuid}`

E preservar overlays relevantes (`led-conf-default` no mínimo).

## 6) O que deixar pronto no workspace (antes da escrita no SD)

1. Template de `boot.cmd` parametrizado por UUID do root Arch.
2. `armbianEnv.txt` para SD-canário (fdtfile + overlays).
3. Pasta `boot/dtb/overlay` alinhada ao kernel escolhido.
4. Verificação automática pós-cópia:
   - presença de `zImage`, `uInitrd`, `boot.scr`, DTB
   - presença de módulos no rootfs

## 7) Checklist de validação quando for testar

1. Boot em SD sobe com console serial ativo.
2. `uname -a` bate com kernel esperado.
3. `ls /lib/modules` bate com kernel.
4. Rede sobe (eth/wifi conforme hardware).
5. Reinício a frio e a quente sem intervenção.

## 8) Migração posterior para eMMC (futuro)

Somente após canário estável:
- copiar rootfs Arch validado para eMMC
- atualizar UUID no `armbianEnv.txt`/`boot.cmd`
- manter SD de resgate pronto (rollback)
