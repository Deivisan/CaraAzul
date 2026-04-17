# CaraAzul

> **Missão:** ressuscitar TV Box RK322x antiga com **Arch Linux ARM funcional**, pipeline reproduzível e base moderna para desenvolvimento de agentes.

Se os testes de boot em hardware real confirmarem estabilidade, este projeto vira uma referência prática e pública para uma classe de dispositivos considerada obsoleta.

## Estado atual (abril/2026)

- ✅ Boot chain do SD Multitool preparada com entrada `ArchLinuxARM-canary`
- ✅ Rootfs Arch ARM minimal preparado e validado
- ✅ Kernel RK322x `6.6.22-current-rockchip` integrado (zImage + uInitrd + DTB + módulos)
- ✅ Pré-configuração de acesso remoto (SSH + rede + usuário `ufrb`)
- ✅ Stack de observabilidade inicial (timer + shipper para webhook/syslog)
- 🔬 Fase atual: **testes de boot no hardware (carapreta)**

## Objetivo técnico

1. Bootar Arch Linux ARM de forma confiável no RK322x.
2. Consolidar procedimento SD-first (canário) com rollback seguro.
3. Migrar para eMMC somente após estabilidade comprovada.
4. Entregar base pronta para toolchain ARMv7 (Rust/Zig) e workloads de agentes.

## Contexto do hardware alvo

- SoC: Rockchip RK322x (ARMv7 Cortex-A7)
- RAM: ~1 GB
- Armazenamento atual: eMMC (~7.2 GB) + SD Multitool
- Sistema legado de origem: Armbian/Bullseye + kernel 4.4 legacy

Detalhes completos em: `DEVICE_CONTEXT.md`.

## Arquitetura da solução (resumo)

- **Canário por SD (sem tocar eMMC inicialmente)**
- Entrada de boot adicional no `extlinux.conf` do Multitool
- Kernel/dtb/initrd do Arch em `/archboot` no SD
- Rootfs Arch minimal preparado offline no workspace
- Telemetria periódica para facilitar diagnóstico pós-boot

## Como preparar (workspace)

Script principal:

```bash
bash scripts/prepare-arch-image.sh prepare-arch-minimal /dev/mmcblk0p2 ext4
bash scripts/prepare-arch-image.sh build-multitool-overlay work/multitool-overlay /dev/mmcblk0p2
bash scripts/prepare-arch-image.sh validate /dev/mmcblk0p2 ext4
```

Documentos operacionais:

- `GUIA_MULTITOOL_ARCH_RK322X.md`
- `CHECKLIST_BOOT_ARCH_CANARIO.md`
- `PLANO_CARAPRETA.md`

## Credenciais de teste da imagem canário

- Usuário: `ufrb`
- Senha: `desk@456.`
- Root: habilitado (senha definida no preparo)

> **Atenção:** credenciais de laboratório. Trocar imediatamente após validação de boot.

## Artefatos grandes e limites do GitHub

Este repositório **não versiona imagens `.img` grandes** por limite de tamanho no GitHub.

Exemplo de artefato local (não commitado):
- `images/ArchLinuxARM-rk322x-canary-6.6.22-minimal.img` (~3.0G)

O que fica no Git:
- scripts, documentação, checklist, plano, hashes e fluxo reproduzível.

## Resultado esperado da fase de testes

Se os boots canário passarem (rede, shell, reinício, logs), o projeto entra na fase de migração para eMMC.

Isso pode transformar o CaraAzul em uma trilha prática para recuperar e modernizar RK322x com Arch Linux ARM — algo raro e de alto impacto para hardware legado.
