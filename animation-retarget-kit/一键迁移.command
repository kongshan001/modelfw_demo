#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

if [[ ! -f config.env ]]; then
	osascript -e 'display dialog "请先在终端运行 ./setup.sh 配置 Blender。" buttons {"好"}'
	exit 1
fi

TARGET="$(osascript -e 'POSIX path of (choose file with prompt "选择目标人形模型（FBX / GLB）")' 2>/dev/null || true)"
if [[ -z "${TARGET}" ]]; then exit 0; fi

case "${TARGET##*.}" in
	fbx|FBX|glb|GLB) ;;
	*)
		osascript -e 'display dialog "只支持 FBX / GLB。" buttons {"好"}'
		exit 1
		;;
esac

CLIP_CHOICE="$(osascript -e 'choose from list {"SambaDance (舞步)","Run (跑步)","Walk (走路)","Idle (待机)"} with prompt "选择要迁移的动作" default items {"SambaDance (舞步)"}' 2>/dev/null || true)"
if [[ -z "${CLIP_CHOICE}" || "${CLIP_CHOICE}" == "false" ]]; then exit 0; fi

FORMAT="$(osascript -e 'choose from list {"GLB (推荐)","FBX"} with prompt "输出格式" default items {"GLB (推荐)"}' 2>/dev/null || true)"
if [[ -z "${FORMAT}" || "${FORMAT}" == "false" ]]; then exit 0; fi

case "${CLIP_CHOICE}" in
	"SambaDance (舞步)") CLIP="samba" ;;
	"Run (跑步)") CLIP="run" ;;
	"Walk (走路)") CLIP="walk" ;;
	"Idle (待机)") CLIP="idle" ;;
	*) exit 0 ;;
esac

EXTRA=()
if [[ "${FORMAT}" == "FBX" ]]; then EXTRA+=(--fbx); fi

mkdir -p out
LOG="out/last_run.log"
set +e
./retarget.sh --target "${TARGET}" --clip "${CLIP}" "${EXTRA[@]}" 2>&1 | tee "${LOG}"
STATUS=$?
set -e

if [[ ${STATUS} -ne 0 ]]; then
	osascript -e 'display dialog "迁移失败，请查看 out/last_run.log" buttons {"好"}'
	exit ${STATUS}
fi

OUT_PATH="$(grep '^完成: ' "${LOG}" | tail -1 | sed 's/^完成: //')"
if [[ -n "${OUT_PATH}" ]]; then
	osascript -e "display dialog \"迁移完成：\n${OUT_PATH}\" buttons {\"在 Finder 中显示\"} default button 1"
	open -R "${OUT_PATH}" 2>/dev/null || true
fi
