# Troubleshooting — Tela preta após burn no eMMC (RK322x)

## Sintoma observado

- Burn no Multitool aparenta sucesso
- Reinicia e fica tela preta
- Mouse pode acender (energia USB), teclado pode não acender
- LED esperado pode não acender

## Hipótese principal (mais provável)

Imagem gravada sem bootchain/layout que o eMMC espera.

Em RK322x isso geralmente significa: imagem rootfs-only ou layout incompatível com cadeia de bootloader/offsets do dispositivo.

## O que NÃO conclui

- Não conclui que Arch Linux ARM é inviável
- Não conclui que kernel 6.6.22 é inviável

Conclui apenas que a forma de empacotar a imagem para eMMC estava incorreta para esse fluxo.

## Verificações rápidas

1. SD com Multitool ainda sobe?
2. eMMC aparece no Multitool?
3. imagem usada no burn veio do método "base-image patch"?
4. hash da imagem no SD bate com hash local?

## Plano de recuperação

1. manter boot por SD (canário)
2. gerar nova imagem com `scripts/build-multitool-image.sh`
3. repetir burn com imagem compatível Multitool 2022
4. se falhar novamente, comparar layout da imagem final com uma base conhecida funcional

## Boas práticas para o próximo teste

- Sempre registrar:
  - nome da imagem
  - SHA256
  - timestamp do burn
  - resultado de boot (ok/falha)
- Nunca testar eMMC sem SD de recuperação pronto
