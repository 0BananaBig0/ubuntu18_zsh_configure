# ############################################################################ #
# #                         File Name: function.zsh                          # #
# #                          Author: Huaxiao Liang                           # #
# #                         Mail: hxliang666@qq.com                          # #
# #                         08/06/2026-Thu-00:01:01                          # #
# ############################################################################ #
# Define some functions:
# 函数：安全地添加路径到环境变量
# 参数：
#   $1: 环境变量名称 (如 PATH, LD_LIBRARY_PATH)
#   $2: 要添加的路径
#   $3: 添加位置，可选值 "before" 或 "after"，默认为 "before"
add_to_env_var() {
    local var_name="$1"
    local new_path="$2"
    local position="${3:-before}"

    # 判断路径是否存在
    if [[ ! -d "$new_path" ]]; then
        return 1
    fi

    # zsh 原生间接引用方式
    local current_value="${(P)var_name}"

    # 判断环境变量是否为空
    if [[ -z "$current_value" ]]; then
        export "$var_name=$new_path"
        return 0
    fi

    # 根据位置添加
    case "$position" in
        before|前面|前)
            export "$var_name=$new_path:$current_value"
            ;;
        after|后面|后)
            export "$var_name=$current_value:$new_path"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}
# 使用示例：
# add_to_env_var "PATH" "/usr/local/bin" "before"
# add_to_env_var "LD_LIBRARY_PATH" "/opt/lib" "after"
add_to_multiple_env_vars() {
    local new_path="$1"
    local position="${2:-before}"
    if [[ ! -d "${new_path}" ]]; then
        return 0
    fi
    add_to_env_var "PATH" "${new_path}/bin" "${position}"
    add_to_env_var "LIBRARY_PATH" "${new_path}/lib" "${position}"
    add_to_env_var "LD_LIBRARY_PATH" "${new_path}/lib" "${position}"
    add_to_env_var "XDG_DATA_DIRS" "${new_path}/share" "${position}"
    if [[ "${new_path}" == "/usr" || "${new_path}" == "/usr/local" ]]; then
        return 0
    fi
    add_to_env_var "C_INCLUDE_PATH" "${new_path}/include" "${position}"
    add_to_env_var "CPLUS_INCLUDE_PATH" "${new_path}/include" "${position}"
}



# Personal functions
find_root_path() {
    # Step 1: Define an array of root patterns
    local root_patterns=(".git" ".hg" ".projections.json" ".project" ".svn" ".root" ".vscode" "SConstruct")
    local current_path="$PWD"

    # Step 2: Traverse up to the root
    while [[ "$current_path" != "${HOME}" && "$current_path" != "/home/$SUDO_USER" && "$current_path" != "/" ]]; do
        for pattern in "${root_patterns[@]}"; do
            # Check if the pattern exists as a file or directory
            if [[ -e "$current_path/$pattern" ]]; then
                echo "$current_path"
                return 0
            fi
        done
        # Move to the parent directory
        current_path=$(dirname "$current_path")
    done

    # Step 3: If no match, return the current path and echo a message
    echo "$PWD"
    echo "Warning: You had better create a root-pattern file like .git in your project." >&2
    return 1
}

check_and_copy_file() {
    local source_path="${HOME}/.vim/.c_cpp"
    local workspace_path="$1"
    local file_name="$2"

    # Check if the file exists in the current workspace
    if [[ -e "$workspace_path/$file_name" ]]; then
        echo "File $workspace_path/$file_name has existed."
    elif [[ -e "$source_path/$file_name" ]]; then
        # If the file exists in the specific path, copy it to the current workspace
        cp "$source_path/$file_name" "$workspace_path/$file_name"
    else
        # If the file doesn't exist in either location
        echo "Warning: File $source_path/$file_name and $workspace_path/$file_name file do not exist."
        return 0
    fi
    return 1
}

