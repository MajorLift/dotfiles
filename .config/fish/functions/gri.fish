function gri --wraps='git rebase -i master' --description 'alias gri=git rebase -i master'
  git rebase -i $argv; 
end
