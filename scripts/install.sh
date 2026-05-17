#!/usr/bin/env bash
# ============================================================
#  install.sh — Installer for sthp (socks-to-http-proxy)
# ============================================================
#  Usage:
#    sudo ./scripts/install.sh          # system-wide install
#    ./scripts/install.sh               # current-user install
#    ./scripts/install.sh --uninstall   # remove installation
# ============================================================
set -euo pipefail

BINARY_NAME="sthp"
LAUNCHER_NAME="socks2http"
SERVICE_NAME="sthp"

# ── Colour helpers ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { printf "${BLUE}[info]${NC}  %s\n"    "$*"; }
ok()   { printf "${GREEN}[ok]${NC}    %s\n"   "$*"; }
warn() { printf "${YELLOW}[warn]${NC}  %s\n"  "$*"; }
die()  { printf "${RED}[error]${NC} %s\n" "$*" >&2; exit 1; }

# ── Detect mode (root vs user) ───────────────────────────────
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    IS_ROOT=true
    INSTALL_DIR="/opt/sthp"
    BIN_LINK_DIR="/usr/local/bin"
    CONFIG_FILE="/etc/sthprc"
    SERVICE_DIR="/etc/systemd/system"
    SYSTEMCTL_ARGS=()
else
    IS_ROOT=false
    INSTALL_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/sthp"
    BIN_DIR="${HOME}/.local/bin"
    CONFIG_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/sthprc"
    SERVICE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
    SYSTEMCTL_ARGS=(--user)
fi

# ── Parse CLI args ───────────────────────────────────────────
UNINSTALL=false
for arg in "$@"; do
    case "$arg" in
        --uninstall)
            UNINSTALL=true ;;
        --help|-h)
            cat <<'HELP'
Usage:
  sudo ./scripts/install.sh          # system-wide install (root)
  ./scripts/install.sh               # current-user install
  ./scripts/install.sh --uninstall   # remove installation

Installs the socks2http launcher, config file, systemd service,
and set-proxy / unset-proxy shell helpers.
HELP
            exit 0 ;;
        *)
            die "Unknown argument: '$arg'  (try --help)" ;;
    esac
done

# ── Locate project root ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BINARY_SRC="${PROJECT_DIR}/target/release/${BINARY_NAME}"

# ═══════════════════════════════════════════════════════════════
# UNINSTALL
# ═══════════════════════════════════════════════════════════════
if $UNINSTALL; then
    info "Uninstalling sthp…"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl "${SYSTEMCTL_ARGS[@]}" stop    "$SERVICE_NAME" 2>/dev/null || true
        systemctl "${SYSTEMCTL_ARGS[@]}" disable "$SERVICE_NAME" 2>/dev/null || true
        rm -f "${SERVICE_DIR}/${SERVICE_NAME}.service"
        systemctl "${SYSTEMCTL_ARGS[@]}" daemon-reload 2>/dev/null || true
    fi

    if $IS_ROOT; then
        rm -f "${BIN_LINK_DIR}/${LAUNCHER_NAME}"
        rm -rf "$INSTALL_DIR"
        rm -f /etc/profile.d/sthp-proxy.sh
    else
        rm -f "${BIN_DIR}/${BINARY_NAME}" "${BIN_DIR}/${LAUNCHER_NAME}"
        rm -rf "$INSTALL_DIR"
        warn "Shell RC files not modified — remove 'sthp proxy helpers' blocks manually."
        warn "Fish functions: remove ~/.config/fish/functions/set-proxy.fish and unset-proxy.fish"
    fi

    warn "Config preserved: $CONFIG_FILE"
    ok "sthp uninstalled."
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════

if $IS_ROOT; then
    info "System-wide install (root mode)"
    info "  Install dir : $INSTALL_DIR"
    info "  Launcher    : ${BIN_LINK_DIR}/${LAUNCHER_NAME}"
    info "  Config      : $CONFIG_FILE"
    info "  Service     : ${SERVICE_DIR}/${SERVICE_NAME}.service"
else
    info "User install"
    info "  Install dir : $INSTALL_DIR"
    info "  Bin dir     : $BIN_DIR"
    info "  Config      : $CONFIG_FILE"
    info "  Service     : ${SERVICE_DIR}/${SERVICE_NAME}.service"
fi
echo ""

# ── Build binary if needed ───────────────────────────────────
if [[ ! -f "$BINARY_SRC" ]]; then
    info "No pre-built binary found; building from source…"
    command -v cargo >/dev/null 2>&1 \
        || die "cargo not found — install Rust from https://rustup.rs and retry."
    (cd "$PROJECT_DIR" && cargo build --release)
