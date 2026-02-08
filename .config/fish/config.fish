eval ($HOME/homebrew/bin/brew shellenv)
tirith init | source

# Added by `rbenv init` on Tue Sep 10 11:30:39 EDT 2024
status --is-interactive; and rbenv init - --no-rehash fish | source

set -gx GH_TOKEN "<GH_TOKEN>"
set -gx PATH $HOME/.opencode/bin $PATH

# Ensure proper terminal for tmux
if set -q TMUX
    set -gx TERM tmux-256color
end

# Editor fallback
if not set -q EDITOR
    set -gx EDITOR vim
end
