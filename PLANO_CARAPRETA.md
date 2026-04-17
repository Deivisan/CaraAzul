# Plano técnico (somente leitura) — carapreta / RK322x

## Estado real coletado do dispositivo (via SSH)

- Host: `carapreta` (`172.17.28.149`)
- SoC/arch: ARMv7 (RK322x)
- OS atual: Armbian Bullseye legacy
- Kernel atual: `4.4.194-rk322x`
- Root atual: `/dev/mmcblk2p1` (UUID `213d2a8b-27c6-447e-8f51-38cdda32f4d3`)
- Boot atual: `/boot` dentro da mesma partição root (`mmcblk2p1`)
- SD presente:
  - `mmcblk0p1` (vfat, label `MULTITOOL`, montado em `/mnt/sd`)
  - `mmcblk0p2` (squashfs)
- Overlay ativo no `armbianEnv.txt`: `overlays= led-conf-default`
- DTB ativo: `fdtfile=rk322x-box.dtb`
- U-Boot script com trigger maskrom em GPIO D25 (preservar)

## Riscos principais para não “sofrer por erro”

1. **Troca direta na eMMC** pode brickar boot.
2. **Perder overlays/fixups** pode quebrar LED/Wi-Fi/eMMC timings.
3. **Kernel novo sem DTB compatível real** pode não subir.
4. **Root por UUID incorreto** quebra boot silenciosamente.

## Estratégia segura (planejamento)

### Fase 0 — Baseline e backup (sem escrita no boot)
- Capturar cópia de `/boot` completo atual (local repo).
- Salvar `armbianEnv.txt`, `boot.cmd`, `boot.scr`, overlays, DTBs.
- Salvar mapa de partições e UUID/PARTUUID.

### Fase 1 — Primeiro boot em SD (canário)
- Subir Arch ARM no SD primeiro.
- Não tocar eMMC durante validação inicial.
- Boot script apontando root no SD por UUID, com fallback manual.

### Fase 2 — Kernel/DTB e módulos
- Integrar kernel-alvo + módulos + DTB `rk322x-box`.
- Manter overlays essenciais (`led-conf-default`) e fixup script.
- Verificar console (`ttyS2,115200`) e bootargs equivalentes ao legado.

### Fase 3 — Sistema de desenvolvimento
- Base Arch atualizada com ferramentas de compilação.
- Rust target `armv7-unknown-linux-gnueabihf`.
- Zig target `arm-linux-gnueabihf`.
- Testes de binários reais (hello + workload simples de agente).

### Fase 4 — Migração para eMMC (somente após validação)
- Clonar rootfs validado do SD para eMMC.
- Ajustar UUID e `armbianEnv.txt`/`boot.cmd`.
- Manter plano de rollback via SD MULTITOOL.

## O que já está preparado no workspace

- Script de setup de toolchain: `toolchain/setup-rk322x.sh`
- Script de build de kernel (base): `scripts/build-kernel-rk322x.sh`
- Artefato kernel 6.6.22 extraído: `kernels/rk322x-kernel-6.6.22.tar.gz`

## Critérios para considerar “perfeito”

1. Boot estável > 20 reinícios sem intervenção.
2. Rede, storage, áudio e DTB sem regressão crítica.
3. Rust e Zig compilando binários válidos para ARMv7.
4. Processo reprodutível (scripts + documentação + rollback).

## Regra desta fase

Este documento é de **planejamento técnico**. Não executar escrita destrutiva no dispositivo sem etapa explícita de aprovação.
