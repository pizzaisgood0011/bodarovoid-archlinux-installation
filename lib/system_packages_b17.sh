#!/usr/bin/env bash
# B17 package planning. AUR selections are exported, never executed as root.
SYSTEM_RECOMMENDED=(linux-headers base-devel git nano curl wget man-db man-pages)
SYSTEM_OPTIONAL=(openssh htop btop neovim tmux unzip zip rsync bash-completion reflector)
SYSTEM_SELECTED=("${SYSTEM_RECOMMENDED[@]}")
OFFICIAL_SEARCH_SELECTED=()
AUR_SEARCH_SELECTED=()

b17_valid_name() { [[ $1 =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]; }
b17_contains() { local target=$1 item; shift; for item in "$@"; do [[ $item == "$target" ]] && return 0; done; return 1; }
b17_mark_changed() {
  B109_FINGERPRINT=''; B109_SNAPSHOT=''; B109_MODE=''
  printf '\nPackage selections changed. Repeat safety approvals before installation.\n'
}
b17_official_packages() { printf '%s\n' "${SYSTEM_SELECTED[@]}" "${OFFICIAL_SEARCH_SELECTED[@]}" | sed '/^$/d' | sort -u; }
b17_validate() {
  local pkg
  for pkg in "${SYSTEM_SELECTED[@]}"; do
    b17_valid_name "$pkg" || return 1
    b17_contains "$pkg" "${SYSTEM_RECOMMENDED[@]}" "${SYSTEM_OPTIONAL[@]}" || return 1
  done
  for pkg in "${OFFICIAL_SEARCH_SELECTED[@]}" "${AUR_SEARCH_SELECTED[@]}"; do b17_valid_name "$pkg" || return 1; done
}
b17_show() {
  printf 'SYSTEM RECOMMENDED (selected by default, removable):\n'
  printf '  %s\n' "${SYSTEM_SELECTED[*]:-(none)}"
  printf 'OFFICIAL SEARCH ADDITIONS:\n  %s\n' "${OFFICIAL_SEARCH_SELECTED[*]:-(none)}"
  printf 'AUR REQUESTS (automatically built as unprivileged user during install):\n  %s\n' "${AUR_SEARCH_SELECTED[*]:-(none)}"
}
b17_toggle_catalog() {
  local result pkg csv
  local -a catalog=("${SYSTEM_RECOMMENDED[@]}" "${SYSTEM_OPTIONAL[@]}") next=()
  csv=$(IFS=,; echo "${SYSTEM_SELECTED[*]}")
  result=$(printf '%s\n' "${catalog[@]}" | gum choose --no-limit --selected "$csv" --header 'System packages: Space toggle, Enter save' --height 20) || return 0
  while IFS= read -r pkg; do [[ -z $pkg ]] || next+=("$pkg"); done <<< "$result"
  SYSTEM_SELECTED=("${next[@]}")
  b17_mark_changed
}
# Live search uses fzf's change:reload hook. Search is executed for each edit;
# remote requests have a short timeout and are limited to the first 60 matches.
b17_search() {
  local source=$1 result name helper
  if ! command -v fzf >/dev/null; then
    ui_note 'Live search requires fzf. Install with: pacman -S --needed fzf curl jq'
    ui_pause; return 0
  fi
  if [[ $source == AUR ]] && { ! command -v curl >/dev/null || ! command -v jq >/dev/null; }; then
    ui_note 'AUR live search requires curl and jq.'; ui_pause; return 0
  fi
  helper="$BASE_DIR/lib/live_search_b18.sh"
  # fzf escapes {q} as one shell argument; helper receives it as $2.
  result=$(fzf --disabled --height=85% --layout=reverse \
    --prompt="$source search > " \
    --header='Type 2+ characters to search live. Enter adds package; Esc returns.' \
    --bind "start:reload:bash '$helper' '$source' {q}" \
    --bind "change:reload:sleep 0.25; bash '$helper' '$source' {q}" \
    < /dev/null) || return 0
  name=${result%%$'\n'*}
  b17_valid_name "$name" || { ui_note 'Invalid package name.'; ui_pause; return 0; }
  if [[ $source == Official ]]; then
    b17_contains "$name" "${OFFICIAL_SEARCH_SELECTED[@]}" || OFFICIAL_SEARCH_SELECTED+=("$name")
  else
    b17_contains "$name" "${AUR_SEARCH_SELECTED[@]}" || AUR_SEARCH_SELECTED+=("$name")
  fi
  b17_mark_changed
}
b17_remove() {
  local source=$1 pkg result
  local -a current=() next=()
  if [[ $source == Official ]]; then current=("${OFFICIAL_SEARCH_SELECTED[@]}"); else current=("${AUR_SEARCH_SELECTED[@]}"); fi
  ((${#current[@]})) || return 0
  result=$(printf '%s\n' "${current[@]}" | gum choose --header "Remove a $source package") || return 0
  for pkg in "${current[@]}"; do [[ $pkg == "$result" ]] || next+=("$pkg"); done
  if [[ $source == Official ]]; then OFFICIAL_SEARCH_SELECTED=("${next[@]}"); else AUR_SEARCH_SELECTED=("${next[@]}"); fi
  b17_mark_changed
}
b17_menu() {
  local choice
  while true; do
    ui_heading 'B18 — Live Package Search + AUR Builds'
    b17_show
    printf '\nOfficial search uses synchronized pacman repository indexes. AUR uses live HTTPS search.\n'
    printf 'AUR builds run as an unprivileged user; review PKGBUILDs before selecting.\n\n'
    choice=$(ui_choose 'Package actions' 'Customize recommended / optional' 'Search official repositories' 'Search AUR online' 'Remove official addition' 'Remove AUR request' 'Reset recommended defaults' 'Back') || return 0
    case "$choice" in
      'Customize recommended / optional') b17_toggle_catalog ;;
      'Search official repositories') b17_search Official ;;
      'Search AUR online') b17_search AUR ;;
      'Remove official addition') b17_remove Official ;;
      'Remove AUR request') b17_remove AUR ;;
      'Reset recommended defaults') SYSTEM_SELECTED=("${SYSTEM_RECOMMENDED[@]}"); b17_mark_changed ;;
      Back) return 0 ;;
    esac
  done
}
