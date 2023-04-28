target_branch=main
target_branch=$(echo $(git show-ref -s remotes/origin/${target_branch}))
echo $target_branch