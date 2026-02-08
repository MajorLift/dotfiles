function gbp
	git branch --set-upstream-to=$argv/(git branch --show-current) && git push $argv; 
end
