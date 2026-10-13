# ############################################################################ #
# #                       File Name: install_font.zsh                        # #
# ############################################################################ #
# 字体下载安装函数（zsh）
#
# 用法（在 ~/.zshrc 中 source）:
#
#   source /path/to/install_font.zsh
#
#   install_font_fantasque              # nerd-fonts FantasqueSansMono，默认 v3.5.0
#   install_font_fantasque 3.4.0         # 指定版本
#   install_font_fantasque --user       # 装到 ~/.local/share/fonts（免 sudo）
#   install_font_juliamono              # Claude Code / Codex / codegraph 符号 fallback
#   install_font_juliamono --only-regular
#   install_font_all --user 3.4.0        # 两个都装，版本仅用于 Fantasque
#
# 说明:
#   · 需要写系统目录时，直接通过 sudo 执行命令，由 sudo 按策略决定是否提示输入密码
#   · root 账号通常没有 zsh，所以这里绝不使用 `sudo zsh -c '...'` 这类写法，
#     sudo 只包裹 mkdir / cp / chown / chmod / fc-cache / restorecon 这些外部命令
#   · 常见的坑: 只 chmod 目录不 chmod 文件 → 字体会带可执行位；
#     开了 SELinux 却不 restorecon → 字体被静默忽略且 fc-cache 不报错。下面都处理了。

# ---------------------------------------------------------------- 内部工具

# 按模式决定是否前置 sudo；用户级安装或已经是 root 时直接执行
function _font_run() {
    if (( FONT_USE_SUDO )); then
        sudo "$@"
    else
        "$@"
    fi
}

