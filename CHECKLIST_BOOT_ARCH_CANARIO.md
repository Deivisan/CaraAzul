# Checklist final — Boot Arch canário no SD (sem tocar eMMC)

## Pré-condições

- [ ] `work/rootfs` preparado com `prepare-arch-minimal`
- [ ] `work/multitool-overlay` gerado com `build-multitool-overlay`
- [ ] Backup atual do SD e eMMC já existe

## O que copiar para o SD (FAT / MULTITOOL)

Copiar para o SD:

- `work/multitool-overlay/archboot/zImage` -> `/archboot/zImage`
- `work/multitool-overlay/archboot/uInitrd` -> `/archboot/uInitrd`
- `work/multitool-overlay/archboot/dtb/rk322x-box.dtb` -> `/archboot/dtb/rk322x-box.dtb`

Atualizar `/extlinux/extlinux.conf` no SD:

- manter entrada `LABEL Multitool`
- adicionar bloco `LABEL ArchLinuxARM-canary`
- referência pronta: `work/multitool-overlay/extlinux/extlinux.conf.merged`

## O que precisa existir no rootfs Arch (partição root)

- `boot/zImage`
- `boot/uInitrd`
- `boot/dtb/rk322x-box.dtb`
- `etc/passwd` com usuário `ufrb`
- `etc/ssh/sshd_config.d/01-carazul.conf`
- `etc/systemd/network/20-wired.network`

## Credenciais previstas

- Usuário: `ufrb`
- Senha: `desk@456.`
- Root: habilitado com mesma senha

## Observabilidade (já pré-configurada)

- Serviço: `carazul-logship.service`
- Timer: `carazul-logship.timer` (2min)
- Configuração: `/etc/caraazul/telemetry.env`

Para ativar envio real:

- Definir `LOG_SHIP_URL=` (webhook HTTP)
ou
- Definir `LOG_SYSLOG_HOST=` (syslog remoto)

## Validação pós-boot (3 minutos)

- [ ] Console serial mostra boot do kernel 6.6.22
- [ ] Login com `ufrb` funciona
- [ ] `uname -r` mostra `6.6.22-current-rockchip`
- [ ] `ip a` mostra rede ativa
- [ ] `systemctl status sshd` ativo
- [ ] `journalctl -u carazul-logship.service -n 50` sem erro crítico

## Rollback imediato

Se falhar:

1. selecionar `LABEL Multitool` no boot menu
2. restaurar `extlinux.conf` original
3. remover diretório `/archboot` do SD
