# socks-to-http-proxy ![Rust](https://github.com/KaranGauswami/socks-to-http-proxy/workflows/Rust/badge.svg) ![release](https://img.shields.io/github/v/release/KaranGauswami/socks-to-http-proxy?include_prereleases)

An executable to convert SOCKS5 proxy into HTTP proxy

## About

`sthp` purpose is to create HTTP proxy on top of the Socks 5 Proxy

## How it works

It uses hyper library HTTP proxy [example](https://github.com/hyperium/hyper/blob/master/examples/http_proxy.rs) and adds functionality to connect via Socks5

## Installation

### Quick install (recommended)

Clone the repo and run the installer.  The script auto-detects whether you are
root or a regular user and sets up everything accordingly.

```bash
git clone https://github.com/KaranGauswami/socks-to-http-proxy.git
cd socks-to-http-proxy

# User install (no sudo needed)
./scripts/install.sh

# System-wide install
sudo ./scripts/install.sh
```

The installer will:

- Build the binary from source (requires `cargo`) if no pre-built binary is found
- **Root mode** — installs to `/opt/sthp/`, symlinks launcher to `/usr/local/bin/socks2http`
- **User mode** — installs binary and launcher to `~/.local/bin/`
- Create a config file at `/etc/sthprc` (root) or `~/.config/sthprc` (user)
- Install and optionally enable a **systemd service**
- Register `set-proxy` / `unset-proxy` shell helpers in your shell RC files (bash, zsh, fish)

To remove:

```bash
./scripts/install.sh --uninstall   # user
sudo ./scripts/install.sh --uninstall   # system
```

### Config file

`/etc/sthprc` or `~/.config/sthprc` (user config wins):

```bash
# HTTP proxy port this service will listen on (default: 8080)
HTTP_PORT=8080

# SOCKS5 server port (default: 1080)
SOCKS_PORT=1080

# SOCKS5 server host (default: 127.0.0.1)
# SOCKS_HOST=127.0.0.1
```

Restart the service after changes:

```bash
systemctl --user restart sthp   # user install
sudo systemctl restart sthp     # system install
```

### Service management

```bash
# User install
systemctl --user {start|stop|restart|status|enable|disable} sthp

# System install
sudo systemctl {start|stop|restart|status|enable|disable} sthp
```

### Proxy helpers

After opening a new shell (or sourcing your RC file) you can quickly toggle
your terminal proxy settings:

```bash
set-proxy      # export http_proxy / https_proxy → 127.0.0.1:<HTTP_PORT>
unset-proxy    # clear all proxy environment variables
```

## Compiling manually

1.  Ensure you have current version of `cargo` and [Rust](https://www.rust-lang.org) installed
2.  Clone the project `$ git clone https://github.com/KaranGauswami/socks-to-http-proxy.git && cd socks-to-http-proxy`
3.  Build the project `$ cargo build --release`
4.  Once complete, the binary will be located at `target/release/sthp`

## Usage

```bash
sthp -p 8080 -s 127.0.0.1:1080
```

This will create proxy server on 8080 and use localhost:1080 as a Socks5 Proxy

```bash
sthp -p 8080 -s example.com:8080
```

This will create proxy server on 8080 and use example:1080 as a Socks5 Proxy

> [!NOTE]  
> The --socks-address (-s) flag does not support adding a schema at the start (e.g., socks:// or socks5h://). Currently, it only supports socks5h, which means DNS resolution will be done on the SOCKS server.

> [!WARNING]
> Since v0.5, the default listening IP changed from `0.0.0.0` to `127.0.0.1`. This restricts the proxy to the local machine only. Use `--listen-ip 0.0.0.0` to restore the old behaviour.

### Options

There are a few options for using `sthp`.

```text
Usage: sthp [OPTIONS]

Options:
  -p, --port <PORT>                        port where Http proxy should listen [default: 8080]
      --listen-ip <LISTEN_IP>              [default: 127.0.0.1]
  -u, --username <USERNAME>                Socks5 username
  -P, --password <PASSWORD>                Socks5 password
  -s, --socks-address <SOCKS_ADDRESS>      Socks5 proxy address [default: 127.0.0.1:1080]
      --allowed-domains <ALLOWED_DOMAINS>  Comma-separated list of allowed domains
      --http-basic <HTTP_BASIC>            HTTP Basic Auth credentials in the format "user:passwd"
  -d, --detached                           Run process in background ( Only for Unix based systems)
  -h, --help                               Print help
  -V, --version                            Print version
```
