#!/bin/zsh
set -euo pipefail

PATH="/usr/bin:/bin:/usr/sbin:/sbin"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
LOCK_IN_TEMPLATE="${REPO_ROOT}/apps/lock_in_headphones.applescript"
MANAGE_TEMPLATE="${REPO_ROOT}/apps/manage_music_sources.applescript"
LOCK_IN_APP="${DIST_DIR}/Lock In Headphones.app"
MANAGE_APP="${DIST_DIR}/Manage Music Sources.app"

mkdir -p "${DIST_DIR}"

compile_template() {
  local template_path="$1"
  local output_path="$2"
  local tmp_file
  local tmp_app_dir
  local tmp_app_path

  tmp_file="$(mktemp)"
  tmp_app_dir="$(mktemp -d)"
  tmp_app_path="${tmp_app_dir}/$(basename "${output_path}")"
  sed "s|__REPO_ROOT__|${REPO_ROOT}|g" "${template_path}" > "${tmp_file}"
  rm -rf "${output_path}"
  osacompile -o "${tmp_app_path}" "${tmp_file}"
  xattr -cr "${tmp_app_path}" 2>/dev/null || true
  ditto "${tmp_app_path}" "${output_path}"
  rm -f "${tmp_file}"
  rm -rf "${tmp_app_dir}"
}

compile_template "${LOCK_IN_TEMPLATE}" "${LOCK_IN_APP}"
compile_template "${MANAGE_TEMPLATE}" "${MANAGE_APP}"

printf 'Built:\n%s\n%s\n' "${LOCK_IN_APP}" "${MANAGE_APP}"
