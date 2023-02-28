function gpa --wraps='git pull --all' --description 'alias gpa=git pull --all'
  git pull --all $argv; 
end
