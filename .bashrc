#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

### Niri-Install Additions
export LANG=en_AU.UTF-8
export GDK_BACKEND=wayland
export GTK_THEME="Ant-Dracula"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-niri}"
export MANPAGER="sh -c 'awk '\''{ gsub(/\x1B\[[0-9;]*m/, \"\", \$0); gsub(/.\x08/, \"\", \$0); print }'\'' | bat -p -lman'"
export EDITOR="hx"
export VISUAL="$EDITOR"
export TERMINAL=/usr/bin/kitty

# Paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"
export PATH="$HOME/.choosenim/current/bin:$PATH"

# Fzf
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git "
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always -n --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --icons=always --tree --color=always {} | head -200'"

# Zoxide
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

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

# Dracula prompt for interactive shells
__dracula_prompt() {
    local exit_status=$?
    local reset="\[\e[0m\]"
    local purple="\[\e[38;2;189;147;249m\]"
    local pink="\[\e[38;2;255;121;198m\]"
    local green="\[\e[38;2;80;250;123m\]"
    local yellow="\[\e[38;2;241;250;140m\]"
    local red="\[\e[38;2;255;85;85m\]"
    local status_color=$green
    local prompt_symbol="$"

    [[ $exit_status -ne 0 ]] && status_color=$red
    [[ $EUID -eq 0 ]] && prompt_symbol="#"

    local branch=""
    if command -v git >/dev/null 2>&1; then
        local ref
        ref=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [[ -n $ref ]]; then
            local dirty=""
            if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
                dirty="*"
            fi
            branch=" ${yellow}(${ref}${dirty})"
        fi
    fi

    local user_color=$pink
    [[ $EUID -eq 0 ]] && user_color=$red

    PS1="${status_color}[${user_color}\\u${reset}@${purple}\\h${status_color}] ${green}\\w${branch}${reset}\n${status_color}${prompt_symbol} ${reset}"
    return 0
}
if [[ $PROMPT_COMMAND != *__dracula_prompt* ]]; then
    PROMPT_COMMAND="__dracula_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Fetch
command -v nymph >/dev/null 2>&1 && nymph
