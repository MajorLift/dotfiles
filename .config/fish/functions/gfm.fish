function gfm
	set -u GIT_BRANCH_CURRENT (git branch --show-current) && git stash && gc $argv && gpa && gc (echo $GIT_BRANCH_CURRENT) && set -e GIT_BRANCH_CURRENT;
end