configure() {
    # Argument: $1 (could be clang, vscode, vimspector, dbg, all or "")
    local action="$1"
    local recursive="$2"
    # Only created and assigned once, a global var
    if [ -z "$workspace_path" ]; then
        workspace_path=$(find_root_path)
    fi

    case "$action" in
        clang)
            check_and_copy_file $workspace_path ".clangd"
            check_and_copy_file $workspace_path ".clang-format"
            check_and_copy_file $workspace_path ".clang-tidy"
            if [[ $recursive -eq 1 ]]; then
              return 1
            fi
            ;;
        vscode)
            if [[ ! -d "$workspace_path/.vscode" ]]; then
              mkdir "$workspace_path/.vscode"
            fi
            check_and_copy_file $workspace_path ".vscode/launch.json"
            if [[ $recursive -eq 1 ]]; then
              return 1
            fi
            ;;
        vimspector)
            check_and_copy_file $workspace_path ".vimspector.json"
            local result=$?
            if [[ $result -eq 1 ]]; then
              gvim "$workspace_path/.vimspector.json"
            fi
            if [[ $recursive -eq 1 ]]; then
              return 1
            fi
            ;;
        dbg)
            configure vscode 1
            configure vimspector 1
            ;;
        all)
            configure clang 1
            configure dbg 1
            ;;
        "")
            configure clang 1
            configure vimspector 1
            ;;
        *)
            echo "Invalid argument: '$action'. Please specify clang, vscode, vimspector, dbg, all or \"\"."
            return 0
            ;;
    esac
    unset workspace_path
    return 1
}



backup_terminal_config() {
    local base_dir="${1:-${HOME}/configuration_file}"
    local qt_version="${2:-$(ldd "$(command -v konsole)" 2>/dev/null | grep -oE 'libQt[56]Core\.so' | head -1)}"
    qt_version="${qt_version#libQt}"; qt_version="${qt_version%Core.so}"
    local backup_dir="${base_dir}/terminal_backup_Qt_${qt_version}"

    [[ ! -d "${base_dir}" ]] && { echo "ERROR：${base_dir} does not exist" >&2; return 1 }
    mkdir -p "${backup_dir}"

    [[ -f "${HOME}/.config/terminator/config" ]] && {
        mkdir -p "${backup_dir}/terminator"
        cp -af "${HOME}/.config/terminator/config" "${backup_dir}/terminator/"
    }

    [[ -f "${HOME}/.config/konsolerc" ]] && {
        mkdir -p "${backup_dir}/konsole"
        cp -af "${HOME}/.config/konsolerc" "${backup_dir}/konsole/"
    }

    [[ -d "${HOME}/.local/share/konsole" ]] && {
        mkdir -p "${backup_dir}/konsole/share-konsole"
        cp -af "${HOME}/.local/share/konsole/"* "${backup_dir}/konsole/share-konsole/"
    }
}

restore_terminal_config() {
    local base_dir="${1:-${HOME}/configuration_file}"
    local qt_version="${2:-$(ldd "$(command -v konsole)" 2>/dev/null | grep -oE 'libQt[56]Core\.so' | head -1)}"
    qt_version="${qt_version#libQt}"; qt_version="${qt_version%Core.so}"
    local backup_dir="${base_dir}/terminal_backup_Qt_${qt_version}"

    [[ ! -d "${backup_dir}" ]] && { echo "ERROR：${backup_dir} does not exist" >&2; return 1 }

    [[ -f "${backup_dir}/terminator/config" ]] && {
        mkdir -p "${HOME}/.config/terminator"
        cp -af "${backup_dir}/terminator/config" "${HOME}/.config/terminator/"
    }

    [[ -f "${backup_dir}/konsole/konsolerc" ]] && {
        cp -af "${backup_dir}/konsole/konsolerc" "${HOME}/.config/"
    }

    [[ -d "${backup_dir}/konsole/share-konsole" ]] && {
        mkdir -p "${HOME}/.local/share/konsole"
        cp -af "${backup_dir}/konsole/share-konsole/"* "${HOME}/.local/share/konsole/"
    }
}

