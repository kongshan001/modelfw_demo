#!/usr/bin/env bash
set -euo pipefail
CALLER_PWD="$(pwd)"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

resolve_path() {
	case "$1" in
		[A-Za-z]:[\\/]*)
			if command -v cygpath >/dev/null 2>&1; then
				cygpath -u "$1"
			else
				printf '%s' "${1//\\//}"
			fi
			;;
		/*) printf '%s' "$1" ;;
		*) printf '%s/%s' "${CALLER_PWD}" "$1" ;;
	esac
}
if [[ -f config.env ]]; then
	# shellcheck disable=SC1091
	source config.env
fi
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
if [[ "${BLENDER}" == [A-Za-z]:* ]] && command -v cygpath >/dev/null 2>&1; then
	BLENDER="$(cygpath -u "${BLENDER}")"
fi
if [[ ! -x "${BLENDER}" ]]; then
	echo "ERROR: Blender not found. Run ./setup.sh first."
	exit 1
fi
export BLENDER
PYTHON="$(command -v python3 || command -v python || true)"
if [[ -z "${PYTHON}" ]]; then
	echo "ERROR: Python 3 is required for one-click report summaries."
	echo "Install Python 3 (Windows 勾选 Add python.exe to PATH) and rerun."
	exit 1
fi

usage() {
	cat <<'EOF'
一键迁移：把内置/自定义源动作烘到目标人形模型。

用法：
  ./retarget.sh --target /path/your.fbx --clip samba
  ./retarget.sh --target /path/your.fbx --clip run --fbx
  ./retarget.sh --target /path/your.fbx --source /path/source.glb --clip ActionName

参数：
  --target <fbx|glb>   目标人形模型（必填）
  --clip <alias|action> 内置别名：idle / walk / run / samba(dance)；
                        或源模型的准确动作名（配合 --source）
  --source <fbx|glb>   自定义源模型；不填则使用内置 Soldier/Michelle
  --out <path>         输出路径；默认 out/<目标名>_<clip>.glb
  --fps <n>            采样帧率，默认 30
  --map <json>         自定义骨骼映射（非 Mixamo 骨架）
  --simple             用全局增量公式（目标 rest 轴差异大时）
  --fbx                输出 FBX（默认 GLB）
  --list-clips         列出内置动作
  -h, --help           帮助
EOF
}

list_clips() {
	cat <<'EOF'
内置动作：
  idle   assets/source/Soldier.glb   Idle_Character
  walk   assets/source/Soldier.glb   Walk_Character
  run    assets/source/Soldier.glb   Run_Character
  samba  assets/target/Michelle.glb  SambaDance_Character
EOF
}

TARGET=""
CLIP=""
SOURCE=""
OUT=""
FPS="30"
MAP=""
SIMPLE=0
FBX=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		--target) TARGET="${2:-}"; shift 2 ;;
		--clip) CLIP="${2:-}"; shift 2 ;;
		--source) SOURCE="${2:-}"; shift 2 ;;
		--out) OUT="${2:-}"; shift 2 ;;
		--fps) FPS="${2:-30}"; shift 2 ;;
		--map) MAP="${2:-}"; shift 2 ;;
		--simple) SIMPLE=1; shift ;;
		--fbx) FBX=1; shift ;;
		--list-clips) list_clips; exit 0 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "ERROR: unknown argument: $1"; usage; exit 1 ;;
	esac
done

if [[ -z "${TARGET}" ]]; then
	echo "ERROR: --target is required"
	usage
	exit 1
fi
if [[ -z "${CLIP}" ]]; then
	echo "ERROR: --clip is required"
	list_clips
	exit 1
fi
TARGET="$(resolve_path "${TARGET}")"
if [[ -n "${SOURCE}" ]]; then SOURCE="$(resolve_path "${SOURCE}")"; fi
if [[ -n "${MAP}" ]]; then MAP="$(resolve_path "${MAP}")"; fi
if [[ -n "${OUT}" ]]; then OUT="$(resolve_path "${OUT}")"; fi
if [[ ! -f "${TARGET}" ]]; then
	echo "ERROR: target not found: ${TARGET}"
	exit 1
fi

ALIAS=""
ACTION="${CLIP}"
DEFAULT_SOURCE=""
if [[ -z "${SOURCE}" ]]; then
	case "${CLIP}" in
		idle|Idle) ALIAS="idle"; ACTION="Idle_Character"; DEFAULT_SOURCE="assets/source/Soldier.glb" ;;
		walk|Walk) ALIAS="walk"; ACTION="Walk_Character"; DEFAULT_SOURCE="assets/source/Soldier.glb" ;;
		run|Run) ALIAS="run"; ACTION="Run_Character"; DEFAULT_SOURCE="assets/source/Soldier.glb" ;;
		samba|dance|SambaDance) ALIAS="samba"; ACTION="SambaDance_Character"; DEFAULT_SOURCE="assets/target/Michelle.glb" ;;
		*)
			echo "ERROR: unknown built-in clip '${CLIP}'. Use --source <file> --clip <action> for custom clips."
			list_clips
			exit 1
			;;
	esac
	SOURCE="${DEFAULT_SOURCE}"
else
	ALIAS="$(echo "${CLIP}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
fi

if [[ ! -f "${SOURCE}" ]]; then
	echo "ERROR: source not found: ${SOURCE}"
	exit 1
fi

mkdir -p out
if [[ -z "${OUT}" ]]; then
	STEM="$(basename "${TARGET}")"
	STEM="${STEM%.*}"
	STEM="${STEM// /_}"
	EXT="glb"
	if [[ "${FBX}" -eq 1 ]]; then EXT="fbx"; fi
	OUT="out/${STEM}_${ALIAS}.${EXT}"
fi
mkdir -p "$(dirname "${OUT}")"

echo "== 1/4 inspect source =="
INSPECT_SRC="out/last_source_inspect.log"
if ! bash tools/blender_inspect.sh "${SOURCE}" --require-armature > "${INSPECT_SRC}" 2>&1; then
	echo "ERROR: source inspect failed"
	tail -30 "${INSPECT_SRC}"
	exit 1
fi
SRC_REPORT="$(grep '^BLENDER_REPORT ' "${INSPECT_SRC}" | tail -1 | sed 's/^BLENDER_REPORT //')"
"${PYTHON}" - "${SRC_REPORT}" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(f"  armatures={d.get('armatures')} bones={d.get('bones')} size={d.get('size')} tpose={d.get('tpose_hint')}")
print(f"  actions={[a.get('name') for a in d.get('actions', [])]}")
PY

echo "== 2/4 inspect target =="
INSPECT_TGT="out/last_target_inspect.log"
if ! bash tools/blender_inspect.sh "${TARGET}" --require-armature > "${INSPECT_TGT}" 2>&1; then
	echo "ERROR: target inspect failed (need a humanoid armature)"
	tail -30 "${INSPECT_TGT}"
	exit 1
fi
TGT_REPORT="$(grep '^BLENDER_REPORT ' "${INSPECT_TGT}" | tail -1 | sed 's/^BLENDER_REPORT //')"
"${PYTHON}" - "${TGT_REPORT}" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(f"  armatures={d.get('armatures')} bones={d.get('bones')} size={d.get('size')} tpose={d.get('tpose_hint')}")
print(f"  bone_samples={d.get('bone_samples')}")
if d.get('bones', 0) < 20:
    print("ERROR: target has < 20 bones; not a usable humanoid rig")
    sys.exit(1)
if not d.get('tpose_hint'):
    print("WARN: target is not T-pose-like; if the result tilts, run Rest Fixer or try --simple.")
PY

echo "== 3/4 retarget =="
ARGS=(--source "${SOURCE}" --target "${TARGET}" --clip "${ACTION}" --out "${OUT}" --fps "${FPS}")
if [[ -n "${MAP}" ]]; then ARGS+=(--map "${MAP}"); fi
if [[ "${SIMPLE}" -eq 1 ]]; then ARGS+=(--simple); fi
RETARGET_LOG="out/last_retarget.log"
if ! bash tools/blender_retarget.sh "${ARGS[@]}" > "${RETARGET_LOG}" 2>&1; then
	echo "ERROR: retarget failed"
	grep -E "RETARGET_ERROR|ERROR" "${RETARGET_LOG}" | tail -10 || tail -30 "${RETARGET_LOG}"
	echo "提示：自定义骨架需要 --map；目标骨骼列表见 ${INSPECT_TGT}"
	exit 1
fi
RETARGET_REPORT="$(grep '^RETARGET_REPORT ' "${RETARGET_LOG}" | tail -1 | sed 's/^RETARGET_REPORT //')"
if [[ -z "${RETARGET_REPORT}" || ! -s "${OUT}" ]]; then
	echo "ERROR: retarget did not produce a usable output"
	grep -E "RETARGET_ERROR|RETARGET_HINT|RETARGET_WARN|Traceback" "${RETARGET_LOG}" | tail -20 || tail -30 "${RETARGET_LOG}"
	exit 1
fi
grep '^RETARGET_WARN ' "${RETARGET_LOG}" | tail -3 || true
"${PYTHON}" - "${RETARGET_REPORT}" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
print(f"  mapped={d.get('mapped_bones')}/{d.get('target_bones')} formula={d.get('formula')}")
print(f"  missing_in_source={d.get('missing_in_source')}")
print(f"  missing_in_target={d.get('missing_in_target')}")
PY

echo "== 4/4 validate =="
VALIDATE_LOG="out/last_validate.log"
if ! bash tools/blender_validate.sh "${OUT}" > "${VALIDATE_LOG}" 2>&1; then
	echo "ERROR: validate failed"
	tail -30 "${VALIDATE_LOG}"
	exit 1
fi
VALIDATION_REPORT="$(grep '^VALIDATION_REPORT ' "${VALIDATE_LOG}" | tail -1 | sed 's/^VALIDATION_REPORT //')"
"${PYTHON}" - "${VALIDATION_REPORT}" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
dev = d.get('max_bone_length_deviation', 1.0)
print(f"  bones={d.get('bones')} actions={d.get('actions')}")
print(f"  max_bone_length_deviation={dev}")
if dev >= 0.01:
    print("ERROR: bone length drift >= 1%; do not ship this output")
    sys.exit(1)
PY

echo
echo "完成: ${OUT}"
echo "目标: ${TARGET}"
echo "动作: ${ACTION}（${SOURCE}）"
echo "报告: ${RETARGET_LOG}"
echo "注意: validate 只查骨长；请在目标引擎里检查手肘/膝盖、整体倾斜、脚滑和 root motion。"