fi
[[ -f "$BINARY_SRC" ]] || die "Binary still missing: $BINARY_SRC"
ok "Binary ready: $BINARY_SRC"

# ── Determine concrete destination paths ─────────────────────
if $IS_ROOT; then
    BINARY_DEST="${INSTALL_DIR}/${BINARY_NAME}"
    LAUNCHER_DEST="${INSTALL_DIR}/${LAUNCHER_NAME}"
    LAUNCHER_LINK="${BIN_LINK_DIR}/${LAUNCHER_NAME}"
    SET_PROXY_DEST="${INSTALL_DIR}/set-proxy.sh"
    UNSET_PROXY_DEST="${INSTALL_DIR}/unset-proxy.sh"
else
    BINARY_DEST="${BIN_DIR}/${BINARY_NAME}"
    LAUNCHER_DEST="${BIN_DIR}/${LAUNCHER_NAME}"
    SET_PROXY_DEST="${INSTALL_DIR}/set-proxy.sh"
    UNSET_PROXY_DEST="${INSTALL_DIR}/unset-proxy.sh"
fi

# ── Create directories ───────────────────────────────────────
mkdir -p "$INSTALL_DIR" "$SERVICE_DIR"
if $IS_ROOT; then
    mkdir -p "$BIN_LINK_DIR"
else
    mkdir -p "$BIN_DIR"
fi

# ── Install binary ───────────────────────────────────────────
install -m 755 "$BINARY_SRC" "$BINARY_DEST"
ok "Binary installed: $BINARY_DEST"

# ═══════════════════════════════════════════════════════════════
# CONFIG FILE
# ═══════════════════════════════════════════════════════════════
if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << 'CONF'
# /etc/sthprc  or  ~/.config/sthprc
# sthp — SOCKS5-to-HTTP proxy configuration
# Restart the service after changes: systemctl [--user] restart sthp

# HTTP proxy port this service will listen on (default: 8080)
HTTP_PORT=8080

# SOCKS5 server port (default: 1080)
SOCKS_PORT=1080

# SOCKS5 server host (default: 127.0.0.1)
# Uncomment and change to use a remote SOCKS5 server:
# SOCKS_HOST=127.0.0.1
CONF
    $IS_ROOT || chmod 600 "$CONFIG_FILE"
    ok "Config created: $CONFIG_FILE"
else
    warn "Config already exists (keeping): $CONFIG_FILE"
fi

# ═══════════════════════════════════════════════════════════════
# LAUNCHER  (socks2http)
# ═══════════════════════════════════════════════════════════════
# The launcher reads the config file and exec's the real binary.
# BINARY_DEST is expanded at install time so the path is hard-coded.
cat > "$LAUNCHER_DEST" << LAUNCHER
#!/usr/bin/env bash
# socks2http — reads config and starts sthp
# Config (user wins over system): ~/.config/sthprc  |  /etc/sthprc

set -euo pipefail

_cfg_user="\${HOME}/.config/sthprc"
_cfg_sys="/etc/sthprc"

if [[ -f "\$_cfg_user" ]]; then
    # shellcheck source=/dev/null
    source "\$_cfg_user"
elif [[ -f "\$_cfg_sys" ]]; then
    # shellcheck source=/dev/null
    source "\$_cfg_sys"
fi

HTTP_PORT="\${HTTP_PORT:-8080}"
SOCKS_PORT="\${SOCKS_PORT:-1080}"
SOCKS_HOST="\${SOCKS_HOST:-127.0.0.1}"

# sthp expects a SocketAddr — normalise "localhost" to 127.0.0.1
[[ "\$SOCKS_HOST" == "localhost" ]] && SOCKS_HOST="127.0.0.1"

exec "${BINARY_DEST}" -p "\$HTTP_PORT" -s "\${SOCKS_HOST}:\${SOCKS_PORT}" "\$@"
LAUNCHER
chmod 755 "$LAUNCHER_DEST"
ok "Launcher created: $LAUNCHER_DEST"

if $IS_ROOT; then
    ln -sf "$LAUNCHER_DEST" "$LAUNCHER_LINK"
    ok "Symlink: $LAUNCHER_LINK → $LAUNCHER_DEST"
fi