# 辅助：在 /usr/lib/jvm 中找可用的 JDK 根目录
# 优先级：目录名含 latest > 版本号最大（支持 jre-*/bin/java）
_find_latest_jdk() {
    # 1. 找 /usr/lib/jvm 下目录名包含 latest 的
    local latest_dir
    latest_dir=$(find /usr/lib/jvm -maxdepth 1 -type d -name '*latest*' 2>/dev/null | head -1)

    if [[ -n "$latest_dir" ]]; then
        # 只输出最终结果，不输出中间信息
        readlink -f "$latest_dir" 2>/dev/null || echo "$latest_dir"
        return 0
    fi

    # 2. 兜底：扫描所有目录
    [[ ! -d /usr/lib/jvm ]] && return 1

    local best_home="" best_ver="" java_bin ver

    for d in /usr/lib/jvm/*; do
        java_bin=""
        [[ -x "$d/bin/java" ]] && java_bin="$d/bin/java"
        [[ -z "$java_bin" && -x "$d/jre/bin/java" ]] && java_bin="$d/jre/bin/java"
        [[ -z "$java_bin" ]] && continue

        ver=$("$java_bin" -version 2>&1 | awk '/version/{print $NF}' | tr -d '"')
        [[ -z "$ver" ]] && continue

        if [[ -z "$best_ver" ]] || [[ $(sort -V <<< "$ver"$'\n'"$best_ver" | tail -1) == "$ver" ]]; then
            best_ver="$ver"
            best_home="$d"
        fi
    done

    # 只在最后输出一次结果
    if [[ -n "$best_home" ]]; then
        echo "$best_home"
        return 0
    fi

    return 1
}

# 辅助：检查当前 java 是否 >= 11
_check_java_version() {
    local ver_str major minor
    ver_str=$(java -version 2>&1 | head -1)
    # 直接用 grep -oP 提取版本号中的前两个数字
    local ver_parts
    ver_parts=$(echo "$ver_str" | grep -oP '\d+\.\d+')
    [[ -z "$ver_parts" ]] && return 1
    # 分割版本号
    IFS='.' read -r major minor <<< "$ver_parts"
    # Java 8 格式: 1.8 -> major=1, minor=8 -> 实际版本 8
    [[ "$major" == "1" ]] && major=$minor
    (( major >= 11 )) && return 0
    return 1
}

backup_linux_config() {
    local dest_dir="${1:-${HOME}/configuration_file}"

    [[ ! -d "${dest_dir}" ]] && mkdir -p "${dest_dir}"

    [[ -f "${HOME}/.gdbinit" ]] && {
        # 把所有 gcc 相关路径替换为统一占位符
        sed 's|sys\.path\.insert(0, '\''/[^'\'']*gcc[^'\'']*/python'\'')|sys.path.insert(0, '\''__GCC_PYTHON_PATH__'\'')|g' "${HOME}/.gdbinit" > "${dest_dir}/.gdbinit"
    }

    [[ -f "${HOME}/.vim/coc-settings.json" ]] && {
        sed '/"xml\.java\.home"/d' "${HOME}/.vim/coc-settings.json" > "${dest_dir}/coc-settings.json"
    }
    [[ -f "${HOME}/.vimrc" ]] && cp -af "${HOME}/.vimrc" "${dest_dir}/"
    [[ -d "${HOME}/.vim/.c_cpp" ]] && cp -af "${HOME}/.vim/.c_cpp" "${dest_dir}/"
    [[ -f "${HOME}/.zshrc" ]] && cp -af "${HOME}/.zshrc" "${dest_dir}/"
    [[ -f "${HOME}/.oh-my-zsh/custom/ys_modified.zsh-theme" ]] && cp -af "${HOME}/.oh-my-zsh/custom/ys_modified.zsh-theme" "${dest_dir}/"
    [[ -f "${HOME}/.config/nvim/init.vim" ]] && cp -af "${HOME}/.config/nvim/init.vim" "${dest_dir}/"
    [[ -f "${HOME}/.tessent_startup" ]] && cp -af "${HOME}/.tessent_startup" "${dest_dir}/"
}

