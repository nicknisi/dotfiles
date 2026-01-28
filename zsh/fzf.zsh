fzf-append-history() {
  local selected
  # 1. fc -r -n -l 1 : 获取所有历史，反向排序（最新的在最前），不带行号
  # 2. awk '!seen[$0]++' : 核心去重逻辑。保留遇到的"第一条"（也就是最新的那条），删除后面重复的旧记录。
  # 3. --scheme=history : (Fzf >= 0.27) 专为历史记录优化的打分算法，优先匹配最近的记录。
  # 4. --tiebreak=index : 如果分数相同，按照输入列表的顺序（也就是时间倒序）排列。
  
  selected=$(fc -r -n -l 1 | awk '!seen[$0]++' | fzf \
    --scheme=history \
    --tiebreak=index \
    --height=40% \
    --layout=reverse \
    --prompt="Append Cmd> " \
    --bind 'ctrl-r:toggle-sort' \
    --header "Ctrl-R: Toggle Sort (Time vs Match)")

  if [[ -n "$selected" ]]; then
    LBUFFER="${LBUFFER}${selected}"
  fi
  zle redisplay
}

zle -N fzf-append-history
bindkey '^E' fzf-append-history
