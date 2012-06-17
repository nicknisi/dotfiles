autoload colors && colors

git_branch() {
  echo $(/usr/bin/git symbolic-ref HEAD 2>/dev/null | awk -F/ {'print $NF'})
}

git_dirty() {
  st=$(/usr/bin/git status 2>/dev/null | tail -n 1)
  if [[ $st == "" ]]
  then
    echo ""
  else
    if [[ $st == "nothing to commit (working directory clean)" ]]
    then
      echo "%{$fg_bold[green]%}✔ $(git_prompt_info)%{$reset_color%}"
    else
      echo "%{$fg_bold[red]%}✘ $(git_prompt_info)%{$reset_color%}"
    fi
  fi
}

unpushed() {
  /usr/bin/git cherry -v @{upstream} 2>/dev/null
}

need_push() {
  if [[ $(unpushed) == "" ]]
  then
    echo " "
  else
    echo " %{$fg_bold[magenta]%}☁%{$reset_color%} "
  fi
}

directory_name(){
  echo "%{$fg_bold[cyan]%}%1/%\/%{$reset_color%}"
}

export PROMPT=$'in $(directory_name) $(git_dirty)$(need_push)\n➜ '
export RPROMPT=$'$(git_dirty)$(need_push)'
