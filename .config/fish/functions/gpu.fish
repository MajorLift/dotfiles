function gpu --description 'pulls branch from upstream and updates origin'
  git pull upstream $argv && git push origin --set-upstream $argv; 
end
