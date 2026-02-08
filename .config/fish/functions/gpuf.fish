function gpuf --wraps='git push upstream --force' --description 'alias gpuf=git push upstream --force $1'
  git push upstream (git branch --show-current) --force; 
end
