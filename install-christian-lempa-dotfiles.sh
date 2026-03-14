#!/usr/bin/env bash
# =============================================================================
# Christian Lempa Dotfiles — Ubuntu Installer
# Source: https://github.com/ChristianLempa/dotfiles
# Installs every file from the repo exactly as-is, Ubuntu only.
# Prompt: Oh-My-Posh with his purple xcad2k theme (no Starship).
# =============================================================================

# Never abort on error — warn and keep going
set +e
set -o pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()     { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()    { echo -e "${RED}[FAIL]${NC}  $*"; }
header() { echo -e "\n${PURPLE}━━━  $*  ━━━${NC}"; }

# ── Guard: Ubuntu only ───────────────────────────────────────────────────────
if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  err "This script is for Ubuntu only. Exiting."
  exit 1
fi

header "Christian Lempa Dotfiles — Ubuntu Installer"
echo -e "  Repo: ${CYAN}https://github.com/ChristianLempa/dotfiles${NC}"
echo ""

# ── Convenience wrapper: run a command and warn on failure, never abort ───────
run() {
  "$@" || warn "Command failed (non-fatal): $*"
}

# =============================================================================
# 1. APT — base packages
# =============================================================================
header "1. APT base packages"

run sudo apt-get update -y
run sudo apt-get install -y \
  curl wget git zsh unzip zip build-essential \
  libssl-dev libffi-dev python3 python3-pip \
  nmap telnet iperf3 jq fzf bat duf \
  fontconfig ca-certificates gnupg lsb-release \
  neofetch vim psmisc

ok "APT packages done"

# =============================================================================
# 2. Zsh — set as default shell
# =============================================================================
header "2. Set Zsh as default shell"

ZSH_PATH="$(command -v zsh 2>/dev/null || true)"
if [[ -z "$ZSH_PATH" ]]; then
  err "zsh not found after install — skipping chsh"
elif [[ "$SHELL" == "$ZSH_PATH" ]]; then
  ok "Zsh is already the default shell"
else
  grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  chsh -s "$ZSH_PATH" || warn "chsh failed — run manually: chsh -s $ZSH_PATH"
  ok "Default shell set to $ZSH_PATH"
fi

# =============================================================================
# 3. Homebrew (Linuxbrew)
# =============================================================================
header "3. Linuxbrew (Homebrew for Linux)"

# Linuxbrew requires these Ubuntu packages to build formulae
log "Installing Linuxbrew build dependencies..."
run sudo apt-get install -y \
  build-essential \
  gcc \
  procps \
  curl \
  file \
  git

if command -v brew &>/dev/null; then
  ok "Linuxbrew already installed"
  eval "$(brew shellenv 2>/dev/null)" || true
else
  log "Installing Linuxbrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || warn "Linuxbrew install failed — check https://docs.brew.sh/Homebrew-on-Linux"

  # Activate brew in the current shell session
  if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    ok "Linuxbrew installed at /home/linuxbrew/.linuxbrew"
  elif [[ -d "$HOME/.linuxbrew" ]]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    ok "Linuxbrew installed at $HOME/.linuxbrew"
  else
    warn "Linuxbrew directory not found after install — PATH may need a restart"
  fi
fi

# Persist brew shellenv in ~/.profile so it loads for every login shell
# (covers bash, zsh, and anything that sources ~/.profile)
BREW_SHELLENV_MARKER="# Linuxbrew shellenv"
if ! grep -q "$BREW_SHELLENV_MARKER" "$HOME/.profile" 2>/dev/null; then
  {
    echo ""
    echo "$BREW_SHELLENV_MARKER"
    echo 'if [[ -d /home/linuxbrew/.linuxbrew ]]; then'
    echo '  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    echo 'elif [[ -d "$HOME/.linuxbrew" ]]; then'
    echo '  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"'
    echo 'fi'
  } >> "$HOME/.profile"
  ok "Linuxbrew shellenv added to ~/.profile"
fi

# Also persist in ~/.zshenv so zsh non-login shells get brew too
if ! grep -q "$BREW_SHELLENV_MARKER" "$HOME/.zshenv" 2>/dev/null; then
  {
    echo ""
    echo "$BREW_SHELLENV_MARKER"
    echo 'if [[ -d /home/linuxbrew/.linuxbrew ]]; then'
    echo '  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    echo 'elif [[ -d "$HOME/.linuxbrew" ]]; then'
    echo '  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"'
    echo 'fi'
  } >> "$HOME/.zshenv"
  ok "Linuxbrew shellenv added to ~/.zshenv"
fi

BREW_BIN="$(command -v brew 2>/dev/null || true)"
if [[ -z "$BREW_BIN" ]]; then
  warn "brew not in PATH yet — re-run the script or run: eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
else
  ok "Linuxbrew ready: $BREW_BIN"
  brew --version 2>/dev/null || true
fi

# =============================================================================
# 4. Brew CLI tools — exact list from yadm bootstrap (Linux-safe)
# =============================================================================
header "4. Brew CLI tools (from yadm bootstrap)"

brew_tools=(
  ansible
  ansible-lint
  bat
  bottom
  cmatrix
  direnv
  duf
  dust
  eza
  fzf
  gh
  glab
  helm
  httpie
  hugo
  influxdb-cli
  iperf3
  jq
  k3sup
  kubectx
  kubernetes-cli
  nmap
  node
  opentofu
  packer
  "python@3.13"
  telnet
  terraform
  wakeonlan
  wget
  yamllint
  yq
  zoxide
  starship
  zsh-autocomplete
  zsh-autosuggestions
)

if command -v brew &>/dev/null; then
  for tool in "${brew_tools[@]}"; do
    if brew list "$tool" &>/dev/null; then
      ok "  $tool (already installed)"
    else
      log "  Installing $tool ..."
      brew install "$tool" 2>&1 || warn "  $tool install failed — skipping"
    fi
  done
else
  warn "brew not available — skipping brew tools"
fi

ok "Brew CLI tools done"

# =============================================================================
# 5. Hack Nerd Font — Christian's exact terminal font
# =============================================================================
header "5. Hack Nerd Font"

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

FONT_FOUND=0
fc-list 2>/dev/null | grep -qi "Hack" && FONT_FOUND=1 || true

if [[ $FONT_FOUND -eq 0 ]]; then
  log "Downloading Hack Nerd Font..."
  TMP_FONT=$(mktemp -d)
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" \
    -o "$TMP_FONT/Hack.zip" \
    && unzip -o "$TMP_FONT/Hack.zip" -d "$TMP_FONT/Hack" \
    && cp "$TMP_FONT/Hack"/*.ttf "$FONT_DIR/" 2>/dev/null \
    && fc-cache -fv "$FONT_DIR" &>/dev/null \
    && ok "Hack Nerd Font installed" \
    || warn "Font download failed — install manually"
  rm -rf "$TMP_FONT"
else
  ok "Hack Nerd Font already installed"
fi

# =============================================================================
# 6. FiraCode Nerd Font — used in Christian's ghostty config
# =============================================================================
header "6. FiraCode Nerd Font"

FIRA_FOUND=0
fc-list 2>/dev/null | grep -qi "FiraCode" && FIRA_FOUND=1 || true

if [[ $FIRA_FOUND -eq 0 ]]; then
  log "Downloading FiraCode Nerd Font..."
  TMP_FIRA=$(mktemp -d)
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" \
    -o "$TMP_FIRA/FiraCode.zip" \
    && unzip -o "$TMP_FIRA/FiraCode.zip" -d "$TMP_FIRA/FiraCode" \
    && cp "$TMP_FIRA/FiraCode"/*.ttf "$FONT_DIR/" 2>/dev/null \
    && fc-cache -fv "$FONT_DIR" &>/dev/null \
    && ok "FiraCode Nerd Font installed" \
    || warn "FiraCode font download failed — install manually"
  rm -rf "$TMP_FIRA"
else
  ok "FiraCode Nerd Font already installed"
fi

# =============================================================================
# 7. Oh-My-Posh — Christian's purple PowerShell-style prompt (not Starship)
# =============================================================================
header "7. Oh-My-Posh"

if command -v oh-my-posh &>/dev/null; then
  ok "Oh-My-Posh already installed"
else
  log "Installing Oh-My-Posh..."
  mkdir -p "$HOME/.local/bin"
  curl -s https://ohmyposh.dev/install.sh \
    | bash -s -- -d "$HOME/.local/bin" \
    && ok "Oh-My-Posh installed" \
    || warn "Oh-My-Posh install failed — install manually: https://ohmyposh.dev"
fi

# =============================================================================
# 8. Warp terminal — from Christian's yadm bootstrap
# =============================================================================
header "8. Warp terminal"

if command -v warp-terminal &>/dev/null || dpkg -l warp-terminal &>/dev/null 2>&1; then
  ok "Warp already installed"
else
  log "Installing Warp terminal..."
  TMP_WARP=$(mktemp -d)
  curl -fsSL "https://app.warp.dev/download?package=deb" -o "$TMP_WARP/warp.deb" \
    && sudo apt-get install -y "$TMP_WARP/warp.deb" \
    && ok "Warp installed" \
    || warn "Warp .deb install failed — try: https://www.warp.dev/linux"
  rm -rf "$TMP_WARP"
fi

# =============================================================================
# 9. Ghostty terminal
# =============================================================================
header "9. Ghostty terminal"

if command -v ghostty &>/dev/null; then
  ok "Ghostty already installed"
else
  log "Installing Ghostty via snap..."
  if command -v snap &>/dev/null; then
    sudo snap install ghostty --classic 2>/dev/null \
      && ok "Ghostty installed" \
      || warn "Ghostty snap failed — install manually: https://ghostty.org"
  else
    warn "snap not found — install Ghostty manually: https://ghostty.org"
  fi
fi

# =============================================================================
# 10. Helix editor
# =============================================================================
header "10. Helix editor"

if command -v hx &>/dev/null; then
  ok "Helix already installed"
else
  log "Installing Helix..."
  sudo add-apt-repository ppa:maveonair/helix-editor -y 2>/dev/null || true
  sudo apt-get update -y 2>/dev/null || true
  sudo apt-get install -y helix 2>/dev/null \
    || brew install helix 2>/dev/null \
    || warn "Helix install failed — install manually: https://helix-editor.com"
fi

# =============================================================================
# 11. Docker — from Christian's yadm bootstrap
# =============================================================================
header "11. Docker"

if command -v docker &>/dev/null; then
  ok "Docker already installed"
else
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo bash 2>/dev/null \
    && sudo usermod -aG docker "$USER" \
    && ok "Docker installed (log out/in to use without sudo)" \
    || warn "Docker install failed — install manually: https://docs.docker.com/engine/install/ubuntu/"
fi

# =============================================================================
# 12. PowerShell — from Christian's yadm bootstrap
# =============================================================================
header "12. PowerShell"

if command -v pwsh &>/dev/null; then
  ok "PowerShell already installed"
else
  log "Installing PowerShell..."
  source /etc/os-release
  curl -fsSL "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" \
    -o /tmp/packages-microsoft-prod.deb \
    && sudo dpkg -i /tmp/packages-microsoft-prod.deb \
    && sudo apt-get update -y \
    && sudo apt-get install -y powershell \
    && ok "PowerShell installed" \
    || warn "PowerShell install failed — install manually"
  rm -f /tmp/packages-microsoft-prod.deb
fi

# =============================================================================
# 13. NVM — Node Version Manager
# =============================================================================
header "13. NVM"

if [[ -d "$HOME/.nvm" ]]; then
  ok "NVM already installed"
else
  log "Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh \
    | bash \
    && ok "NVM installed" \
    || warn "NVM install failed — install manually: https://github.com/nvm-sh/nvm"
fi

# =============================================================================
# 14. YADM — dotfile manager, from Christian's bootstrap
# =============================================================================
header "14. YADM"

if command -v yadm &>/dev/null; then
  ok "YADM already installed"
else
  brew install yadm 2>/dev/null \
    || sudo apt-get install -y yadm 2>/dev/null \
    || warn "yadm install failed"
fi

# =============================================================================
# 15. Write ALL dotfiles — exact content from the repo, verbatim
# =============================================================================
header "15. Writing dotfiles"

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.zsh"
mkdir -p "$HOME/.ansible"
mkdir -p "$HOME/.warp/themes"
mkdir -p "$HOME/.warp/workflows"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ── .hushlogin ────────────────────────────────────────────────────────────────
touch "$HOME/.hushlogin"
ok ".hushlogin"

# ── .ansible.cfg ─────────────────────────────────────────────────────────────
cat > "$HOME/.ansible.cfg" << 'DOTEOF'
[defaults]
inventory=.ansible/clcreative-home-inventory
DOTEOF
ok ".ansible.cfg"

# ── .ansible/clcreative-home-inventory ───────────────────────────────────────
cat > "$HOME/.ansible/clcreative-home-inventory" << 'DOTEOF'
# Inventory for clcreative-home network
#
# Please only use this as an example!


# Ubuntu Production and Demo Servers

[srv-prod]
srv-prod-1.home.clcreative.de
srv-prod-2.home.clcreative.de
srv-prod-3.home.clcreative.de

[srv-demo]
srv-demo-1.home.clcreative.de
srv-demo-2.home.clcreative.de

[srv-prod-1]
srv-prod-1.home.clcreative.de

[srv-prod-2]
srv-prod-2.home.clcreative.de

[srv-prod-3]
srv-prod-3.home.clcreative.de

[srv-demo-1]
srv-demo-1.home.clcreative.de

[srv-demo-2]
srv-demo-2.home.clcreative.de

# Kubernetes Production and Demo Servers

[ksrv-prod]
ksrv-prod-1.home.clcreative.de
ksrv-prod-2.home.clcreative.de
ksrv-prod-3.home.clcreative.de

[ksrv-prod-1]
ksrv-prod-1.home.clcreative.de

[ksrv-prod-2]
ksrv-prod-2.home.clcreative.de

[ksrv-prod-3]
ksrv-prod-3.home.clcreative.de

[ksrv-demo-1]
ksrv-demo-1.home.clcreative.de

[kube-prod-1]
ksrv-prod-1.home.clcreative.de
ksrv-prod-2.home.clcreative.de
ksrv-prod-3.home.clcreative.de

[kube-demo-1]
ksrv-demo-1.home.clcreative.de

# Proxmox and Nas machine

[prx-prod-1]
prx-prod-1.home.clcreative.de

[nas-prod-1]
nas-prod-1.home.clcreative.de

# Windows Servers and Clients

[wdc-prod-1]
wdc-prod-1.home.clcreative.de

[win-prod-1]
win-prod-1.home.clcreative.de
DOTEOF
ok ".ansible/clcreative-home-inventory"

# ── .zshenv ───────────────────────────────────────────────────────────────────
cat > "$HOME/.zshenv" << 'DOTEOF'
# Added locations to path variable
export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin

# NVM directory
export NVM_DIR="$HOME/.nvm"

export EDITOR=vim
export KUBE_EDITOR=vim

# Homebrew (Linuxbrew)
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -d "$HOME/.linuxbrew" ]]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi
DOTEOF
ok ".zshenv"