# 修复 SELinux 上下文后刷新目标目录的字体缓存，再验证字体
function _font_finalize() {
    emulate -L zsh
    setopt pipefail
    local dest="$1" keyword="$2"

    if command -v restorecon >/dev/null 2>&1; then
        print -r -- "==> 修复 SELinux 上下文"
        _font_run restorecon -R "$dest" || return 1
    fi

    print -r -- ""
    print -r -- "==> 刷新字体缓存"
    _font_run fc-cache -f "$dest" || return 1

    print -r -- ""
    print -r -- "==> 验证"
    local output
    local -a found
    if ! output=$(fc-list | grep -iF -- "$keyword") || [[ -z "$output" ]]; then
        print -u2 -r -- "✘ fontconfig 没识别到 ${keyword}。请检查:"
        print -u2 -r -- "    ls -lZ ${(q)dest} | head"
        return 1
    fi
    found=("${(@f)output}")
    print -r -- "✔ 已识别 ${#found} 条:"
    print -r -- "    ${found[1]}"
    (( ${#found} > 1 )) && print -r -- "    ${found[2]}"
    (( ${#found} > 2 )) && print -r -- "    ... 共 ${#found} 条"
    return 0
}

# 安装: 把 ttfs 数组里的字体装到 dest
function _font_install_to() {
    emulate -L zsh
    local dest="$1"
    shift
    local -a ttfs
    ttfs=("$@")

    print -r -- "==> 安装到 ${dest}"
    _font_run mkdir -p "$dest" || return 1
    _font_run cp -f "${ttfs[@]}" "$dest"/ || return 1

    if (( FONT_USE_SUDO || EUID == 0 )); then
        _font_run chown -R root:root "$dest" || return 1
    fi
    _font_run chmod 755 "$dest" || return 1

    # (N) 避免没有 .ttf 或 .otf 时触发 NOMATCH，导致权限未更新。
    local -a files
    files=("$dest"/**/*.ttf(N) "$dest"/**/*.otf(N))
    if (( ${#files} )); then
        _font_run chmod 644 "${files[@]}" || return 1
    fi
    return 0
}

# ---------------------------------------------------------------- FantasqueSansMono (nerd-fonts)

function install_font_fantasque() {
    emulate -L zsh
    setopt pipefail

    local version="3.5.0" user_mode=0 only_regular=0
    while (( $# )); do
        case "$1" in
            -u|--user) user_mode=1; shift ;;
            --only-regular) only_regular=1; shift ;;
            -h|--help)
                print -r -- "用法: install_font_fantasque [--user] [--only-regular] [版本]"
                print -r -- "  版本默认 3.5.0（nerd-fonts release tag，函数内自动补 v 前缀）"
                return 0 ;;
            -*) print -u2 -r -- "未知选项: $1"; return 1 ;;
            *) version="${1#v}"; shift ;;
        esac
    done

    local font="FantasqueSansMono"
    local repo="ryanoasis/nerd-fonts"
    local url="https://github.com/${repo}/releases/download/v${version}/${font}.zip"

    (( only_regular )) && print -r -- "注意: nerd-fonts 单字重过滤仅保留 Regular，其余丢弃"

    local -i FONT_USE_SUDO=0
    local dest
    if (( user_mode )); then
        dest="${HOME}/.local/share/fonts/${font}"
    else
        dest="/usr/share/fonts/${font}"
        (( EUID == 0 )) || FONT_USE_SUDO=1
    fi

    local work
    work=$(mktemp -d) || { print -u2 -r -- "✘ 无法创建临时目录"; return 1; }
    {
        print -r -- "==> 下载 ${font} v${version}"
        print -r -- "    ${url}"
        if ! curl -fL --retry 3 --connect-timeout 10 --progress-bar "$url" -o "${work}/${font}.zip"; then
            print -u2 -r -- "✘ 下载失败。可手动取:"
            print -r -- "    https://github.com/${repo}/releases/tag/v${version}"
            return 1
        fi

        print -r -- "==> 解压"
        local ex="${work}/ex"
        mkdir -p "$ex" || return 1
        if command -v unzip >/dev/null 2>&1; then
            unzip -oq "${work}/${font}.zip" -d "$ex" || { print -u2 -r -- "✘ 解压失败"; return 1; }
        else
            python3 -m zipfile -e "${work}/${font}.zip" "$ex" \
                || { print -u2 -r -- "✘ 解压失败（需要 unzip 或 python3）"; return 1; }
        fi

        # 全量解压后再筛，别在解压时过滤文件名（包内层带目录时 pattern 会静默匹配失败）
        local -a ttfs
        ttfs=("${ex}"/**/*.ttf(N) "${ex}"/**/*.otf(N))
        if (( ${#ttfs} == 0 )); then
            print -u2 -r -- "✘ 没解出任何字体文件"; return 1
        fi
        if (( only_regular )); then
            ttfs=("${ex}"/**/*Regular*.ttf(N) "${ex}"/**/*Regular*.otf(N))
            (( ${#ttfs} )) || { print -u2 -r -- "✘ 过滤 Regular 后为空"; return 1; }
        fi
        print -r -- "    解出 ${#ttfs} 个文件"

        _font_install_to "$dest" "${ttfs[@]}" || return 1
        _font_finalize "$dest" "$font"
    } always {
        rm -rf "$work"
    }
}

# ---------------------------------------------------------------- JuliaMono

function install_font_juliamono() {
    emulate -L zsh
    setopt pipefail

    local user_mode=0 only_regular=0
    while (( $# )); do
        case "$1" in
            -u|--user) user_mode=1; shift ;;
            --only-regular) only_regular=1; shift ;;
            -h|--help)
                print -r -- "用法: install_font_juliamono [--user] [--only-regular]"
                print -r -- "  JuliaMono 官方只发 GitHub Releases, 无 RPM"
                print -r -- "  --only-regular 只取 JuliaMono-Regular.ttf (3.2MB)"
                return 0 ;;
            -*) print -u2 -r -- "未知选项: $1"; return 1 ;;
            *) print -u2 -r -- "多余参数: $1"; return 1 ;;
        esac
    done

    local repo="cormullion/juliamono"
    local base="https://github.com/${repo}/releases/latest/download"

    local -i FONT_USE_SUDO=0
    local dest
    if (( user_mode )); then
        dest="${HOME}/.local/share/fonts/JuliaMono"
    else
        dest="/usr/share/fonts/JuliaMono"
        (( EUID == 0 )) || FONT_USE_SUDO=1
    fi

    local work
    work=$(mktemp -d) || { print -u2 -r -- "✘ 无法创建临时目录"; return 1; }
    {
        print -r -- "==> 下载 JuliaMono (最新版)"
        local got="" asset
        for asset in JuliaMono-ttf.tar.gz JuliaMono-ttf.zip; do
            print -r -- "    尝试 ${asset}"
            if curl -fL --retry 3 --connect-timeout 10 --progress-bar \
                "${base}/${asset}" -o "${work}/${asset}"; then
                got="${asset}"; break
            fi
            print -r -- "    ⚠️ 失败，换下一个"
        done
        if [[ -z "$got" ]]; then
            print -u2 -r -- "✘ 下载失败。手动地址:"
            print -r -- "    https://github.com/${repo}/releases"
            print -r -- "    镜像: https://mirrors.ctan.org/fonts/juliamono/"
            return 1
        fi

        print -r -- "==> 解压 ${got}"
        local ex="${work}/ex"
        mkdir -p "$ex" || return 1
        if [[ "$got" == *.tar.gz ]]; then
            tar -xzf "${work}/${got}" -C "$ex" || { print -u2 -r -- "✘ 解压失败"; return 1; }
        else
            if command -v unzip >/dev/null 2>&1; then
                unzip -oq "${work}/${got}" -d "$ex"
            else
                python3 -m zipfile -e "${work}/${got}" "$ex"
            fi
            (( $? == 0 )) || { print -u2 -r -- "✘ 解压失败"; return 1; }
        fi

        # 全量解压后再筛，只留 .ttf（丢掉 LICENSE / README / webfonts 的 woff2）
        local -a ttfs
        ttfs=("${ex}"/**/*.ttf(N))
        (( ${#ttfs} )) || { print -u2 -r -- "✘ 没解出任何 .ttf"; return 1; }

        if (( only_regular )); then
            ttfs=("${ex}"/**/JuliaMono-Regular.ttf(N))
            (( ${#ttfs} )) || { print -u2 -r -- "✘ 过滤 Regular 后为空"; return 1; }
        fi
        print -r -- "    解出 ${#ttfs} 个 TTF"

        _font_install_to "$dest" "${ttfs[@]}" || return 1
        _font_finalize "$dest" "JuliaMono" || return 1

        print -r -- ""
        print -r -- "==> 关键符号是否由 JuliaMono 提供"
        local cp fams
        for cp in 23fa 23bf 23f1 280b 2733 26cf; do
            fams="$(fc-list ":charset=${cp}" -f '%{family[0]}\n' 2>/dev/null | sort -u)"
            if print -r -- "$fams" | grep -qi juliamono; then
                printf '    U+%s  ✔ JuliaMono\n' "$cp"
            else
                printf '    U+%s  ✘ 未提供 (候选: %s)\n' "$cp" "$(print -r -- "$fams" | head -1)"
            fi
        done
    } always {
        rm -rf "$work"
    }
}

# ---------------------------------------------------------------- 组合 / 校验

function install_font_all() {
    emulate -L zsh
    local arg
    local -a julia_args
    # 版本参数只属于 Fantasque；JuliaMono 使用最新发行版。
    for arg in "$@"; do
        [[ "$arg" == -* ]] && julia_args+=("$arg")
    done
    install_font_fantasque "$@" || return 1
    print -r -- ""
    install_font_juliamono "${julia_args[@]}"
}

# 查询提供指定 Unicode 码位的字体文件
function font_who_has() {
    emulate -L zsh
    setopt pipefail
    local cp="${1#U+}"
    cp="${cp#0x}"
    print -r -- "U+${cp} 由以下字体提供:"
    fc-list ":charset=${cp}" -f '  %{file}\n' 2>/dev/null | sort -u
}
