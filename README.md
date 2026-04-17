# CaraAzul 🔵

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/7/74/Arch_Linux_logo.svg" alt="Arch Linux Logo" width="110" />
</p>

![Status](https://img.shields.io/badge/status-canary%20em%20teste-orange)
![Platform](https://img.shields.io/badge/platform-RK322x%20(ARMv7)-blue)
![Kernel](https://img.shields.io/badge/kernel-6.6.22--current--rockchip-1f6feb)
![Arch](https://img.shields.io/badge/base-Arch%20Linux%20ARM-1793d1)

> **CaraPreta (governo)** inspirou o nome.  
> **CaraAzul** é a reabilitação comunitária com base em **Arch Linux ARM** (logo azul), focada em hardware legado RK322x.

## 🚀 Visão do projeto

Ressuscitar TV Boxes antigas RK322x e transformar esse hardware em uma plataforma mínima, funcional e reproduzível para:

- Linux moderno (Arch ARM)
- automação e laboratório de sistemas
- execução de agentes em terminal (ex.: arquitetura estilo zeroclaw/hermes/picoclaw, em binário único quando possível)

Se estabilizar em produção real, este repositório vira uma referência pública para recuperação técnica de uma família de dispositivos considerada descartável.

---

## 📌 Estado atual (abril/2026)

- ✅ Pipeline SD-first canário estruturado
- ✅ Rootfs Arch minimal preparado offline
- ✅ Kernel RK322x `6.6.22-current-rockchip` integrado
- ✅ Entrada `ArchLinuxARM-canary` adicionada no Multitool SD
- ✅ SSH + networkd + observabilidade básica no rootfs
- ⚠️ **eMMC flash com imagem genérica resultou em tela preta (investigação ativa)**

> **Fase atual:** testes de boot em hardware real (`carapreta`) com foco em robustez de bootchain.

---

## 🧠 Diagnóstico crítico atual (tela preta após flash)

Mais provável que o erro tenha sido **formato/layout de imagem para eMMC**:

- A imagem `.img` gerada no workspace foi **rootfs-centric** (partição Linux + conteúdo).
- O boot RK322x em eMMC via Multitool costuma depender de uma imagem com layout/offsets de bootloader já válidos (cadeia Rockchip completa no disco).

Resultado típico: gravação “sucesso” no Multitool, mas boot morto (sem vídeo/LED esperado).

👉 Em outras palavras: **não é falha de conceito do Arch**, é falha provável de empacotamento/layout da imagem para o bootchain Rockchip no eMMC.

### Próximo caminho correto

1. Manter estratégia **SD canário** até boot estável.
2. Gerar imagem **multitool-friendly para burn em eMMC**, baseada em imagem RK322x comprovadamente bootável.
3. Só então repetir migração para eMMC.

Detalhes em: `CHECKLIST_BOOT_ARCH_CANARIO.md` e `PLANO_CARAPRETA.md`.

---

## 🏗️ Arquitetura de trabalho

### Fase 1 — Canário por SD (sem tocar eMMC)

- SD com Multitool mantém entrada de recuperação
- Entrada adicional `ArchLinuxARM-canary`
- kernel/initrd/dtb em `/archboot`
- rootfs Arch preparado no workspace

### Fase 2 — Validação funcional

- boot repetível
- rede + ssh
- módulos de kernel carregando corretamente
- coleta de logs de boot

### Fase 3 — Migração para eMMC

- somente após estabilidade comprovada no SD
- com rollback pronto

Roadmap completo: **[`ROADMAP.md`](ROADMAP.md)**

---

## 🛠️ Setup rápido (workspace)

```bash
bash scripts/prepare-arch-image.sh prepare-arch-minimal /dev/mmcblk0p2 ext4
bash scripts/prepare-arch-image.sh build-multitool-overlay work/multitool-overlay /dev/mmcblk0p2
bash scripts/prepare-arch-image.sh validate /dev/mmcblk0p2 ext4
# solução eMMC compatível com Multitool 2022 (base-image method)
bash scripts/build-multitool-image.sh --base /caminho/Armbian_23.02.0-trunk_Rk322x-box_kinetic_edge_6.1.0_minimal.img
```

### Build final pronto para teste (gerado)

Arquivo gerado neste ciclo:

- `images/CaraAzul-rk322x-multitool2022-canary-r1.img`
- SHA256: `9e87ef10a03659cbe14516b56dc55c9abac3b60c68fddd8878322b43f2413437`

Esse é o arquivo que você deve mover para `images/` do SD do Multitool.

### Documentação principal

- `GUIA_MULTITOOL_ARCH_RK322X.md`
- `CHECKLIST_BOOT_ARCH_CANARIO.md`
- `PLANO_CARAPRETA.md`
- `DEVICE_CONTEXT.md`
- `MULTITOOL_2022_COMPAT.md`
- `docs/TROUBLESHOOTING_BLACKSCREEN.md`

---

## 📡 Observabilidade e telemetria

O rootfs canário já inclui:

- `carazul-logship.service`
- `carazul-logship.timer`
- `/etc/caraazul/telemetry.env`

Permite envio de logs para webhook/syslog remoto após subir rede, para lapidação contínua de boot/perf.

---

## 🔐 Segurança / credenciais de laboratório

Este projeto usa credenciais de teste em ambiente de validação controlado.  
**Não reutilize em produção.** Troque credenciais imediatamente no primeiro boot estável.

---

## 📦 Artefatos grandes e limites do GitHub

Imagens `.img` grandes **não são versionadas** no GitHub.

- política: `images/README.md`
- este repo versiona scripts + docs + fluxo reproduzível

---

## 🌍 Impacto esperado

Se a trilha fechar com boot estável + migração eMMC reproduzível, o CaraAzul estabelece um caminho público e prático para:

- reuso de TV Boxes antigas
- laboratório Linux de baixo custo
- base mínima para agentes locais em terminal

Essa é a proposta: **transformar sucata eletrônica em infraestrutura funcional de IA e sistemas**.

## 🧪 Status dos testes de campo

- O último teste gravado em eMMC exibiu **tela preta**.
- Esse comportamento já foi incorporado ao plano técnico para correção do formato de imagem.
- Próximo ciclo: retestar com `CaraAzul-rk322x-multitool2022-canary-r1.img`.

## ▶️ Qual opção escolher no menu do Multitool

Para **testar boot em eMMC com a imagem nova**:

1. Inserir SD Multitool com o arquivo `.img` em `/images`
2. No menu do Multitool, escolher **`Burn image to flash`**
3. Selecionar `CaraAzul-rk322x-multitool2022-canary-r1.img`
4. Aguardar término e reiniciar sem interromper alimentação

Se quiser apenas testar sem mexer no eMMC, manter o fluxo pelo item `ArchLinuxARM-canary` no extlinux do SD.

---

## 🏷️ Tópicos sugeridos para o GitHub (Settings → Topics)

`archlinux` `archlinuxarm` `rk322x` `rockchip` `tv-box` `armv7` `embedded-linux` `u-boot` `multitool` `armbian` `legacy-hardware` `self-hosted-ai` `edge-computing`