# ── .zsh/aliases.zsh — exact from repo ───────────────────────────────────────
cat > "$HOME/.zsh/aliases.zsh" << 'DOTEOF'
alias k="kubectl"
alias kc="kubectx"
alias kn="kubens"
alias h="helm"
alias tf="terraform"
alias a="ansible"
alias ap="ansible-playbook"
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first -l"
alias bp="boilerplates"
alias prx="proxmox-manager"
DOTEOF
ok ".zsh/aliases.zsh"

# ── .zsh/functions.zsh — exact from repo ─────────────────────────────────────
cat > "$HOME/.zsh/functions.zsh" << 'DOTEOF'
# Colormap
function colormap() {
  for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done
}
DOTEOF
ok ".zsh/functions.zsh"

# ── .zsh/nvm.zsh — exact from repo ───────────────────────────────────────────
cat > "$HOME/.zsh/nvm.zsh" << 'DOTEOF'
# NVM lazy load
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  alias nvm='unalias nvm node npm && . "$NVM_DIR"/nvm.sh && nvm'
  alias node='unalias nvm node npm && . "$NVM_DIR"/nvm.sh && node'
  alias npm='unalias nvm node npm && . "$NVM_DIR"/nvm.sh && npm'
fi
DOTEOF
ok ".zsh/nvm.zsh"

