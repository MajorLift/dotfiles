#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y-%m-%d)"

# Files to skip when symlinking
SKIP_FILES=(.git .gitignore .gitmodules setup.sh)

# ============================================
# ===  1. Prompt for secrets / fill placeholders  ===
# ============================================

prompt_placeholder() {
    local file="$1" placeholder="$2" description="$3" default="${4:-}"
    local current
    current=$(grep -o "<${placeholder}>" "$DOTFILES_DIR/$file" 2>/dev/null || true)
    if [ -z "$current" ]; then
        echo "  [skip] $description — already set in $file"
        return
    fi

    local prompt="  $description"
    [ -n "$default" ] && prompt="$prompt [$default]"
    prompt="$prompt: "

    read -rp "$prompt" value
    value="${value:-$default}"

    if [ -z "$value" ]; then
        echo "  [skip] No value provided for $description"
        return
    fi

    # Escape sed special characters in the value
    local escaped
    escaped=$(printf '%s\n' "$value" | sed 's/[&/\]/\\&/g')
    sed -i '' "s/<${placeholder}>/${escaped}/g" "$DOTFILES_DIR/$file"
    echo "  [done] Replaced <$placeholder> in $file"
}

echo "=== Dotfiles Setup ==="
echo ""
echo "Step 1: Fill in secrets and personal info"
echo "  (Press Enter to skip any prompt)"
echo ""

prompt_placeholder ".gitconfig" "NAME" "Git user name"
prompt_placeholder ".gitconfig" "EMAIL" "Git email" "majorlift@users.noreply.github.com"
prompt_placeholder ".gitconfig" "GPG_SIGNING_KEY" "GPG signing key ID"

# If no GPG key was provided and placeholder remains, disable gpgsign
if grep -q '<GPG_SIGNING_KEY>' "$DOTFILES_DIR/.gitconfig" 2>/dev/null; then
    sed -i '' 's/	signingkey = <GPG_SIGNING_KEY>//' "$DOTFILES_DIR/.gitconfig"
    sed -i '' 's/	gpgsign = true/	gpgsign = false/' "$DOTFILES_DIR/.gitconfig"
    echo "  [info] GPG signing disabled (no key provided)"
fi

# GH_TOKEN: try gh auth token first, then prompt
gh_token_default=""
if command -v gh &>/dev/null; then
    gh_token_default=$(gh auth token 2>/dev/null || true)
fi
if [ -n "$gh_token_default" ]; then
    echo ""
    echo "  Found GitHub token via 'gh auth token'."
    read -rp "  Use it? [Y/n]: " use_gh
    if [[ "${use_gh:-Y}" =~ ^[Yy]$ ]]; then
        prompt_value="$gh_token_default"
        escaped=$(printf '%s\n' "$prompt_value" | sed 's/[&/\]/\\&/g')
        sed -i '' "s/<GH_TOKEN>/${escaped}/g" "$DOTFILES_DIR/.config/fish/config.fish"
        echo "  [done] Replaced <GH_TOKEN> in .config/fish/config.fish"
    else
        prompt_placeholder ".config/fish/config.fish" "GH_TOKEN" "GitHub personal access token"
    fi
else
    prompt_placeholder ".config/fish/config.fish" "GH_TOKEN" "GitHub personal access token"
fi

# ============================================
# ===  2. Symlink dotfiles into $HOME     ===
# ============================================

echo ""
echo "Step 2: Symlink dotfiles into \$HOME"
echo ""

cd "$DOTFILES_DIR"
files=$(git ls-files | while read -r f; do
    skip=false
    for s in "${SKIP_FILES[@]}"; do
        if [ "$f" = "$s" ] || [ "${f%%/*}" = "$s" ]; then
            skip=true
            break
        fi
    done
    $skip || echo "$f"
done)

