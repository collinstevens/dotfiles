#!/bin/bash
command -v jq >/dev/null 2>&1 || exit 0

fields=$(jq -r '[
	(.model.display_name // .model.id // ""),
	(.effort.level // "default"),
	(if .fast_mode then "fast" else "" end),
	(.permissionMode // .permission_mode // ""),
	(.context_window.total_input_tokens // 0 | round),
	(.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else 100 - . | round end),
	(.rate_limits.seven_day.used_percentage // "" | if . == "" then "" else 100 - . | round end),
	(.pr.number // ""),
	(.pr.url // ""),
	(.workspace.current_dir // .cwd // ""),
	(.workspace.repo.name // (.workspace.project_dir // "" | if . == "" then "" else split("/") | last end))
] | map(tostring) | join("\u001f")')

IFS=$'\x1f' read -r model effort fast permission_mode tokens_used five_hour_left weekly_left pr_number pr_url work_dir project_name <<< "$fields"

esc=$'\e'
reset="${esc}[0m"
dim="${esc}[2m"
underline="${esc}[4m"
yellow="${esc}[38;2;246;226;183m"
peach="${esc}[38;2;242;181;144m"
red="${esc}[38;2;233;144;169m"
blue="${esc}[38;2;143;179;239m"
mauve="${esc}[38;2;200;169;238m"
green="${esc}[38;2;171;223;167m"

segments=()

if [ -n "$model" ]; then
	segment="$model $effort"
	[ -n "$fast" ] && segment="$segment fast"
	segments+=("${yellow}${segment}${reset}")
fi

[ -n "$permission_mode" ] && segments+=("${mauve}${permission_mode}${reset}")
if [ "$tokens_used" -ge 1000 ]; then
	tokens_used_hundredths=$(( (tokens_used + 5) / 10 ))
	printf -v tokens_used_text '%d.%02dK used' "$((tokens_used_hundredths / 100))" "$((tokens_used_hundredths % 100))"
else
	tokens_used_text="${tokens_used} used"
fi
segments+=("${peach}${tokens_used_text}${reset}")
[ -n "$five_hour_left" ] && segments+=("${red}5h ${five_hour_left}% left${reset}")
[ -n "$weekly_left" ] && segments+=("${red}weekly ${weekly_left}% left${reset}")

if [ -n "$pr_number" ]; then
	pr_text="${blue}${underline}PR #${pr_number}${reset}"
	if [ -n "$pr_url" ]; then
		pr_text="${esc}]8;;${pr_url}${esc}\\${pr_text}${esc}]8;;${esc}\\"
	fi
	segments+=("$pr_text")
fi

if [ -n "$work_dir" ]; then
	branch=$(git -C "$work_dir" branch --show-current 2>/dev/null)
	[ -n "$branch" ] && segments+=("${blue}${branch}${reset}")
fi

[ -n "$project_name" ] && segments+=("${green}${project_name}${reset}")

separator="${dim} · ${reset}"
output=""
for segment in "${segments[@]}"; do
	[ -n "$output" ] && output="${output}${separator}"
	output="${output}${segment}"
done
printf '%s' "$output"
