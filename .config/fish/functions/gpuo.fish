function gpuo --wraps='git pull upstream main && git push origin main' --description 'alias gpuo=git pull upstream $1 && git push origin $1'
  git pull upstream (git branch --show-current) && git push origin (git branch --show-current); 
end