# ── .zsh/wsl2fix.zsh — exact from repo ───────────────────────────────────────
cat > "$HOME/.zsh/wsl2fix.zsh" << 'DOTEOF'
# Fix Interop Error that randomly occurs in vscode terminal when using WSL2
fix_wsl2_interop() {
    for i in $(pstree -np -s $$ | grep -o -E '[0-9]+'); do
        if [[ -e "/run/WSL/${i}_interop" ]]; then
            export WSL_INTEROP=/run/WSL/${i}_interop
        fi
    done
}
DOTEOF
ok ".zsh/wsl2fix.zsh"

# ── .zsh/starship.zsh — exact from repo ──────────────────────────────────────
cat > "$HOME/.zsh/starship.zsh" << 'DOTEOF'
# find out which distribution we are running on
LFILE="/etc/*-release"
MFILE="/System/Library/CoreServices/SystemVersion.plist"
if [[ -f $LFILE ]]; then
  _distro=$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }')
elif [[ -f $MFILE ]]; then
  _distro="macos"

  # on mac os use the systemprofiler to determine the current model
  _device=$(system_profiler SPHardwareDataType | awk '/Model Name/ {print $3,$4,$5,$6,$7}')

  case $_device in
    *MacBook*)     DEVICE="";;
    *mini*)        DEVICE="󰇄";;
    *)             DEVICE="";;
  esac
fi

# set an icon based on the distro
# make sure your font is compatible with https://github.com/lukas-w/font-logos
case $_distro in
    *kali*)                  ICON="ﴣ";;
    *arch*)                  ICON="";;
    *debian*)                ICON="";;
    *raspbian*)              ICON="";;
    *ubuntu*)                ICON="";;
    *elementary*)            ICON="";;
    *fedora*)                ICON="";;
    *coreos*)                ICON="";;
    *gentoo*)                ICON="";;
    *mageia*)                ICON="";;
    *centos*)                ICON="";;
    *opensuse*|*tumbleweed*) ICON="";;
    *sabayon*)               ICON="";;
    *slackware*)             ICON="";;
    *linuxmint*)             ICON="";;
    *alpine*)                ICON="";;
    *aosc*)                  ICON="";;
    *nixos*)                 ICON="";;
    *devuan*)                ICON="";;
    *manjaro*)               ICON="";;
    *rhel*)                  ICON="";;
    *macos*)                 ICON="";;
    *)                       ICON="";;
esac

export STARSHIP_DISTRO="$ICON"
export STARSHIP_DEVICE="$DEVICE"
DOTEOF
ok ".zsh/starship.zsh"

# ── .zshrc ────────────────────────────────────────────────────────────────────
# Matches Christian's .zshrc exactly:
#   - starship.zsh line is commented out (same as his repo)
#   - macOS-only paths removed
#   - Oh-My-Posh loads the purple xcad2k prompt instead of starship init
cat > "$HOME/.zshrc" << 'DOTEOF'
[[ -f ~/.zsh/secrets.zsh ]]   && source ~/.zsh/secrets.zsh
[[ -f ~/.zsh/aliases.zsh ]]   && source ~/.zsh/aliases.zsh
[[ -f ~/.zsh/functions.zsh ]] && source ~/.zsh/functions.zsh
# [[ -f ~/.zsh/starship.zsh ]] && source ~/.zsh/starship.zsh
[[ -f ~/.zsh/nvm.zsh ]]       && source ~/.zsh/nvm.zsh
[[ -f ~/.zsh/wsl2fix.zsh ]]   && source ~/.zsh/wsl2fix.zsh

