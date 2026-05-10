#!/bin/bash

declare -A screen_active_desktop
declare -A screen_label
declare -A desktop_state

build_screen_label_map() {
	screen_label=()
	local entries=() line head_id xoff
	while IFS= read -r line; do
		if [[ $line =~ head\ #([0-9]+):\ [0-9]+x[0-9]+\ @\ (-?[0-9]+),(-?[0-9]+) ]]; then
			head_id="${BASH_REMATCH[1]}"
			xoff="${BASH_REMATCH[2]}"
			entries+=("$xoff:$head_id")
		fi
	done < <(xdpyinfo -ext XINERAMA 2>/dev/null)

	if [[ ${#entries[@]} -eq 0 ]]; then
		return
	fi

	local sorted pos=1 entry id
	mapfile -t sorted < <(printf '%s\n' "${entries[@]}" | sort -n)
	for entry in "${sorted[@]}"; do
		id="${entry#*:}"
		screen_label[$id]=$pos
		((pos++))
	done
}

label_for() {
	local id="$1"
	if [[ -n "${screen_label[$id]}" ]]; then
		echo "${screen_label[$id]}"
	else
		echo "$((id + 1))"
	fi
}

build_screen_label_map
_iter=0

$HOME/go/bin/xmonad-log | while IFS= read -r line; do
	if ((_iter % 20 == 0)); then
		build_screen_label_map
	fi
	((_iter++))

	temp_line="$line"
	current_focused_screen=""
	screen_active_desktop=()
	desktop_state=()

	if [[ $line =~ %\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\} ]]; then
		current_focused_screen="${BASH_REMATCH[1]}"
	fi

	while [[ $temp_line =~ ([^%]*)%\{F(#[0-9a-fA-F]+)\}\ ([0-9]+)_([0-9]+)\ %\{F-\}(.*) ]]; do
		color="${BASH_REMATCH[2]}"
		screen_id="${BASH_REMATCH[3]}"
		desktop_id="${BASH_REMATCH[4]}"
		case "$color" in
			"#2266d0")
				screen_active_desktop[$screen_id]=$desktop_id
				desktop_state[${screen_id}_${desktop_id}]=current
				;;
			"#83a598")
				screen_active_desktop[$screen_id]=$desktop_id
				desktop_state[${screen_id}_${desktop_id}]=visible
				;;
			"#fb4934")
				desktop_state[${screen_id}_${desktop_id}]=urgent
				;;
			"#fabd2f")
				desktop_state[${screen_id}_${desktop_id}]=occupied
				;;
			*)
				:
				;;
		esac
		temp_line="${BASH_REMATCH[1]}${BASH_REMATCH[5]}"
	done

	screens=()
	temp_line="$line"
	while [[ $temp_line =~ ([0-9]+)_([0-9]+) ]]; do
		screen_id="${BASH_REMATCH[1]}"
		screens+=("$screen_id")
		temp_line="${temp_line/${BASH_REMATCH[0]}/_PROCESSED_}"
	done

	if [[ ${#screens[@]} -gt 0 ]]; then
		mapfile -t unique_screens < <(printf '%s\n' "${screens[@]}" | sort -nu)
	else
		unique_screens=(0 1)
	fi

	sortable=()
	for s in "${unique_screens[@]}"; do
		sortable+=("$(label_for "$s"):$s")
	done
	mapfile -t sorted_pairs < <(printf '%s\n' "${sortable[@]}" | sort -n)
	sorted_screens=()
	for p in "${sorted_pairs[@]}"; do
		sorted_screens+=("${p#*:}")
	done

	display=""
	for i in "${!sorted_screens[@]}"; do
		screen="${sorted_screens[i]}"
		screen_num="$(label_for "$screen")"

		if [[ -n "$SCREEN_LABEL" && "$screen_num" != "$SCREEN_LABEL" ]]; then
			continue
		fi

		if [[ -z "$SCREEN_LABEL" ]]; then
			if [[ "$screen" == "$current_focused_screen" ]]; then
				display+="%{F#87ceeb}Screen $screen_num:%{F-} "
			else
				display+="Screen $screen_num: "
			fi
		fi

		for desktop in {1..5}; do
			state="${desktop_state[${screen}_${desktop}]}"
			if [[ "${screen_active_desktop[$screen]}" == "$desktop" ]]; then
				display+="%{F#ffe500}$desktop%{F-}"
			elif [[ "$state" == "urgent" ]]; then
				display+="%{F#fb4934}$desktop%{F-}"
			elif [[ "$state" == "occupied" ]]; then
				display+="%{F#ffffff}$desktop%{F-}"
			else
				display+="%{F#555555}$desktop%{F-}"
			fi
			if [[ $desktop -lt 5 ]]; then
				display+=" "
			fi
		done

		if [[ -z "$SCREEN_LABEL" && $i -lt $((${#sorted_screens[@]} - 1)) ]]; then
			display+=" | "
		fi
	done

	echo "$display"
done
