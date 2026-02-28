# ~/.zshrc - niri-install

# Exit if non-interactive
[[ -o interactive ]] || return

# Locale and desktop defaults
export LANG=en_AU.UTF-8
export GDK_BACKEND=wayland
export GTK_THEME="Ant-Dracula"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-niri}"
export MANPAGER="sh -c 'awk '\''{ gsub(/\\x1B\\[[0-9;]*m/, \"\", $0); gsub(/.\\x08/, \"\", $0); print }'\'' | bat -p -lman'"
export EDITOR="hx"
export VISUAL="$EDITOR"
export TERMINAL=/usr/bin/kitty

# Paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"
export PATH="$HOME/.choosenim/current/bin:$PATH"

# Completion
autoload -Uz compinit
compinit -C
zmodload -i zsh/complist
bindkey '^I' expand-or-complete
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Inline suggestions (fish-style)
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
fi

# History
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=50000
setopt inc_append_history share_history hist_ignore_dups hist_ignore_space

# Quality of life
setopt autocd nocaseglob no_beep

# Fzf
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
export FZF_ALT_C_OPTS="--preview 'eza --icons=always --tree --color=always {} | head -200'"

# Zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# bat
export BAT_THEME="Dracula"
alias cat='bat --style=plain'
alias ccat='bat --style=full'

# Eza
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias lt='eza --tree --level=2 --icons'
alias l='eza -lah --icons --git'

# Ripgrep with fzf for content search
alias rgf='rg --line-number --no-heading --color=always . | fzf --ansi'
alias grep='grep --color=auto'

# Helix
alias hx='helix'

# Prompt (16-color friendly)
autoload -Uz colors vcs_info
colors
setopt prompt_subst
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats '%b%u'

_dracula_precmd() {
  local exit_status=$?
  vcs_info
  local status_color="%F{green}"
  [[ $exit_status -ne 0 ]] && status_color="%F{red}"

  local user_color="%F{magenta}"
  [[ $EUID -eq 0 ]] && user_color="%F{red}"

  local branch=""
  [[ -n ${vcs_info_msg_0_:-} ]] && branch=" %F{yellow}(${vcs_info_msg_0_})%f"

  PROMPT="${status_color}[${user_color}%n%f@%F{blue}%m${status_color}] %F{cyan}%~${branch}%f"$'\n'"${status_color}$ %f"
}
precmd_functions+=(_dracula_precmd)

# Fetch
command -v nymph >/dev/null 2>&1 && nymph
