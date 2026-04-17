# Napkin Runbook

## Curation Rules
- Re-priorizar em toda sessão.
- Manter só notas recorrentes e de alto impacto.
- Máximo 10 itens por categoria.
- Cada item precisa de "Do instead".

## Execution & Validation (Highest Priority)
1. **[2026-04-17] Sempre validar download por tamanho + hash antes de afirmar sucesso**
   Do instead: checar `ls -lh`, `sha256sum` e amostra de conteúdo.
2. **[2026-04-17] Estado remoto precisa vir de comando real no host**
   Do instead: rodar `ssh carapreta "..."` e registrar saída bruta no plano.
3. **[2026-04-17] Planejamento de migração sem escrita no device por padrão**
   Do instead: operar em modo leitura (`lsblk`, `mount`, `boot.cmd`) até aprovação explícita.

## Shell & Command Reliability
1. **[2026-04-17] Evitar pipelines frágeis para caminhos não confirmados**
   Do instead: verificar diretório/arquivo antes com `ls` e só então executar operação.
2. **[2026-04-17] Em SSH remoto, comandos podem faltar (ex.: blkid)**
   Do instead: fallback para `/dev/disk/by-*`, `/proc/partitions`, `lsblk -o`.

## Domain Behavior Guardrails
1. **[2026-04-17] RK322x usa U-Boot script + overlays críticos**
   Do instead: preservar `boot.cmd`, `boot.scr`, `armbianEnv.txt`, overlays e `fdtfile` no desenho final.
2. **[2026-04-17] Root único em eMMC aumenta risco de brick em migração direta**
   Do instead: primeira fase de boot em SD (MULTITOOL) com fallback claro.

## User Directives
1. **[2026-04-17] Foco final: Arch Linux atualizado e stack para agentes (Rust/Zig)**
   Do instead: priorizar arquitetura estável de kernel+boot antes de otimização de linguagem.
