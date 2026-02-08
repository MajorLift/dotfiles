function gpou --wraps='git push origin --set-upstream (git branch --show-current)' --description 'alias gpou=git push origin --set-upstream (git branch --show-current)'
  gpo --set-upstream (git branch --show-current) $argv; 
end
