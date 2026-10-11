#!/usr/bin/env bash
set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
zephyr_dir="$workspace_dir/zephyrproject/zephyr"
venv_dir="${ZEPHYR_VENV:-/opt/zephyr/venv}"
sdk_dir="${ZEPHYR_SDK_INSTALL_DIR:-/opt/zephyr/sdk}"
board="${ZEPHYR_BOARD:-frdm_mcxn947/mcxn947/cpu0}"
action="${1:-}"
app_name="${2:-}"

if [[ -z "$app_name" ]]; then
    printf 'Application folder under my_firmware: '
    read -r app_name
fi

if [[ -z "$app_name" || "$app_name" == */* || "$app_name" == "." || "$app_name" == ".." ]]; then
    printf 'Invalid application folder name: %s\n' "$app_name" >&2
    exit 2
fi

app_dir="$workspace_dir/my_firmware/$app_name"
build_dir="build/apps/$app_name"

if [[ ! -f "$app_dir/CMakeLists.txt" ]]; then
    printf 'Application not found: %s (expected CMakeLists.txt)\n' "$app_dir" >&2
    exit 2
fi

if [[ ! -f "$venv_dir/bin/activate" ]]; then
    printf 'Zephyr virtual environment not found: %s\n' "$venv_dir" >&2
    exit 2
fi

source "$venv_dir/bin/activate"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="$sdk_dir"

if [[ ! -d "$zephyr_dir/.west" && ! -d "$workspace_dir/zephyrproject/.west" ]]; then
    printf 'Zephyr west workspace not found under %s\n' "$workspace_dir/zephyrproject" >&2
    exit 2
fi

cd "$zephyr_dir"

build_app() {
    west build -d "$build_dir" -p auto -b "$board" "$app_dir"

    compile_db="$zephyr_dir/$build_dir/compile_commands.json"
    compile_link="$workspace_dir/.vscode/compile_commands.json"
    if [[ -f "$compile_db" ]]; then
        if [[ -e "$compile_link" && ! -L "$compile_link" ]]; then
            printf 'Not replacing existing non-symlink compile database: %s\n' "$compile_link" >&2
        else
            ln -sfn "$compile_db" "$compile_link"
        fi
    fi
}

flash_app() {
    if [[ ! -f "$zephyr_dir/$build_dir/zephyr/zephyr.elf" ]]; then
        printf 'No build found for %s. Run the build task first.\n' "$app_name" >&2
        exit 2
    fi
    west flash -d "$build_dir" -r jlink
}

debug_app() {
    if [[ ! -f "$zephyr_dir/$build_dir/zephyr/zephyr.elf" ]]; then
        printf 'No build found for %s. Run the build task first.\n' "$app_name" >&2
        exit 2
    fi
    west debug -d "$build_dir" -r jlink
}

case "$action" in
    build)
        build_app
        ;;
    flash)
        flash_app
        ;;
    debug)
        debug_app
        ;;
    build-flash)
        build_app
        flash_app
        ;;
    *)
        printf 'Usage: %s {build|flash|debug|build-flash} [application-folder]\n' "$0" >&2
        exit 2
        ;;
esac