# ═══════════════════════════════════════════════════════════════
# SET-PROXY / UNSET-PROXY  (source-able shell scripts)
# ═══════════════════════════════════════════════════════════════
cat > "$SET_PROXY_DEST" << 'SETPROXY'
# set-proxy.sh — Source this file to route terminal traffic through the HTTP proxy.
#
# IMPORTANT: do NOT execute; source it:
#   source /path/to/set-proxy.sh
# Or use the shell function the sthp installer added:
#   set-proxy

_sthp_load_cfg() {
    local u="${HOME}/.config/sthprc" s="/etc/sthprc"
    # shellcheck source=/dev/null
    if [[ -f "$u" ]]; then source "$u"
    # shellcheck source=/dev/null
    elif [[ -f "$s" ]]; then source "$s"; fi
}
_sthp_load_cfg
unset -f _sthp_load_cfg

HTTP_PORT="${HTTP_PORT:-8080}"
_p="http://127.0.0.1:${HTTP_PORT}"

export http_proxy="$_p"  export https_proxy="$_p"
export HTTP_PROXY="$_p"  export HTTPS_PROXY="$_p"
export all_proxy="$_p"   export ALL_PROXY="$_p"
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="localhost,127.0.0.1,::1"
unset _p

echo "Proxy enabled → http://127.0.0.1:${HTTP_PORT}"
SETPROXY
chmod 644 "$SET_PROXY_DEST"
ok "set-proxy.sh: $SET_PROXY_DEST"

cat > "$UNSET_PROXY_DEST" << 'UNSETPROXY'
# unset-proxy.sh — Source this file to clear proxy environment variables.
#
# IMPORTANT: do NOT execute; source it:
#   source /path/to/unset-proxy.sh
# Or use the shell function the sthp installer added:
#   unset-proxy

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
unset all_proxy  ALL_PROXY  no_proxy    NO_PROXY
echo "Proxy disabled."
UNSETPROXY
chmod 644 "$UNSET_PROXY_DEST"
ok "unset-proxy.sh: $UNSET_PROXY_DEST"

# ═══════════════════════════════════════════════════════════════
# SYSTEMD SERVICE
# ═══════════════════════════════════════════════════════════════
if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl not found — skipping service installation."
else
    if $IS_ROOT; then
        _wanted_by="multi-user.target"
    else
        _wanted_by="default.target"
    fi

    cat > "${SERVICE_DIR}/${SERVICE_NAME}.service" << SERVICE
[Unit]
Description=SOCKS5 to HTTP Proxy (sthp)
Documentation=https://github.com/KaranGauswami/socks-to-http-proxy
After=network.target

[Service]
Type=simple
ExecStart=${LAUNCHER_DEST}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=${_wanted_by}
SERVICE
    ok "Service: ${SERVICE_DIR}/${SERVICE_NAME}.service"

    systemctl "${SYSTEMCTL_ARGS[@]}" daemon-reload
    ok "systemd daemon reloaded."

    echo ""
    read -rp "Enable and start sthp service now? [Y/n] " _ans </dev/tty || _ans="Y"
    _ans="${_ans:-Y}"
    if [[ "$_ans" =~ ^[Yy]$ ]]; then
        systemctl "${SYSTEMCTL_ARGS[@]}" enable --now "$SERVICE_NAME"
        ok "Service enabled and started."
        echo ""
        systemctl "${SYSTEMCTL_ARGS[@]}" status "$SERVICE_NAME" --no-pager --lines=8 || true
    else
        echo ""
        if $IS_ROOT; then _sc="systemctl"; else _sc="systemctl --user"; fi
        info "Skipped. Manage the service with:"
        info "  $_sc enable  $SERVICE_NAME"
        info "  $_sc start   $SERVICE_NAME"
        info "  $_sc stop    $SERVICE_NAME"
        info "  $_sc restart $SERVICE_NAME"
        info "  $_sc status  $SERVICE_NAME"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# SHELL INTEGRATION  (set-proxy / unset-proxy functions)
# ═══════════════════════════════════════════════════════════════
echo ""
info "Setting up shell integration (set-proxy / unset-proxy)…"

# Bash / Zsh: define shell functions that source the helper scripts
_SNIPPET=$(cat << SNIPPET

# sthp proxy helpers — added by sthp installer
set-proxy()   { . "${SET_PROXY_DEST}"; }
unset-proxy() { . "${UNSET_PROXY_DEST}"; }
SNIPPET
)

_added=false

