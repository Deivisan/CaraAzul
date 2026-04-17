# ROADMAP — CaraAzul (RK322x + Arch Linux ARM)

## Norte do projeto

Entregar uma trilha pública, reprodutível e estável para transformar TV Box RK322x em:

1. Arch Linux ARM funcional
2. Base mínima de infraestrutura para agentes em terminal
3. Migração segura para eMMC com rollback

---

## Wave 0 — Base pronta (concluído)

- [x] rootfs Arch ARM minimal preparado
- [x] kernel 6.6.22 integrado no rootfs
- [x] overlay de boot para Multitool (entrada canário)
- [x] docs operacionais e checklist

## Wave 1 — Boot canário no SD (em andamento)

**Objetivo:** provar boot estável sem tocar eMMC.

- [ ] boot completo no item `ArchLinuxARM-canary`
- [ ] rede ativa + ssh funcional
- [ ] 10 ciclos reboot sem intervenção
- [ ] coletar logs de boot e travas

Critério de saída:
- SD canário estável por 24h de uso intermitente

## Wave 2 — Compatibilidade Multitool 2022 (crítico)

**Objetivo:** gerar `.img` instalável no eMMC sem tela preta.

Estratégia:
- usar método **base-image patch**:
  - partir de uma imagem RK322x comprovada (Armbian/multitool-friendly)
  - substituir rootfs/boot payload mantendo layout/offsets bootloader do disco

Itens:
- [ ] script `build-multitool-image.sh`
- [ ] validação com `fdisk`, `file`, assinatura de partições
- [ ] dry-run e hash final

Critério de saída:
- imagem aparece e é gravável no Multitool sem quebrar bootchain

## Wave 3 — Instalação em eMMC (depois da Wave 2)

- [ ] backup eMMC confirmado
- [ ] burn da imagem compatível
- [ ] primeiro boot eMMC com console/ssh
- [ ] rollback testado

Critério de saída:
- eMMC operacional + fallback disponível

## Wave 4 — Infra mínima para agentes (zeroclaw-like)

**Objetivo:** runtime mínimo para agente terminal binário único.

- [ ] toolchain Rust/Zig validada em ARMv7
- [ ] pacote utilitário base (tmux, curl, jq, git, openssh)
- [ ] serviço supervisor leve de agente
- [ ] benchmark de memória/CPU em 1GB RAM

Critério de saída:
- agente CLI simples estável em loop + telemetria

## Wave 5 — Publicação e comunidade

- [ ] guia público de instalação (SD/eMMC)
- [ ] matriz de compatibilidade por board RK322x
- [ ] playbook de troubleshooting (black screen/no HDMI/no network)
- [ ] release pública com changelog técnico

---

## Riscos principais

1. variação de hardware entre boxes RK322x
2. cadeia de boot sensível a offsets/loader
3. recursos limitados (1GB RAM + eMMC antiga)

## Mitigações

1. SD-first obrigatório
2. imagem eMMC somente por layout compatível
3. observabilidade ativa no primeiro boot
