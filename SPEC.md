# CaraAzul - RK322x Development Environment

## 🎯 Objetivo

Transformar um TV Box Rockchip RK322x em um sistema de desenvolvimento completo com:
- Arch Linux ARM mais atualizado possível
- Kernel Linux customizado (6.6+)
- Suporte a Zig e Rust para agents IA

## 📋 Hardware

### Dispositivo Alvo
- **SoC**: Rockchip RK3228 / RK3229 (ARM Cortex-A7 quad-core)
- **Arquitetura**: ARMv7 32-bit (armhf) com NEON/VFPv4
- **RAM**: 1-2GB DDR3
- **GPU**: Mali-400 MP4
- **Rede**: Ethernet RTL8201F (10/100)

## 🏗️ Stack de Software

### Sistema Operacional
- **Base**: Arch Linux ARM (armv7)
- **Kernel**: Linux 6.6 LTS (custom build via Armbian)
- **Init**: systemd

### Linguagens de Programação

#### Rust (cross-compile)
```bash
# Instalar
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add armv7-unknown-linux-gnueabihf

# Compilar
cargo build --target armv7-unknown-linux-gnueabihf --release
```

#### Zig (native + cross)
```bash
# Instalar
wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz
sudo tar -xf zig-linux-x86_64-0.14.0.tar.xz -C /opt

# Cross-compile
zig build-exe main.zig -target arm-linux-gnueabihf
```

## 📦 Repositório

### Estrutura
```
CaraAzul/
├── kernels/           # Kernels baixados/compilados
│   └── rk322x-kernel-6.6.22.tar.gz
├── toolchain/        # Scripts de setup
│   └── setup-rk322x.sh
├── scripts/          # Scripts de build
│   └── build-kernel-rk322x.sh
├── work/             # Rootfs extraído
│   └── rootfs/
└── SPEC.md           # Este arquivo
```

## 🔧 Build do Kernel

### Dependências
```bash
sudo apt install gcc-arm-linux-gnueabihf build-essential git bc bison flex libssl-dev libelf-dev python3
```

### Build
```bash
# Baixar sources
git clone --depth=1 --branch=linux-6.6.y https://github.com/armbian/linux-rockchip.git

# Compilar
cd linux-rockchip
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- rockchip_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage dtbs modules -j4

# Instalar módulos
sudo make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=/path/to/rootfs modules_install
```

## 🚀 Próximos Passos

1. **Setup toolchain** - Executar `./toolchain/setup-rk322x.sh full`
2. **Build kernel** - Executar `./scripts/build-kernel-rk322x.sh -v 6.6.22`
3. **Preparar rootfs** - Extrair e configurar Arch Linux ARM
4. **Testar boot** - Colocar no dispositivo e verificar

## 📝 Notas

- O RK322x foi descontinuado pelo Armbian em 2026
- Não existem mais pacotes pré-compilados disponíveis
- É necessário compilar o kernel manualmente
- O device tree principal é `rk322x-box.dtb`

## 🔗 Links Úteis

- [Armbian Build](https://github.com/armbian/build)
- [Linux Rockchip](https://github.com/armbian/linux-rockchip)
- [Zig Cross-compilation](https://ziglearn.org/build-system/cross-compilation)
- [Rust for ARM](https://learn.arm.com/install-guides/rust)