_add_to_rc() {
    local rc="$1"
    if [[ -f "$rc" ]] && ! grep -q "sthp proxy helpers" "$rc" 2>/dev/null; then
        printf '%s\n' "$_SNIPPET" >> "$rc"
        ok "Shell helpers added to $rc"
        _added=true
    fi
}

_add_to_rc "${HOME}/.bashrc"
_add_to_rc "${HOME}/.bash_profile"
_add_to_rc "${HOME}/.zshrc"

# System-wide profile snippet (root mode)
if $IS_ROOT; then
    _pfd="/etc/profile.d/sthp-proxy.sh"
    if ! grep -q "sthp proxy helpers" "$_pfd" 2>/dev/null; then
        { printf '#!/usr/bin/env sh\n'; printf '%s\n' "$_SNIPPET"; } > "$_pfd"
        chmod 644 "$_pfd"
        ok "System shell helpers: $_pfd"
        _added=true
    fi
fi

# Fish shell — write auto-loaded function files
_fish_fn_dir="${HOME}/.config/fish/functions"
if command -v fish >/dev/null 2>&1 || [[ -d "${HOME}/.config/fish" ]]; then
    mkdir -p "$_fish_fn_dir"

    if [[ ! -f "${_fish_fn_dir}/set-proxy.fish" ]]; then
        cat > "${_fish_fn_dir}/set-proxy.fish" << 'FISHSET'
function set-proxy --description "Enable HTTP proxy (reads sthp config)"
    # Load config variables
    set -l _cfg ""
    if test -f "$HOME/.config/sthprc"
        set _cfg "$HOME/.config/sthprc"
    else if test -f /etc/sthprc
        set _cfg /etc/sthprc
    end
    if test -n "$_cfg"
        for line in (grep -v '^#' "$_cfg" | grep -v '^\s*$')
            set -l kv (string split -m 1 = $line)
            if test (count $kv) -eq 2
                set -gx $kv[1] $kv[2]
            end
        end
    end

    set -q HTTP_PORT; or set HTTP_PORT 8080
    set -l _proxy "http://127.0.0.1:$HTTP_PORT"
    set -gx http_proxy  $_proxy
    set -gx https_proxy $_proxy
    set -gx HTTP_PROXY  $_proxy
    set -gx HTTPS_PROXY $_proxy
    set -gx all_proxy   $_proxy
    set -gx ALL_PROXY   $_proxy
    set -gx no_proxy    "localhost,127.0.0.1,::1"
    set -gx NO_PROXY    "localhost,127.0.0.1,::1"
    echo "Proxy enabled → $_proxy"
end
FISHSET
        ok "Fish function: ${_fish_fn_dir}/set-proxy.fish"
        _added=true
    fi

    if [[ ! -f "${_fish_fn_dir}/unset-proxy.fish" ]]; then
        cat > "${_fish_fn_dir}/unset-proxy.fish" << 'FISHUNSET'
function unset-proxy --description "Disable HTTP proxy"
    set -e http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    set -e all_proxy  ALL_PROXY  no_proxy    NO_PROXY
    echo "Proxy disabled."
end
FISHUNSET
        ok "Fish function: ${_fish_fn_dir}/unset-proxy.fish"
        _added=true
    fi
fi

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
if $IS_ROOT; then _mode="system"; _sc="systemctl"; else _mode="user"; _sc="systemctl --user"; fi

printf "${GREEN}%s${NC}\n" "══════════════════════════════════════════"
printf "${GREEN}  sthp installed  (%s mode)${NC}\n" "$_mode"
printf "${GREEN}%s${NC}\n" "══════════════════════════════════════════"
echo ""
echo "  Config      → $CONFIG_FILE"
echo "  Binary      → $BINARY_DEST"
echo "  Launcher    → $LAUNCHER_DEST"
echo ""
echo "  Service:"
echo "    $_sc {start|stop|restart|status} $SERVICE_NAME"
echo ""
echo "  Proxy helpers (open a new shell or reload your RC file):"
echo "    set-proxy      # route traffic through port \${HTTP_PORT:-8080}"
echo "    unset-proxy    # restore direct connection"
echo ""

if ! $_added; then
    warn "Could not detect a shell RC file. Add these lines manually:"
    echo ""
    echo "  # bash / zsh"
    echo "  set-proxy()   { . \"$SET_PROXY_DEST\"; }"
    echo "  unset-proxy() { . \"$UNSET_PROXY_DEST\"; }"
    echo ""
    echo "  # fish  (~/.config/fish/functions/set-proxy.fish already created)"
    echo ""
fi
