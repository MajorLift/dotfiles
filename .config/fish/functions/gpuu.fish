function gpuu --wraps='git pull --set-upstream origin (git branch --show-current)' --description 'alias gpuu=git pull --set-upstream origin $(git branch --show-current)'
  git pull --set-upstream $argv (git branch --show-current); 
end