restore_linux_config() {
    local src_dir="${1:-${HOME}/configuration_file}"

    [[ ! -d "${src_dir}" ]] && { echo "ERROR：${src_dir} does not exist" >&2; return 1 }

    [[ -f "${src_dir}/.gdbinit" ]] && {
        # 通过 printers.py 找到 gcc python 路径
        local printer_path
        printer_path=$(find /usr/share -path '*/libstdcxx/v6/printers.py' 2>/dev/null | head -1)

        if [[ -n "${printer_path}" ]]; then
            # 截取 printers.py 前面的 python 目录路径
            # 例如：/usr/share/gcc-12/python/libstdcxx/v6/printers.py
            # 截取后：/usr/share/gcc-12/python
            local gcc_python_path="${printer_path%/libstdcxx/v6/printers.py}"

            sed "s|__GCC_PYTHON_PATH__|${gcc_python_path}|g" "${src_dir}/.gdbinit" > "${HOME}/.gdbinit"
        else
            # 备用：直接找 gcc python 目录
            local fallback_path
            fallback_path=$(find /usr/share -maxdepth 4 -type d -name 'python' -path '*/gcc*' 2>/dev/null | head -1)

            if [[ -n "${fallback_path}" ]]; then
                sed "s|__GCC_PYTHON_PATH__|${fallback_path}|g" "${src_dir}/.gdbinit" > "${HOME}/.gdbinit"
            else
                cp -af "${src_dir}/.gdbinit" "${HOME}/"
                echo "Warning: Could not find GCC python path, using default .gdbinit" >&2
            fi
        fi
    }

    [[ -f "${src_dir}/coc-settings.json" ]] && {
        mkdir -p "${HOME}/.vim"
        local target_file="${HOME}/.vim/coc-settings.json"
        local src_file="${src_dir}/coc-settings.json"

        if ! _check_java_version; then
            jdk_home=$(_find_latest_jdk)
            if [[ -n "$jdk_home" ]]; then
                sed 's#"inlayHint.enable": true,#&\n   "xml.java.home": "'"$jdk_home"'",#' \
                    "$src_file" > "$target_file"
            else
                cp -af "$src_file" "$target_file"
            fi
        else
            cp -af "$src_file" "$target_file"
        fi

        chmod 644 "$target_file"
    }

    [[ -f "${src_dir}/.vimrc" ]] && cp -af "${src_dir}/.vimrc" "${HOME}/"
    [[ -d "${src_dir}/.c_cpp" ]] && {
        mkdir -p "${HOME}/.vim"
        cp -af "${src_dir}/.c_cpp" "${HOME}/.vim/"
    }
    [[ -f "${src_dir}/.zshrc" ]] && cp -af "${src_dir}/.zshrc" "${HOME}/"
    [[ -f "${src_dir}/ys_modified.zsh-theme" ]] && {
        mkdir -p "${HOME}/.oh-my-zsh/custom"
        cp -af "${src_dir}/ys_modified.zsh-theme" "${HOME}/.oh-my-zsh/custom/"
    }
    [[ -f "${src_dir}/init.vim" ]] && {
        mkdir -p "${HOME}/.config/nvim"
        cp -af "${src_dir}/init.vim" "${HOME}/.config/nvim/"
    }
    [[ -f "${src_dir}/.tessent_startup" ]] && cp -af "${src_dir}/.tessent_startup" "${HOME}/"
}

ensure_dracula_konsole() {
    local target="${1:-$HOME/.local/share/konsole/Dracula.colorscheme}"

    if [[ -f "$target" ]]; then
        echo "Dracula theme already installed at: $target"
        return 0
    fi

    echo "Dracula theme not found. Installing..."

    local tmpdir
    tmpdir=$(mktemp -d) || { echo "Failed to create temp dir" >&2; return 1; }

    git clone --depth 1 https://github.com/dracula/konsole "$tmpdir/konsole" 2>/dev/null || {
        echo "Failed to clone repository" >&2
        rm -rf "$tmpdir"
        return 1
    }

    mkdir -p "$(dirname "$target")"
    mv "$tmpdir/konsole/Dracula.colorscheme" "$target"
    rm -rf "$tmpdir"

    echo "Dracula theme installed at: $target"
}

function update_codex_skills() {
    local msg="$1"
    cd "$codex_home/skills" || { echo "Failed to enter directory $codex_home/skills"; return 1; }
    if [[ -z "$msg" ]]; then
        echo "No commit message provided, only executing git pull..."
        git pull || { echo "git pull failed"; return 1; }
    else
        echo "Executing full git workflow..."
        git pull || { echo "git pull failed"; return 1; }
        git add . || { echo "git add failed"; return 1; }
        git commit -m "$msg" || { echo "git commit failed"; return 1; }
        git push || { echo "git push failed"; return 1; }
    fi
}

is_remote_ssh() {
    # 1. 必须存在 SSH_CONNECTION 变量（SSH 会话的标志）
    [[ -z "$SSH_CONNECTION" ]] && return 1

    # 2. 提取客户端 IP（第一个字段）
    local client_ip="${SSH_CONNECTION%% *}"

    # 3. 去除可能的 IPv6 作用域（如 fe80::1%eth0 -> fe80::1）
    client_ip="${client_ip%\%*}"

    # 4. 检查是否为本地回环地址
    case "$client_ip" in
        127.0.0.1|::1|localhost|127.*)
            return 1  # 本地连接
            ;;
        *)
            return 0  # 远程连接
            ;;
    esac
}