backed_up=false
while IFS= read -r file; do
    target="$HOME/$file"
    source="$DOTFILES_DIR/$file"

    # Skip submodule directories (git ls-files lists them as single entries)
    if [ -d "$source" ]; then
        continue
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    # If target exists and is not already a symlink to our dotfiles
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        mv "$target" "$BACKUP_DIR/$file"
        if [ "$backed_up" = false ]; then
            echo "  Backing up existing files to $BACKUP_DIR/"
            backed_up=true
        fi
    fi

    # Create symlink (overwrite existing symlinks)
    ln -sf "$source" "$target"
done <<< "$files"

echo "  [done] Symlinks created"
if [ "$backed_up" = true ]; then
    echo "  [info] Backed-up files are in $BACKUP_DIR/"
fi

# ============================================
# ===  3. Install dependencies (optional)  ===
# ============================================

echo ""
read -rp "Step 3: Install dependencies? [y/N]: " install_deps
if [[ "${install_deps:-N}" =~ ^[Yy]$ ]]; then

    # Homebrew
    if ! command -v brew &>/dev/null; then
        echo "  Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$($HOME/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
    else
        echo "  [skip] Homebrew already installed"
    fi

    # Fish shell
    if ! command -v fish &>/dev/null; then
        echo "  Installing fish shell..."
        brew install fish
    else
        echo "  [skip] Fish already installed"
    fi

    # Fisher + plugins
    if command -v fish &>/dev/null; then
        if ! fish -c "type -q fisher" 2>/dev/null; then
            echo "  Installing Fisher plugin manager..."
            fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
        else
            echo "  [skip] Fisher already installed"
        fi
        if [ -f "$DOTFILES_DIR/.config/fish/fish_plugins" ]; then
            echo "  Installing Fish plugins from fish_plugins..."
            fish -c "fisher update" 2>/dev/null || true
        fi
    fi

    # TPM (Tmux Plugin Manager)
    tpm_dir="$HOME/.config/tmux/plugins/tpm"
    if [ ! -d "$tpm_dir" ]; then
        echo "  Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    else
        echo "  [skip] TPM already installed"
    fi
    # Install tmux plugins
    if [ -x "$tpm_dir/bin/install_plugins" ]; then
        echo "  Installing tmux plugins..."
        "$tpm_dir/bin/install_plugins" || true
    fi

    # vim-plug for vim
    if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
        echo "  Installing vim-plug for vim..."
        curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    else
        echo "  [skip] vim-plug (vim) already installed"
    fi

    # vim-plug for neovim
    if [ ! -f "$HOME/.config/nvim/autoload/plug.vim" ]; then
        echo "  Installing vim-plug for neovim..."
        curl -fLo "$HOME/.config/nvim/autoload/plug.vim" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    else
        echo "  [skip] vim-plug (nvim) already installed"
    fi

    # Install vim/nvim plugins
    echo "  Installing vim plugins..."
    vim +PlugInstall +qall 2>/dev/null || true
    if command -v nvim &>/dev/null; then
        nvim +PlugInstall +qall 2>/dev/null || true
    fi

    # rbenv
    if ! command -v rbenv &>/dev/null; then
        echo "  Installing rbenv..."
        brew install rbenv
    else
        echo "  [skip] rbenv already installed"
    fi

    # nvm (via fish-nvm plugin, no separate install needed)
    echo "  [info] nvm is managed via fish-nvm plugin"

    echo ""
    echo "  [done] Dependencies installed"
fi

# ============================================
# ===  4. Set fish as default shell        ===
# ============================================

current_shell=$(basename "$SHELL")
if [ "$current_shell" != "fish" ]; then
    echo ""
    read -rp "Step 4: Set fish as default shell? [y/N]: " set_fish
    if [[ "${set_fish:-N}" =~ ^[Yy]$ ]]; then
        fish_path=$(command -v fish)
        if ! grep -q "$fish_path" /etc/shells; then
            echo "  Adding $fish_path to /etc/shells (requires sudo)..."
            echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
        fi
        chsh -s "$fish_path"
        echo "  [done] Default shell set to fish"
    fi
else
    echo ""
    echo "  [skip] Fish is already your default shell"
fi

echo ""
echo "=== Setup complete ==="
echo "  Open a new terminal to pick up changes."
