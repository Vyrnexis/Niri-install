# Configure Fish for the Dracula-themed Niri desktop.

set -gx EDITOR hx
set -gx VISUAL $EDITOR
set -gx TERMINAL kitty
set -gx BAT_THEME Dracula
set -gx EZA_CONFIG_DIR "$HOME/.config/eza"

fish_add_path --global --move \
    "$HOME/.local/bin" \
    "$HOME/.nimble/bin" \
    "$HOME/.choosenim/current/bin"

status is-interactive; or return

# Dracula syntax and completion colors.
set -g fish_color_normal f8f8f2
set -g fish_color_command 50fa7b
set -g fish_color_keyword ff79c6
set -g fish_color_quote f1fa8c
set -g fish_color_redirection 8be9fd
set -g fish_color_end 50fa7b
set -g fish_color_error ff5555
set -g fish_color_param bd93f9
set -g fish_color_option 8be9fd
set -g fish_color_comment 6272a4
set -g fish_color_operator ff79c6
set -g fish_color_escape ff79c6
set -g fish_color_autosuggestion 6272a4
set -g fish_color_selection --background=44475a
set -g fish_color_search_match --background=44475a
set -g fish_pager_color_progress 6272a4
set -g fish_pager_color_prefix 8be9fd --bold
set -g fish_pager_color_completion f8f8f2
set -g fish_pager_color_description 6272a4

set -gx FZF_DEFAULT_COMMAND "fd --type f --hidden --exclude .git --strip-cwd-prefix"
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_ALT_C_COMMAND "fd --type d --hidden --exclude .git --strip-cwd-prefix"
set -gx FZF_DEFAULT_OPTS "--height=60% --layout=reverse --border=rounded --preview-window=right:65%:wrap:border-left"
set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --style=plain,numbers --line-range=:500 -- {}'"
set -gx FZF_ALT_C_OPTS "--preview 'eza --icons=always --tree --color=always {} | head -200'"

if command -q fzf
    fzf --fish | source
end

if command -q zoxide
    zoxide init fish | source
end

if command -q bat
    set -gx MANPAGER "bat -l man -p"
end

abbr --add --global ls 'eza --icons'
abbr --add --global ll 'eza -lh --icons --git'
abbr --add --global la 'eza -lah --icons --git'
abbr --add --global lt 'eza --tree --level=2 --icons'
abbr --add --global ccat 'bat --style=full'
abbr --add --global rgf 'rg --line-number --no-heading --color=always . | fzf --ansi'

set -g __fish_git_prompt_showdirtystate yes
set -g __fish_git_prompt_showuntrackedfiles yes
set -g __fish_git_prompt_color_branch f1fa8c
set -g __fish_git_prompt_color_dirtystate ff5555
set -g __fish_git_prompt_color_untracked ff79c6

# Open Superfile and change to its final directory on exit.
function sf
    set -l last_dir (command spf --print-last-dir $argv)
    if test -d "$last_dir"; and test "$last_dir" != "$PWD"
        builtin cd -- "$last_dir"
    end
end

# Render a compact two-line Dracula prompt with Git state.
function fish_prompt
    set -l last_status $status
    set -l status_color 50fa7b
    set -l prompt_symbol '$'

    if test $last_status -ne 0
        set status_color ff5555
    end
    if fish_is_root_user
        set status_color ff5555
        set prompt_symbol '#'
    end

    set_color $status_color
    printf '['
    set_color ff79c6
    printf '%s' "$USER"
    set_color bd93f9
    printf '@%s' (prompt_hostname)
    set_color $status_color
    printf '] '
    set_color 8be9fd
    printf '%s' (prompt_pwd)
    fish_vcs_prompt
    set_color normal
    printf '\n'
    set_color $status_color
    printf '%s ' $prompt_symbol
    set_color normal
end

# Show long command duration on the right side of the prompt.
function fish_right_prompt
    if test $CMD_DURATION -ge 1000
        set_color 6272a4
        printf '%.1fs' (math "$CMD_DURATION / 1000")
        set_color normal
    end
end

# Show the system summary once for each terminal process tree.
function fish_greeting
    if not set -q __nymph_greeting_shown
        set -gx __nymph_greeting_shown 1
        if command -q nymph
            nymph
        else if command -q fastfetch
            fastfetch
        end
    end
end