# Auto-Complete & Auto-Suggestions plugin
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '')"
[[ -f "$BREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] && \
  source "$BREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
[[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
  source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Load Oh-My-Posh — Christian's purple xcad2k prompt (no Starship on Linux)
if command -v oh-my-posh &>/dev/null; then
  eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/themes/christian.omp.json")"
fi

# Load Direnv
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# Load zoxide
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# kubectl krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Go binaries
export PATH="$HOME/go/bin:$PATH"
DOTEOF
ok ".zshrc"

# ── .config/starship.toml — exact from uploaded file ─────────────────────────
cat > "$HOME/.config/starship.toml" << 'DOTEOF'
# ~/.config/starship.toml

add_newline = false
command_timeout = 100
format = """
$os$username$hostname$kubernetes$directory$git_branch$git_status
 
"""

# Drop ugly default prompt characters
[character]
success_symbol = ''
error_symbol = ''

# ---

[os]
format = '[$symbol](bold white) '
disabled = false

[os.symbols]
Windows = ' '
Arch = '󰣇'
Ubuntu = ''
Macos = '󰀵'

# ---

# Shows the username
[username]
style_user = 'white bold'
style_root = 'black bold'
format = '[$user]($style) '
disabled = false
show_always = true

# Shows the hostname
[hostname]
ssh_only = false
format = 'on [$hostname](bold yellow) '
disabled = false

# Shows current directory
[directory]
truncation_length = 1
truncation_symbol = '…/'
home_symbol = '󰋜 ~'
read_only_style = '197'
read_only = '  '
format = 'at [$path]($style)[$read_only]($read_only_style) '

# Shows current git branch
[git_branch]
symbol = ' '
format = 'via [$symbol$branch]($style)'
# truncation_length = 4
truncation_symbol = '…/'
style = 'bold green'

# Shows current git status
[git_status]
format = '([ \( $all_status$ahead_behind\)]($style) )'
style = 'bold green'
conflicted = '[ confliced=${count}](red) '
up_to_date = '[󰘽 up-to-date](green) '
untracked = '[󰋗 untracked=${count}](red) '
ahead = ' ahead=${count}'
diverged = ' ahead=${ahead_count}  behind=${behind_count}'
behind = ' behind=${count}'
stashed = '[ stashed=${count}](green) '
modified = '[󰛿 modified=${count}](yellow) '
staged = '[󰐗 staged=${count}](green) '
renamed = '[󱍸 renamed=${count}](yellow) '
deleted = '[󰍶 deleted=${count}](red) '

# Shows kubernetes context and namespace
[kubernetes]
format = 'via [󱃾 $context\($namespace\)](bold purple) '
disabled = false

# ---

[vagrant]
disabled = true

[docker_context]
disabled = true

[helm]
disabled = true

[python]
disabled = false

[nodejs]
disabled = true

[ruby]
disabled = true

[terraform]
disabled = true
DOTEOF
ok ".config/starship.toml"

# ── .config/goto — exact from repo ───────────────────────────────────────────
cat > "$HOME/.config/goto" << 'DOTEOF'
prj /Users/xcad/Projects
clc /Users/xcad/Projects/clcreative
cs /Users/xcad/Projects/christianlempa/cheat-sheets
bp /Users/xcad/Projects/christianlempa/boilerplates
cl /Users/xcad/Projects/christianlempa/christianlempa
vid /Users/xcad/Projects/christianlempa/videos
obs /Users/xcad/Library/Mobile Documents/iCloud~md~obsidian/Documents
content /Users/xcad/Library/Mobile Documents/iCloud~md~obsidian/Documents/content
cheatsheets /Users/xcad/Library/Mobile Documents/iCloud~md~obsidian/Documents/cheat-sheets
projects /Users/xcad/Library/Mobile Documents/iCloud~md~obsidian/Documents/projects
home /Users/xcad/
DOTEOF
ok ".config/goto"

# ── .config/ghostty/ — exact from repo ───────────────────────────────────────
mkdir -p "$HOME/.config/ghostty/themes"

cat > "$HOME/.config/ghostty/config" << 'DOTEOF'
window-padding-x = 8
window-padding-y = 8

font-family = FiraCode Nerd Font
font-size = 16
theme = dark:xcad2k-dark, light:xcad2k-light

background-opacity = 0.95
background-blur = true
DOTEOF

cat > "$HOME/.config/ghostty/themes/xcad2k-dark" << 'DOTEOF'
background = #191919
foreground = #F1F1F1
cursor-color = #28B9FF
selection-background = #444444
selection-foreground = #F1F1F1

palette = 0=#121212
palette = 1=#A52AFF
palette = 2=#7129FF
palette = 3=#3D2AFF
palette = 4=#2B4FFF
palette = 5=#2883FF
palette = 6=#28B9FF
palette = 7=#F1F1F1
palette = 8=#666666
palette = 9=#BA5AFF
palette = 10=#905AFF
palette = 11=#657B83
palette = 12=#5C78FF
palette = 13=#5EA2FF
palette = 14=#5AC8FF
palette = 15=#FFFFFF
DOTEOF

cat > "$HOME/.config/ghostty/themes/xcad2k-light" << 'DOTEOF'
background = #EFEFEF
foreground = #A0A1A5
cursor-color = #28B9FF
selection-background = #D8D8D8
selection-foreground = #A0A1A5

palette = 0=#EDEFF1
palette = 1=#A52AFF
palette = 2=#7129FF
palette = 3=#3D2AFF
palette = 4=#2B4FFF
palette = 5=#2883FF
palette = 6=#28B9FF
palette = 7=#F1F1F1
palette = 8=#666666
palette = 9=#BA5AFF
palette = 10=#905AFF
palette = 11=#657B83
palette = 12=#5C78FF
palette = 13=#5EA2FF
palette = 14=#5AC8FF
palette = 15=#A0A1A5
DOTEOF
ok ".config/ghostty/ (config + xcad2k-dark + xcad2k-light)"

# ── .config/helix/ — exact from repo ─────────────────────────────────────────
mkdir -p "$HOME/.config/helix/themes"

cat > "$HOME/.config/helix/config.toml" << 'DOTEOF'
theme = "christian"

[editor]
line-number = "absolute"
mouse = true

[editor.statusline]
left = ["mode", "spinner"]
center = ["file-name"]
right = ["diagnostics", "selections", "position", "file-encoding", "file-line-ending", "file-type"]
separator = "│"

[keys.normal]
"del" = "delete_selection"
"C-c" = ":clipboard-yank"

[editor.indent-guides]
render = false
character = ""
DOTEOF

cat > "$HOME/.config/helix/themes/christian.toml" << 'DOTEOF'
"ui.background" = "light-black"
"ui.text" = "white"
"ui.menu" = { fg = "black", bg = "light-gray" }
"ui.menu.selected" = { modifiers = ["reversed"] }
"ui.popup" = { modifiers = ["reversed"] }
"ui.linenr" = "gray"
"ui.linenr.selected" = { fg = "white", bg = "black", modifiers = ["bold"] }
"ui.selection" = { fg = "black", bg = "blue" }
"ui.selection.primary" = { fg = "white", bg = "blue" }
"comment" = { fg = "gray" }
"ui.statusline" = { fg = "white", bg = "black" }
"ui.cursor" = { fg = "white", modifiers = ["reversed"] }
"variable" = "red"
"constant.numeric" = "yellow"
"constant" = "yellow"
"attributes" = "yellow"
"type" = "yellow"
"ui.cursor.match" = { fg = "yellow", modifiers = ["underlined"] }
"string"  = "green"
"variable.other.member" = "green"
"constant.character.escape" = "cyan"
"function" = "blue"
"constructor" = "blue"
"special" = "blue"
"keyword" = "magenta"
"label" = "magenta"
"namespace" = "magenta"
"ui.help" = { fg = "white", bg = "black" }

"ui.virtual.indent-guide" = "black"
"ui.virtual.indent-guide.selected" = { bg = "black"}

"markup.heading" = "blue"
"markup.list" = "red"
"markup.bold" = { fg = "yellow", modifiers = ["bold"] }
"markup.italic" = { fg = "magenta", modifiers = ["italic"] }
"markup.link.url" = { fg = "yellow", modifiers = ["underlined"] }
"markup.link.text" = "red"
"markup.quote" = "cyan"
"markup.raw" = "green"

"diff.plus" = "green"
"diff.delta" = "yellow"
"diff.minus" = "red"

"diagnostic" = { modifiers = ["underlined"] }
"ui.gutter" = { bg = "black" }
"info" = "blue"
"hint" = "gray"
"debug" = "gray"
"warning" = "yellow"
"error" = "red"


[palette]
black     = "#1A1A1A"
blue      = "#5c78ff"
cyan      = "#5ac8ff"
green     = "#905aff"
magenta   = "#5ea2ff"
red       = "#ba5aff"
white     = "#ffffff"
yellow    = "#657b83"
gray      = "#171717"

light-black   = "#666666"
light-blue    = "#2b4fff"
light-cyan    = "#28b9ff"
light-green   = "#7129ff"
light-magenta = "#2883ff"
light-red     = "#a52aff"
light-white   = "#f1f1f1"
light-yellow  = "#3d2aff"
light-gray    = "#1d1d1d"
DOTEOF
ok ".config/helix/ (config.toml + christian.toml theme)"

# ── .config/neofetch/ — exact from repo ──────────────────────────────────────
mkdir -p "$HOME/.config/neofetch"

cat > "$HOME/.config/neofetch/config.conf" << 'DOTEOF'
print_info() {
    info title
    info underline

    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "WM Theme" wm_theme
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory

    # info "GPU Driver" gpu_driver  # Linux/macOS only
    # info "CPU Usage" cpu_usage
    # info "Disk" disk
    # info "Battery" battery
    # info "Font" font
    # info "Song" song
    # [[ "$player" ]] && prin "Music Player" "$player"
    # info "Local IP" local_ip
    # info "Public IP" public_ip
    # info "Users" users
    # info "Locale" locale  # This only works on glibc systems.

    info cols
}
DOTEOF

cat > "$HOME/.config/neofetch/thedigitallife.txt" << 'DOTEOF'
      ██████ ███████████████████▇▅▖ 
      ██████   ████████████████████▙
      ██████     ███████████████████
          ████              ██████
██      ████                ██████
████  ████                  ██████
      ██████                   ██████
      ██████                   ██████
      ██████                   ██████
      ██████                   ██████
      ██████████ ███████████████████
      ████████   ██████████████████▛
      ██████     ████████████████▀▘ 
DOTEOF
ok ".config/neofetch/ (config.conf + thedigitallife.txt)"

# ── .config/oh-my-posh/ — Christian's purple xcad2k prompt theme ─────────────
mkdir -p "$HOME/.config/oh-my-posh/themes"

cat > "$HOME/.config/oh-my-posh/themes/christian.omp.json" << 'DOTEOF'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "blocks": [
    {
      "alignment": "left",
      "segments": [
        {
          "foreground": "#A52AFF",
          "style": "plain",
          "template": "\u256d\u2500 ",
          "type": "text"
        },
        {
          "foreground": "#A52AFF",
          "style": "plain",
          "template": "{{ .Name }} ",
          "type": "os"
        },
        {
          "foreground": "#F1F1F1",
          "style": "plain",
          "template": "{{ .UserName }} ",
          "type": "session"
        },
        {
          "foreground": "#5C78FF",
          "style": "plain",
          "template": "on \uf0e8 {{ .HostName }} ",
          "type": "session"
        },
        {
          "foreground": "#7129FF",
          "properties": {
            "home_icon": "\uf015 ~",
            "style": "agnoster_short",
            "max_depth": 3
          },
          "style": "plain",
          "template": "at {{ .Path }} ",
          "type": "path"
        },
        {
          "foreground": "#905AFF",
          "style": "plain",
          "template": "via \ue0a0 {{ .HEAD }}{{ if .Working.Changed }} \uf044 {{ .Working.String }}{{ end }}{{ if .Staging.Changed }} \uf046 {{ .Staging.String }}{{ end }} ",
          "type": "git"
        },
        {
          "foreground": "#BA5AFF",
          "style": "plain",
          "template": "via \uf3e2 {{ .Context }}({{ .Namespace }}) ",
          "type": "kubectl"
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "foreground": "#A52AFF",
          "style": "plain",
          "template": "\u2570\u2500 ",
          "type": "text"
        },
        {
          "foreground": "#28B9FF",
          "style": "plain",
          "template": "\u276f ",
          "type": "text"
        }
      ],
      "type": "prompt"
    }
  ],
  "final_space": true,
  "version": 3
}
DOTEOF
ok ".config/oh-my-posh/themes/christian.omp.json"

# ── .warp/themes/ — xcad dark + light ────────────────────────────────────────
# Warp Linux reads themes from the XDG data dir, NOT ~/.warp/themes/
# Official docs: ${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes/
# Some builds also use warp_terminal (underscore) — write to all locations.

WARP_THEME_DIR1="${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes"
WARP_THEME_DIR2="${XDG_DATA_HOME:-$HOME/.local/share}/warp_terminal/themes"
WARP_THEME_DIR3="$HOME/.warp/themes"

mkdir -p "$WARP_THEME_DIR1"
mkdir -p "$WARP_THEME_DIR2"
mkdir -p "$WARP_THEME_DIR3"

# Write theme to a temp file then copy to all locations
TMP_DARK=$(mktemp)
TMP_LIGHT=$(mktemp)

cat > "$TMP_DARK" << 'DOTEOF'
---
accent: '#28b9ff'
background: '#191919'
details: darker
foreground: '#f1f1f1'
terminal_colors:
  bright:
    black: '#666666'
    blue: '#5c78ff'
    cyan: '#5ac8ff'
    green: '#905aff'
    magenta: '#5ea2ff'
    red: '#ba5aff'
    white: '#ffffff'
    yellow: '#657b83'
  normal:
    black: '#121212'
    blue: '#2b4fff'
    cyan: '#28b9ff'
    green: '#7129ff'
    magenta: '#2883ff'
    red: '#a52aff'
    white: '#f1f1f1'
    yellow: '#3d2aff'
DOTEOF

cat > "$TMP_LIGHT" << 'DOTEOF'
---
accent: '#28b9ff'
background: '#efefef'
details: lighter
foreground: '#a0a1a5'
terminal_colors:
  bright:
    black: '#666666'
    blue: '#5c78ff'
    cyan: '#5ac8ff'
    green: '#905aff'
    magenta: '#5ea2ff'
    red: '#ba5aff'
    white: '#a0a1a5'
    yellow: '#657b83'
  normal:
    black: '#edeff1'
    blue: '#2b4fff'
    cyan: '#28b9ff'
    green: '#7129ff'
    magenta: '#2883ff'
    red: '#a52aff'
    white: '#f1f1f1'
    yellow: '#3d2aff'
DOTEOF

# Copy to every known Warp Linux theme location
for DIR in "$WARP_THEME_DIR1" "$WARP_THEME_DIR2" "$WARP_THEME_DIR3"; do
  cp "$TMP_DARK"  "$DIR/xcad2k-dark.yaml"
  cp "$TMP_LIGHT" "$DIR/xcad2k-light.yaml"
  # Also write with .yml extension in case Warp checks that
  cp "$TMP_DARK"  "$DIR/xcad2k-dark.yml"
  cp "$TMP_LIGHT" "$DIR/xcad2k-light.yml"
done

rm -f "$TMP_DARK" "$TMP_LIGHT"

ok ".warp themes written to all Linux locations:"
ok "  $WARP_THEME_DIR1/"
ok "  $WARP_THEME_DIR2/"
ok "  $WARP_THEME_DIR3/"
log "Restart Warp then: Settings → Appearance → Theme → xcad2k-dark"

# ── .warp/workflows/ — all 7, exact from repo ────────────────────────────────
cat > "$HOME/.warp/workflows/create-certificate-extfile.yml" << 'DOTEOF'
---
name: Create SSL/TLS Certificate Extfile
command: "echo \"subjectAltName=DNS:{{dns}}\" >> extfile.cnf"
tags:
  - openssl
  - certificate
  - ssl
  - tls
description: "Create SSL/TLS Certificate Extfile"
arguments:
  - name: dns
    description: DNS
    default_value: your-dns-record
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF

cat > "$HOME/.warp/workflows/create-certificate-from-csr.yml" << 'DOTEOF'
---
name: Create SSL/TLS Certificate from CSR
command: "openssl x509 -req -sha256 -days {{days}} -in {{certificate}}.csr -CA {{ca}}.crt -CAkey {{ca-key}}.key -out {{certificate}}.crt -extfile extfile.cnf -CAcreateserial"
tags:
  - openssl
  - certificate
  - ssl
  - tls
description: "Create SSL/TLS Certificate from CSR"
arguments:
  - name: certificate
    description: Name
    default_value: cert
  - name: days
    description: Days
    default_value: 365
  - name: ca
    description: CA
    default_value: your-dns-record    
  - name: ca-key
    description: CA
    default_value: your-dns-record    
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF

cat > "$HOME/.warp/workflows/create-certificate-private-key.yml" << 'DOTEOF'
---
name: Create SSL/TLS Certificate Private Key
command: "openssl genrsa -out {{certificate}}.key {{length}}"
tags:
  - openssl
  - certificate
  - ssl
  - tls
description: "Create SSL/TLS Certificate Private Key"
arguments:
  - name: certificate
    description: Name
    default_value: cert
  - name: length
    description: Key Length
    default_value: 4096
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF

cat > "$HOME/.warp/workflows/create-certificate-signing-request.yml" << 'DOTEOF'
---
name: Create SSL/TLS Certificate Signing Request
command: "openssl req -new -sha256 -subj \"/CN={{certificate}}\" -key {{certificate}}.key -out {{certificate}}.csr"
tags:
  - openssl
  - certificate
  - ssl
  - tls
description: "Create SSL/TLS Certificate Signing Request"
arguments:
  - name: certificate
    description: Name
    default_value: cert
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF

cat > "$HOME/.warp/workflows/create-self-signed-certificate-from-ca.yml" << 'DOTEOF'
---
name: Create self-signed SSL/TLS Certificate from CA
command: |-
  openssl genrsa -out {{certificate}}.key 4096
  openssl req -new -sha256 -subj "/CN={{certificate}}" -key {{certificate}}.key -out {{certificate}}.csr
  echo "subjectAltName=DNS:{{dns}}" > extfile.cnf
  openssl x509 -req -sha256 -days {{days}} -in {{certificate}}.csr -CA {{ca}}.crt -CAkey {{ca-key}}.key -out {{certificate}}.crt -extfile extfile.cnf -CAcreateserial
tags:
  - openssl
  - certificate
  - ssl
  - tls
description: "Create self-signed SSL/TLS Certificate from CA."
arguments:
  - name: certificate
    description: The name of the certificate file and key.
    default_value: cert
  - name: dns
    description: The hostname /subjectAltName the certificate is valid for.
    default_value: localhost
  - name: days
    description: How long is this certificate valid.
    default_value: 365
  - name: ca
    description: Certificate Authority to sign this certificate.
    default_value: ca
  - name: ca-key
    description: Certificate Authoritys private key to sign this certificate.
    default_value: ca  
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF

cat > "$HOME/.warp/workflows/switch-to-a-different-namespace.yml" << 'DOTEOF'
---
name: Switch to a different namespace
command: "kubectl config set-context --current --namespace={{namespace}}"
tags:
  - kubectl
description: "Switch to a different namespace"
arguments:
  - name: namespace
    description: The Namespace you want to switch to
    default_value: default
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF

cat > "$HOME/.warp/workflows/unset-current-kubernetes-context.yml" << 'DOTEOF'
---
name: Unset current Kubernetes Context
command: "kubectl config unset current-context"
tags:
  - kubectl
description: "Unset current Kubernetes Context"
source_url: "https://github.com/christianlempa/dotfiles"
author: Christian Lempa
author_url: "https://github.com/christianlempa"
shells: []
DOTEOF
ok ".warp/workflows/ (all 7)"

# ── .ssh/config — exact from repo (OrbStack include removed for Linux) ─────────
if [[ ! -f "$HOME/.ssh/config" ]]; then
  cat > "$HOME/.ssh/config" << 'DOTEOF'
Host *
    AddKeysToAgent yes

Host srv-prod-1.home.clcreative.de
	User xcad

Host srv-prod-2.home.clcreative.de
	User xcad

Host srv-prod-3.home.clcreative.de
	User xcad

Host srv-prod-4.home.clcreative.de
	User xcad

Host srv-prod-5.home.clcreative.de
	User xcad

Host srv-prod-6.home.clcreative.de
	User xcad

Host srv-prod-7.home.clcreative.de
	User xcad

Host srv-prod-8.home.clcreative.de
	User xcad

Host srv-prod-9.home.clcreative.de
	User xcad

Host srv-prod-10.home.clcreative.de
	User xcad

Host srv-prod-11.home.clcreative.de
	User xcad

Host srv-prod-12.cloud.clcreative.de
	User xcad

Host nas-prod-1.home.clcreative.de
	User xcad

Host nas-prod-2.home.clcreative.de
	User root

Host prx-prod-1.home.clcreative.de
	User root

Host prx-prod-2.home.clcreative.de
	User root

Host srv-test-1.home.clcreative.de
	User xcad

Host srv-test-2.home.clcreative.de
	User xcad

Host srv-test-3.home.clcreative.de
	User xcad

Host srv-test-4.home.clcreative.de
	User xcad

Host srv-test-5.home.clcreative.de
	User xcad

Host nas-test-1.home.clcreative.de
	User xcad

Host nas-test-2.home.clcreative.de
	User root
DOTEOF
  chmod 600 "$HOME/.ssh/config"
  ok ".ssh/config"
else
  ok ".ssh/config (already exists — not overwritten)"
fi

# ── .config/yadm/bootstrap — exact from repo ─────────────────────────────────
mkdir -p "$HOME/.config/yadm"
cat > "$HOME/.config/yadm/bootstrap" << 'DOTEOF'
#!/bin/sh

# install essential formulae tools
brew install ansible
brew install ansible-lint
brew install bat
brew install bottom
brew install cmatrix
brew install direnv
brew install docker
brew install duf
brew install dust
brew install eza
brew install font-hack-nerd-font
brew install fzf
brew install gh
brew install glab
brew install helm
brew install httpie
brew install hugo
brew install influxdb-cli
brew install iperf3
brew install jq
brew install k3sup
brew install kubectx
brew install kubernetes-cli
brew install nmap
brew install node
brew install opentofu
brew install packer
brew install python@3.13
brew install teleport
brew install telnet
brew install terraform
brew install vhs
brew install wakeonlan
brew install wget
brew install yadm
brew install yamllint
brew install yq
brew install zoxide

# install essential cask tools
brew install --cask 1password-cli
brew install --cask alt-tab
brew install --cask commandpost
brew install --cask detail
brew install --cask discord
brew install --cask github
brew install --cask grammarly-desktop
brew install --cask google-chrome
brew install --cask httpie
brew install --cask markedit
brew install --cask notion
brew install --cask notion-calendar
brew install --cask orbstack
brew install --cask powershell
brew install --cask raindropio
brew install --cask raycast
brew install --cask remote-desktop-manager
brew install --cask slack
brew install --cask spotify
brew install --cask warp
brew install --cask zoom
DOTEOF
chmod +x "$HOME/.config/yadm/bootstrap"
ok ".config/yadm/bootstrap"

# =============================================================================
# 16. Starship prompt — install + write custom starship.toml
# =============================================================================
header "16. Starship prompt"

if command -v starship &>/dev/null; then
  ok "Starship already installed"
else
  log "Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes \
    && ok "Starship installed" \
    || warn "Starship install failed — trying brew fallback"
  command -v starship &>/dev/null || brew install starship 2>/dev/null || warn "Starship brew install also failed"
fi

# Write starship.toml — exact from uploaded file
cat > "$HOME/.config/starship.toml" << 'DOTEOF'
# ~/.config/starship.toml

add_newline = false
command_timeout = 100
format = """
$os$username$hostname$kubernetes$directory$git_branch$git_status
 
"""

# Drop ugly default prompt characters
[character]
success_symbol = ''
error_symbol = ''

# ---

[os]
format = '[$symbol](bold white) '
disabled = false

[os.symbols]
Windows = ' '
Arch = '󰣇'
Ubuntu = ''
Macos = '󰀵'

# ---

# Shows the username
[username]
style_user = 'white bold'
style_root = 'black bold'
format = '[$user]($style) '
disabled = false
show_always = true

# Shows the hostname
[hostname]
ssh_only = false
format = 'on [$hostname](bold yellow) '
disabled = false

# Shows current directory
[directory]
truncation_length = 1
truncation_symbol = '…/'
home_symbol = '󰋜 ~'
read_only_style = '197'
read_only = '  '
format = 'at [$path]($style)[$read_only]($read_only_style) '

# Shows current git branch
[git_branch]
symbol = ' '
format = 'via [$symbol$branch]($style)'
# truncation_length = 4
truncation_symbol = '…/'
style = 'bold green'

# Shows current git status
[git_status]
format = '([ \( $all_status$ahead_behind\)]($style) )'
style = 'bold green'
conflicted = '[ confliced=${count}](red) '
up_to_date = '[󰘽 up-to-date](green) '
untracked = '[󰋗 untracked=${count}](red) '
ahead = ' ahead=${count}'
diverged = ' ahead=${ahead_count}  behind=${behind_count}'
behind = ' behind=${count}'
stashed = '[ stashed=${count}](green) '
modified = '[󰛿 modified=${count}](yellow) '
staged = '[󰐗 staged=${count}](green) '
renamed = '[󱍸 renamed=${count}](yellow) '
deleted = '[󰍶 deleted=${count}](red) '

# Shows kubernetes context and namespace
[kubernetes]
format = 'via [󱃾 $context\($namespace\)](bold purple) '
disabled = false

# ---

[vagrant]
disabled = true

[docker_context]
disabled = true

[helm]
disabled = true

[python]
disabled = false

[nodejs]
disabled = true

[ruby]
disabled = true

[terraform]
disabled = true
DOTEOF
ok ".config/starship.toml"

# Update .zshrc to load starship (replace OMP with starship eval)
# Starship is now the prompt — comment out OMP, enable starship
sed -i 's|^# \[\[ -f ~/.zsh/starship.zsh \]\].*|[[ -f ~/.zsh/starship.zsh ]] \&\& source ~/.zsh/starship.zsh|' "$HOME/.zshrc"
# Replace the oh-my-posh eval block with starship init
if grep -q "oh-my-posh" "$HOME/.zshrc"; then
  sed -i '/# Load Oh-My-Posh/,/fi$/c\# Load Starship prompt\ncommand -v starship \&>/dev/null \&\& eval "$(starship init zsh)"' "$HOME/.zshrc"
fi
ok ".zshrc updated to use Starship"

# =============================================================================
# 17. GNOME dark theme
# =============================================================================
header "17. GNOME dark theme"

if command -v gsettings &>/dev/null; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null \
    && ok "GNOME color-scheme set to prefer-dark" \
    || warn "gsettings color-scheme failed"
  gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark' 2>/dev/null \
    || gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null \
    || warn "gtk-theme dark set failed — set manually in Settings → Appearance"
  ok "GNOME dark theme applied"
else
  warn "gsettings not found — set dark mode manually in Settings → Appearance"
fi

# =============================================================================
# 18. Mr. Robot wallpaper — download + set
# =============================================================================
header "18. Mr. Robot wallpaper"

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER_FILE="$WALLPAPER_DIR/mr-robot-wallpaper.png"
mkdir -p "$WALLPAPER_DIR"

# GitHub raw URL for the wallpaper
WALLPAPER_URL="https://raw.githubusercontent.com/ChristianLempa/hackbox/main/src/assets/mr-robot-wallpaper.png"

if [[ -f "$WALLPAPER_FILE" ]]; then
  ok "Wallpaper already downloaded"
else
  log "Downloading Mr. Robot wallpaper..."
  curl -fsSL "$WALLPAPER_URL" -o "$WALLPAPER_FILE" \
    && ok "Wallpaper downloaded → $WALLPAPER_FILE" \
    || warn "Wallpaper download failed — download manually: $WALLPAPER_URL"
fi

# Set wallpaper via gsettings (works on GNOME / Ubuntu desktop)
if [[ -f "$WALLPAPER_FILE" ]] && command -v gsettings &>/dev/null; then
  gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_FILE" 2>/dev/null || true
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_FILE" 2>/dev/null \
    && ok "Wallpaper set (light + dark)" \
    || warn "gsettings wallpaper set failed — right-click desktop → Set as wallpaper"
  gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null || true
else
  warn "Cannot set wallpaper — either file missing or gsettings unavailable"
fi

# =============================================================================
# 19. Ubuntu terminal — xcad colour scheme + Hack Nerd Font
# =============================================================================
header "19. Ubuntu terminal — xcad colour scheme + Hack Nerd Font"

# Install required tools first
sudo apt-get install -y dconf-cli uuid-runtime gnome-terminal 2>/dev/null || true

if ! command -v dconf &>/dev/null; then
  warn "dconf not available — cannot apply terminal colours automatically"
else

  # ── Get or create the default GNOME Terminal profile UUID ─────────────────
  # gsettings returns the value with surrounding quotes e.g. 'abc-123'
  # We strip ALL quotes and whitespace to get a clean UUID
  PROFILE_ID="$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null \
    | sed "s/'//g" | tr -d '[:space:]')"

  if [[ -z "$PROFILE_ID" ]]; then
    PROFILE_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
    gsettings set org.gnome.Terminal.ProfilesList list "['${PROFILE_ID}']" 2>/dev/null || true
    gsettings set org.gnome.Terminal.ProfilesList default "'${PROFILE_ID}'" 2>/dev/null || true
    log "Created new GNOME Terminal profile: $PROFILE_ID"
  else
    log "Using existing GNOME Terminal profile: $PROFILE_ID"
  fi

  # ── dconf path — NO trailing slash, that is what breaks writes ─────────────
  PBASE="/org/gnome/terminal/legacy/profiles:/:${PROFILE_ID}"

  # ── Profile name ───────────────────────────────────────────────────────────
  dconf write "${PBASE}/visible-name" "'xcad'" 2>/dev/null || true

  # ── Turn off system theme colours ─────────────────────────────────────────
  dconf write "${PBASE}/use-theme-colors" "false" 2>/dev/null || true

  # ── Background + foreground ────────────────────────────────────────────────
  dconf write "${PBASE}/background-color" "'#1A1A1A'" 2>/dev/null || true
  dconf write "${PBASE}/foreground-color" "'#F1F1F1'" 2>/dev/null || true

  # ── Bold ──────────────────────────────────────────────────────────────────
  dconf write "${PBASE}/bold-color" "'#F1F1F1'" 2>/dev/null || true
  dconf write "${PBASE}/bold-color-same-as-fg" "true" 2>/dev/null || true

  # ── Cursor ────────────────────────────────────────────────────────────────
  dconf write "${PBASE}/cursor-colors-set" "true" 2>/dev/null || true
  dconf write "${PBASE}/cursor-background-color" "'#FFFFFF'" 2>/dev/null || true
  dconf write "${PBASE}/cursor-foreground-color" "'#1A1A1A'" 2>/dev/null || true

  # ── Selection / highlight ─────────────────────────────────────────────────
  dconf write "${PBASE}/highlight-colors-set" "true" 2>/dev/null || true
  dconf write "${PBASE}/highlight-background-color" "'#FFFFFF'" 2>/dev/null || true
  dconf write "${PBASE}/highlight-foreground-color" "'#1A1A1A'" 2>/dev/null || true

  # ── 16-colour palette ─────────────────────────────────────────────────────
  # GVariant array of strings — must use @as type annotation
  # Slot order (ANSI): black red green yellow blue magenta cyan white
  #                    (normal 0-7, then bright 8-15)
  # Exact hex values from user's xcad colour spec:
  #   normal:  black=#121212  red=#A52AFF  green=#7129FF  yellow=#3D2AFF
  #            blue=#2B4FFF   purple=#2883FF  cyan=#28B9FF  white=#F1F1F1
  #   bright:  black=#666666  red=#BA5AFF  green=#905AFF  yellow=#685AFF
  #            blue=#5C78FF   purple=#5EA2FF  cyan=#5AC8FF  white=#FFFFFF
  dconf write "${PBASE}/palette" \
    "@as ['#121212','#A52AFF','#7129FF','#3D2AFF','#2B4FFF','#2883FF','#28B9FF','#F1F1F1','#666666','#BA5AFF','#905AFF','#685AFF','#5C78FF','#5EA2FF','#5AC8FF','#FFFFFF']" \
    2>/dev/null || true

  # ── Transparency off ──────────────────────────────────────────────────────
  dconf write "${PBASE}/use-transparent-background" "false" 2>/dev/null || true

  # ── Font: Hack Nerd Font Mono 14 ──────────────────────────────────────────
  dconf write "${PBASE}/use-system-font" "false" 2>/dev/null || true
  dconf write "${PBASE}/font" "'Hack Nerd Font Mono 14'" 2>/dev/null || true

  # ── Unlimited scrollback ──────────────────────────────────────────────────
  dconf write "${PBASE}/scrollback-unlimited" "true" 2>/dev/null || true

  # ── Verify at least one key wrote correctly ───────────────────────────────
  BG_CHECK="$(dconf read "${PBASE}/background-color" 2>/dev/null || true)"
  if [[ "$BG_CHECK" == *"1A1A1A"* ]]; then
    ok "xcad colour scheme applied to GNOME Terminal (verified)"
  else
    warn "dconf write may not have taken — try running: dconf write ${PBASE}/background-color \"'#1A1A1A'\""
  fi

  ok "Hack Nerd Font Mono 14 set as terminal font"

fi

# ── Write xcad scheme as reference file ───────────────────────────────────────
cat > "$HOME/.config/xcad-terminal-colors.sh" << 'DOTEOF'
# xcad terminal colour scheme — exact hex values
# Applied automatically to GNOME Terminal via dconf (section 19 of installer)
#
# background:    #1A1A1A    foreground:    #F1F1F1
# cursorColor:   #FFFFFF    selectionBg:   #FFFFFF
#
# normal colours:
#   black:       #121212    red:           #A52AFF
#   green:       #7129FF    yellow:        #3D2AFF
#   blue:        #2B4FFF    purple:        #2883FF
#   cyan:        #28B9FF    white:         #F1F1F1
#
# bright colours:
#   brightBlack: #666666    brightRed:     #BA5AFF
#   brightGreen: #905AFF    brightYellow:  #685AFF
#   brightBlue:  #5C78FF    brightPurple:  #5EA2FF
#   brightCyan:  #5AC8FF    brightWhite:   #FFFFFF
DOTEOF
ok ".config/xcad-terminal-colors.sh (reference)"

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${PURPLE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║   Christian Lempa Dotfiles — Installation Complete ✓     ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Programs installed:${NC}"
echo "  zsh · homebrew · hack nerd font · firacode nerd font"
echo "  starship (custom prompt) · warp · ghostty · helix"
echo "  docker · powershell · nvm · yadm"
echo "  ansible · bat · bottom · cmatrix · direnv · duf · dust · eza"
echo "  fzf · gh · glab · helm · httpie · hugo · iperf3 · jq · k3sup"
echo "  kubectx · kubectl · nmap · node · opentofu · packer · python3.13"
echo "  terraform · wakeonlan · wget · yamllint · yq · zoxide"
echo "  zsh-autocomplete · zsh-autosuggestions"
echo ""
echo -e "${CYAN}Dotfiles written:${NC}"
echo "  ~/.hushlogin"
echo "  ~/.ansible.cfg  ~/.ansible/clcreative-home-inventory"
echo "  ~/.zshenv  ~/.zshrc"
echo "  ~/.zsh/{aliases,functions,nvm,wsl2fix,starship}.zsh"
echo "  ~/.config/starship.toml          (custom prompt)"
echo "  ~/.config/goto"
echo "  ~/.config/ghostty/config + themes/xcad2k-{dark,light}"
echo "  ~/.config/helix/config.toml + themes/christian.toml"
echo "  ~/.config/neofetch/config.conf + thedigitallife.txt"
echo "  ~/.config/oh-my-posh/themes/christian.omp.json"
echo "  ~/.config/xcad-terminal-colors.sh (colour reference)"
echo "  ~/.config/yadm/bootstrap"
echo "  ~/.warp/themes/xcad2k-{dark,light}.yml"
echo "  ~/.warp/workflows/ (all 7)"
echo "  ~/.ssh/config"
echo ""
echo -e "${CYAN}System configuration applied:${NC}"
echo "  GNOME dark theme (prefer-dark + Yaru-dark/Adwaita-dark)"
echo "  Mr. Robot wallpaper → ~/Pictures/Wallpapers/mr-robot-wallpaper.png"
echo "  GNOME Terminal → xcad colour scheme + Hack Nerd Font Mono 14"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. exec zsh                         (start Zsh right now)"
echo "  2. Warp → Settings → Appearance → Theme → xcad2k-dark"
echo "  3. neofetch                          (see the TheDigitalLife logo)"
echo "  4. Log out and back in if wallpaper/theme need a refresh"
echo ""
