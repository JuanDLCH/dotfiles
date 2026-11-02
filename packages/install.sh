#!/usr/bin/env bash
# Install package suites on any distro from the plain-text manifests in suites/.
#
#   packages/install.sh --suite base,dev [--dry-run] [--yes] [--family arch|debian|fedora]
#   packages/install.sh --list            # show suites
#
# Manifest line:  name | arch | debian | fedora | flatpak | note
#   - a cell holds one or more package names, and/or @script:NAME (runs scripts/NAME.sh)
#   - an empty cell for this distro falls back to the flatpak column, else the app is skipped
#   - a failing app is reported at the end; it never stops the rest
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
suites="" dry=0 yes=0 family=""

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }
while (($#)); do
    case $1 in
        --suite|-s) suites=$2; shift ;;
        --suite=*) suites=${1#*=} ;;
        --dry-run|-n) dry=1 ;;
        --yes|-y) yes=1 ;;
        --family) family=$2; shift ;;
        --list) for f in "$here"/suites/*.txt; do
                    printf '%-14s %s\n' "$(basename "$f" .txt)" "$(sed -n 's/^#: //p' "$f" | head -1)"
                done; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done
[[ -n $suites ]] || { usage; exit 2; }

# ── Distro family ───────────────────────────────────────
detect_family() {
    local id="" like=""
    # shellcheck disable=SC1091
    [[ -r /etc/os-release ]] && { . /etc/os-release; id=${ID:-}; like=${ID_LIKE:-}; }
    for x in $id $like; do
        case $x in
            arch|archarm|cachyos|endeavouros|manjaro) echo arch; return ;;
            debian|ubuntu|linuxmint|pop) echo debian; return ;;
            fedora|rhel|centos|nobara) echo fedora; return ;;
        esac
    done
    echo unknown
}
[[ -n $family ]] || family=$(detect_family)
case $family in
    arch) col=2 ;; debian) col=3 ;; fedora) col=4 ;;
    *) col=0; echo "Unknown distro family: only flatpak apps will be installed." >&2 ;;
esac

SUDO=(sudo); ((EUID == 0)) && SUDO=()
run() {   # print, and execute unless --dry-run
    printf '  $ %s\n' "$*"
    ((dry)) || "$@"
}

aur_helper() { command -v paru || command -v yay; }

native_install() {   # native_install pkg...
    local y=()
    case $family in
        arch)
            ((yes)) && y=(--noconfirm)
            local h; h=$(aur_helper)
            if [[ -n $h ]]; then run "$h" -S --needed "${y[@]}" "$@"
            else run "${SUDO[@]}" pacman -S --needed "${y[@]}" "$@"; fi ;;
        debian) ((yes)) && y=(-y); run "${SUDO[@]}" apt-get install "${y[@]}" "$@" ;;
        fedora) ((yes)) && y=(-y); run "${SUDO[@]}" dnf install "${y[@]}" "$@" ;;
        *) return 1 ;;
    esac
}

flatpak_ready=0
flatpak_install() {   # flatpak_install app-id
    if ((!flatpak_ready)); then
        command -v flatpak >/dev/null || ((dry)) || native_install flatpak || return 1
        run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
        flatpak_ready=1
    fi
    local y=(); ((yes)) && y=(-y)
    run flatpak install --user --or-update "${y[@]}" flathub "$1"
}

run_script() {   # run_script NAME
    local s="$here/scripts/$1.sh"
    [[ -f $s ]] || { echo "  missing script: $s" >&2; return 1; }
    run env FAMILY="$family" YES="$yes" bash "$s"
}

trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

# ── Collect the plan ────────────────────────────────────
declare -a names=() cells=() kinds=()
IFS=, read -ra wanted <<<"$suites"
for suite in "${wanted[@]}"; do
    file="$here/suites/$(trim "$suite").txt"
    [[ -f $file ]] || { echo "No such suite: $suite (see --list)" >&2; exit 2; }
    while IFS= read -r raw; do
        [[ $raw =~ ^[[:space:]]*(#|$) ]] && continue
        IFS='|' read -ra f <<<"$raw"
        name=$(trim "${f[0]}")
        cell=""; kind=native
        ((col)) && cell=$(trim "${f[col-1]:-}")
        if [[ -z $cell ]]; then cell=$(trim "${f[4]:-}"); kind=flatpak; fi
        [[ -z $cell ]] && kind=skip
        names+=("$name"); cells+=("$cell"); kinds+=("$kind")
    done <"$file"
done

echo "Distro family: $family    suites: $suites"
for i in "${!names[@]}"; do
    printf '  %-16s %-8s %s\n' "${names[i]}" "${kinds[i]}" "${cells[i]}"
done
if ((!dry && !yes)); then
    read -rp "Install these? [Y/n] " a
    [[ -z $a || $a =~ ^[Yy] ]] || exit 0
fi
[[ $family == debian ]] && ((!dry)) && "${SUDO[@]}" apt-get update

# ── Install ─────────────────────────────────────────────
declare -a failed=() skipped=()
for i in "${!names[@]}"; do
    name=${names[i]} cell=${cells[i]} ok=1
    echo "── $name"
    case ${kinds[i]} in
        skip) skipped+=("$name"); echo "  no package for $family, skipped"; continue ;;
        flatpak) flatpak_install "$cell" || ok=0 ;;
        native)
            pkgs=() scripts=()
            for tok in $cell; do
                if [[ $tok == @script:* ]]; then scripts+=("${tok#@script:}"); else pkgs+=("$tok"); fi
            done
            ((${#pkgs[@]})) && { native_install "${pkgs[@]}" || ok=0; }
            for s in "${scripts[@]}"; do run_script "$s" || ok=0; done ;;
    esac
    ((ok)) || failed+=("$name")
done

echo
((${#skipped[@]})) && echo "Skipped (no package for $family): ${skipped[*]}"
((${#failed[@]})) && { echo "FAILED: ${failed[*]}"; exit 1; }
echo "Done."
