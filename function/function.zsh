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
function add_to_env_var() {
    local var_name="$1"
    local new_path="$2"
    local position="${3:-before}"

    # 判断路径是否存在
    if [[ ! -d "$new_path" ]]; then
        return 1
    fi

    case "$position" in
        before|前面|前|after|后面|后) ;;
        *) return 1 ;;
    esac

    # zsh 原生间接引用方式
    local current_value="${(P)var_name}"

    # 已存在的路径不重复添加，也不改变已有顺序
    if [[ ":$current_value:" == *":$new_path:"* ]]; then
        export "$var_name=$current_value"
        return 0
    fi

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
    esac

    return 0
}
# 使用示例：
# add_to_env_var "PATH" "/usr/local/bin" "before"
# add_to_env_var "LD_LIBRARY_PATH" "/opt/lib" "after"
function add_to_multiple_env_vars() {
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
function find_root_path() {
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
        current_path="${current_path:h}"
    done

    # Step 3: If no match, return the current path and echo a message
    echo "$PWD"
    echo "Warning: You had better create a root-pattern file like .git in your project." >&2
    return 1
}

function check_and_copy_file() {
    local source_path="${HOME}/.vim/.c_cpp"
    local workspace_path="$1"
    local file_name="$2"

    # Check if the file exists in the current workspace
    if [[ -e "$workspace_path/$file_name" ]]; then
        echo "File $workspace_path/$file_name has existed."
    elif [[ -e "$source_path/$file_name" ]]; then
        # If the file exists in the specific path, copy it to the current workspace
        mkdir -p -- "$workspace_path/${file_name:h}" || return 1
        cp -- "$source_path/$file_name" "$workspace_path/$file_name" || return 1
    else
        # If the file doesn't exist in either location
        echo "Warning: File $source_path/$file_name and $workspace_path/$file_name file do not exist." >&2
        return 1
    fi
    return 0
}

function configure() {
    emulate -L zsh
    local action="$1"
    local workspace_path file
    local -a files
    case "$action" in
        clang)
            files=(.clangd .clang-format .clang-tidy)
            ;;
        vscode)
            files=(.vscode/launch.json)
            ;;
        vimspector)
            files=(.vimspector.json)
            ;;
        dbg)
            files=(.vscode/launch.json .vimspector.json)
            ;;
        all)
            files=(.clangd .clang-format .clang-tidy .vscode/launch.json .vimspector.json)
            ;;
        "")
            files=(.clangd .clang-format .clang-tidy .vimspector.json)
            ;;
        *)
            echo "Invalid argument: '$action'. Please specify clang, vscode, vimspector, dbg, all or \"\"." >&2
            return 1
            ;;
    esac

    # find_root_path 在未找到项目标记时仍输出当前目录，保留这个回退行为
    workspace_path=$(find_root_path)
    [[ -d "$workspace_path" ]] || return 1
    for file in "${files[@]}"; do
        check_and_copy_file "$workspace_path" "$file" || return 1
    done
    if [[ "${files[-1]}" == .vimspector.json ]]; then
        gvim "$workspace_path/.vimspector.json" || return 1
    fi
    return 0
}



function backup_terminal_config() {
    local base_dir="${1:-${HOME}/configuration_file}"
    local qt_version="${2:-$(ldd "$(command -v konsole)" 2>/dev/null | grep -oE 'libQt[56]Core\.so' | head -1)}"
    qt_version="${qt_version#libQt}"; qt_version="${qt_version%Core.so}"
    local backup_dir="${base_dir}/terminal_backup_Qt_${qt_version}"

    [[ ! -d "${base_dir}" ]] && { echo "ERROR：${base_dir} does not exist" >&2; return 1 }
    mkdir -p "${backup_dir}" || return 1

    [[ -f "${HOME}/.config/terminator/config" ]] && {
        mkdir -p "${backup_dir}/terminator" || return 1
        cp -af "${HOME}/.config/terminator/config" "${backup_dir}/terminator/" || return 1
    }

    [[ -f "${HOME}/.config/konsolerc" ]] && {
        mkdir -p "${backup_dir}/konsole" || return 1
        cp -af "${HOME}/.config/konsolerc" "${backup_dir}/konsole/" || return 1
    }

    [[ -d "${HOME}/.local/share/konsole" ]] && {
        mkdir -p "${backup_dir}/konsole/share-konsole" || return 1
        cp -af "${HOME}/.local/share/konsole/." "${backup_dir}/konsole/share-konsole/" || return 1
    }
    return 0
}

function restore_terminal_config() {
    local base_dir="${1:-${HOME}/configuration_file}"
    local qt_version="${2:-$(ldd "$(command -v konsole)" 2>/dev/null | grep -oE 'libQt[56]Core\.so' | head -1)}"
    qt_version="${qt_version#libQt}"; qt_version="${qt_version%Core.so}"
    local backup_dir="${base_dir}/terminal_backup_Qt_${qt_version}"

    [[ ! -d "${backup_dir}" ]] && { echo "ERROR：${backup_dir} does not exist" >&2; return 1 }

    [[ -f "${backup_dir}/terminator/config" ]] && {
        mkdir -p "${HOME}/.config/terminator" || return 1
        cp -af "${backup_dir}/terminator/config" "${HOME}/.config/terminator/" || return 1
    }

    [[ -f "${backup_dir}/konsole/konsolerc" ]] && {
        mkdir -p "${HOME}/.config" || return 1
        cp -af "${backup_dir}/konsole/konsolerc" "${HOME}/.config/" || return 1
    }

    [[ -d "${backup_dir}/konsole/share-konsole" ]] && {
        mkdir -p "${HOME}/.local/share/konsole" || return 1
        cp -af "${backup_dir}/konsole/share-konsole/." "${HOME}/.local/share/konsole/" || return 1
    }
    return 0
}

# 提取 java -version 中的版本字符串，保留更新号和构建后缀
function _java_version_string() {
    emulate -L zsh
    unsetopt bash_rematch
    local MATCH MBEGIN MEND
    local -a match mbegin mend
    [[ "$1" =~ '(^|[[:space:]])(openjdk|java)[[:space:]]+(version[[:space:]]+)?"?([0-9]+([._][0-9]+)*([-+][[:alnum:]._-]+)?)("|[[:space:]]|$)' ]] || return 1
    print -r -- "${match[4]}"
}

# 辅助：在 /usr/lib/jvm 中找可用的 JDK 根目录
# 优先级：目录名含 latest > 版本号最大（支持 jre-*/bin/java）
function _find_latest_jdk() {
    emulate -L zsh
    [[ -d /usr/lib/jvm ]] || return 1
    local latest_dir
    latest_dir=$(find /usr/lib/jvm -maxdepth 1 -type d -name '*latest*' 2>/dev/null | head -1)
    if [[ -n "$latest_dir" ]]; then
        readlink -f "$latest_dir" 2>/dev/null || print -r -- "$latest_dir"
        return 0
    fi

    local d java_bin canonical_java output ver best_ver
    local -A cached_versions homes_by_version
    for d in /usr/lib/jvm/*(N); do
        java_bin="$d/bin/java"
        [[ -x "$java_bin" ]] || java_bin="$d/jre/bin/java"
        [[ -x "$java_bin" ]] || continue
        canonical_java="${java_bin:A}"
        if (( ${+cached_versions[$canonical_java]} )); then
            ver="${cached_versions[$canonical_java]}"
        else
            cached_versions[$canonical_java]=""
            output=$("$java_bin" -version 2>&1) || continue
            ver=$(_java_version_string "$output") || continue
            cached_versions[$canonical_java]="$ver"
        fi
        [[ -n "$ver" ]] || continue
        # 相同版本保留最后匹配的路径，包括原有的 JRE 链接路径
        homes_by_version[$ver]="$d"
    done

    (( ${#homes_by_version} )) || return 1
    # 保留 sort -V 的比较规则，所有版本只排序一次
    best_ver=$(print -rl -- "${(@k)homes_by_version}" | sort -V | tail -1)
    print -r -- "${homes_by_version[$best_ver]}"
}

# 辅助：检查 PATH 中当前 java 是否 >= 11，不受其他已安装版本影响
function _check_java_version() {
    emulate -L zsh
    local output ver major
    output=$(java -version 2>&1) || return 1
    ver=$(_java_version_string "${output%%$'\n'*}") || return 1
    [[ "$ver" == 1.* ]] && ver="${ver#1.}"
    major="${ver%%[^0-9]*}"
    (( 10#$major >= 11 ))
}

function backup_linux_config() {
    local dest_dir="${1:-${HOME}/configuration_file}"

    if [[ ! -d "${dest_dir}" ]]; then
        mkdir -p "${dest_dir}" || return 1
    fi

    [[ -f "${HOME}/.gdbinit" ]] && {
        mkdir -p "${dest_dir}/others" || return 1
        # 把所有 gcc 相关路径替换为统一占位符
        sed 's|sys\.path\.insert(0, '\''/[^'\'']*gcc[^'\'']*/python'\'')|sys.path.insert(0, '\''__GCC_PYTHON_PATH__'\'')|g' "${HOME}/.gdbinit" > "${dest_dir}/others/.gdbinit" || return 1
    }

    [[ -f "${HOME}/.vim/coc-settings.json" ]] && {
        mkdir -p "${dest_dir}/vim" || return 1
        sed '/"xml\.java\.home"/d' "${HOME}/.vim/coc-settings.json" > "${dest_dir}/vim/coc-settings.json" || return 1
    }
    [[ -f "${HOME}/.vim/vimrc" ]] && { mkdir -p "${dest_dir}/vim" || return 1; cp -aTf "${HOME}/.vim/vimrc" "${dest_dir}/vim/vimrc" || return 1; }
    [[ -d "${HOME}/.vim/.c_cpp" ]] && { mkdir -p "${dest_dir}/vim" || return 1; cp -af "${HOME}/.vim/.c_cpp" "${dest_dir}/vim/" || return 1; }
    [[ -f "${HOME}/.zshrc" ]] && { mkdir -p "${dest_dir}/shell" || return 1; cp -af "${HOME}/.zshrc" "${dest_dir}/shell/" || return 1; }
    [[ -f "${HOME}/.oh-my-zsh/custom/ys_modified.zsh-theme" ]] && { mkdir -p "${dest_dir}/shell" || return 1; cp -af "${HOME}/.oh-my-zsh/custom/ys_modified.zsh-theme" "${dest_dir}/shell/" || return 1; }
    [[ -f "${HOME}/.config/nvim/init.vim" ]] && { mkdir -p "${dest_dir}/vim" || return 1; cp -af "${HOME}/.config/nvim/init.vim" "${dest_dir}/vim/" || return 1; }
    [[ -f "${HOME}/.tessent_startup" ]] && { mkdir -p "${dest_dir}/others" || return 1; cp -af "${HOME}/.tessent_startup" "${dest_dir}/others/" || return 1; }
    return 0
}

# 优先检查标准 GCC 布局，非标准安装保留原来的 find 回退
function _find_gcc_python_path() {
    emulate -L zsh
    local printer_path fallback_path
    for printer_path in /usr/share/gcc*/python/libstdcxx/v6/printers.py(-.NoN); do
        print -r -- "${printer_path%/libstdcxx/v6/printers.py}"
        return 0
    done
    printer_path=$(find /usr/share -path '*/libstdcxx/v6/printers.py' 2>/dev/null | head -1)
    if [[ -n "$printer_path" ]]; then
        print -r -- "${printer_path%/libstdcxx/v6/printers.py}"
        return 0
    fi
    fallback_path=$(find /usr/share -maxdepth 4 -type d -name 'python' -path '*/gcc*' 2>/dev/null | head -1)
    [[ -n "$fallback_path" ]] || return 1
    print -r -- "$fallback_path"
}

function restore_linux_config() {
    local src_dir="${1:-${HOME}/configuration_file}"

    [[ ! -d "${src_dir}" ]] && { echo "ERROR：${src_dir} does not exist" >&2; return 1 }

    [[ -f "${src_dir}/others/.gdbinit" ]] && {
        local gcc_python_path
        gcc_python_path=$(_find_gcc_python_path)
        if [[ -n "${gcc_python_path}" ]]; then
            sed "s|__GCC_PYTHON_PATH__|${gcc_python_path}|g" "${src_dir}/others/.gdbinit" > "${HOME}/.gdbinit" || return 1
        else
            cp -af "${src_dir}/others/.gdbinit" "${HOME}/" || return 1
            echo "Warning: Could not find GCC python path, using default .gdbinit" >&2
        fi
    }

    [[ -f "${src_dir}/vim/coc-settings.json" ]] && {
        mkdir -p "${HOME}/.vim" || return 1
        local target_file="${HOME}/.vim/coc-settings.json" jdk_home
        local src_file="${src_dir}/vim/coc-settings.json"

        if ! _check_java_version; then
            jdk_home=$(_find_latest_jdk)
            if [[ -n "$jdk_home" ]]; then
                sed 's#"inlayHint.enable": true,#&\n   "xml.java.home": "'"$jdk_home"'",#' \
                    "$src_file" > "$target_file" || return 1
            else
                cp -af "$src_file" "$target_file" || return 1
            fi
        else
            cp -af "$src_file" "$target_file" || return 1
        fi

        chmod 644 "$target_file" || return 1
    }

    [[ -f "${src_dir}/vim/vimrc" ]] && { mkdir -p "${HOME}/.vim" || return 1; cp -aTf "${src_dir}/vim/vimrc" "${HOME}/.vim/vimrc" || return 1; }
    [[ -d "${src_dir}/vim/.c_cpp" ]] && {
        mkdir -p "${HOME}/.vim" || return 1
        cp -af "${src_dir}/vim/.c_cpp" "${HOME}/.vim/" || return 1
    }
    [[ -f "${src_dir}/shell/.zshrc" ]] && { cp -af "${src_dir}/shell/.zshrc" "${HOME}/" || return 1; }
    [[ -f "${src_dir}/shell/ys_modified.zsh-theme" ]] && {
        mkdir -p "${HOME}/.oh-my-zsh/custom" || return 1
        cp -af "${src_dir}/shell/ys_modified.zsh-theme" "${HOME}/.oh-my-zsh/custom/" || return 1
    }
    [[ -f "${src_dir}/vim/init.vim" ]] && {
        mkdir -p "${HOME}/.config/nvim" || return 1
        cp -af "${src_dir}/vim/init.vim" "${HOME}/.config/nvim/" || return 1
    }
    [[ -f "${src_dir}/others/.tessent_startup" ]] && { cp -af "${src_dir}/others/.tessent_startup" "${HOME}/" || return 1; }
    return 0
}

function ensure_dracula_konsole() {
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
    local repo_url="git@gitee.com:banana33/skills.git"
    (
        # Ensure the parent directory exists
        mkdir -p "${CODEX_HOME}" || { echo "Failed to create ${CODEX_HOME}"; exit 1; }
        # Case 1: skills directory does not exist at all → just clone directly
        if [[ ! -d "${CODEX_HOME}/skills" ]]; then
            echo "Skills directory does not exist. Cloning repository..."
            git clone "$repo_url" "${CODEX_HOME}/skills" || { echo "git clone failed"; exit 1; }
            cd "${CODEX_HOME}/skills" || exit 1
        else
            cd "${CODEX_HOME}/skills" || exit 1
            # Case 2: skills directory exists but is NOT a git repository
            if ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo "Skills directory exists but is not a git repo. Initializing..."
                # Clone into a temp directory first (git clone won't overwrite non-empty dirs)
                local tmpdir
                tmpdir="$(mktemp -d)" || { echo "Failed to create temp dir"; exit 1; }
                git clone "$repo_url" "$tmpdir" || { echo "git clone failed"; exit 1; }
                # Move .git into the existing skills directory
                mv "$tmpdir/.git" . || { echo "Failed to move .git"; exit 1; }
                # Restore tracked files (overwrites local files with repo versions)
                git checkout -- . 2>/dev/null
                # Clean up temp directory
                rm -rf "$tmpdir"
                echo "Repository initialized successfully."
            fi
            # Case 3: already a git repo → fall through to normal workflow below
        fi
        # --- From this point, skills/ is guaranteed to be a git repository ---
        if [[ -z "$msg" ]]; then
            # No commit message → only pull the latest changes
            echo "No commit message provided, only executing git pull..."
            git pull || { echo "git pull failed"; exit 1; }
        else
            # Full workflow: add → commit → pull --rebase → push
            echo "Executing full git workflow..."
            # Check if there are any changes to commit
            if ! git status --porcelain | grep -q .; then
                echo "No changes detected. Skipping add/commit."
                git pull || { echo "git pull failed"; exit 1; }
                exit 0
            fi
            git add . || { echo "git add failed"; exit 1; }
            git commit -m "$msg" || { echo "git commit failed"; exit 1; }
            git pull --rebase || { echo "git pull failed"; exit 1; }
            git push || { echo "git push failed"; exit 1; }
        fi
    )
    return $?
}

function status_codex_skills() {
    local msg="$1"
    (
        cd "${CODEX_HOME}/skills" || { echo "Failed to enter directory ${CODEX_HOME}/skills"; exit 1; }
        git status
    )
    return $?
}

function is_remote_ssh() {
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

# Ensure that [tui] section in Codex config.toml contains:
#   vim_mode_default = true
#   vim_mode_initial_state = "insert"
#   vim_mode_after_submit = "insert"
# Usage: ensure_codex_vim [config_path]
# If no argument given, defaults to ${CODEX_HOME}/config.toml
function ensure_codex_vim() {
    emulate -L zsh
    local config="${1:-${CODEX_HOME}/config.toml}"
    # Resolve symlinks before replacing the target with a sibling temporary file.
    config="${config:A}"
    [[ -e "$config" && ! -f "$config" ]] && return 1
    local temporary
    mkdir -p -- "${config:h}" || return 1
    temporary=$(mktemp "${config}.tmp.XXXXXXXX") || return 1

    # If file does not exist, create it with the desired config
    if [[ ! -f "$config" ]]; then
        cat > "$temporary" <<-'EOF'
[tui]
vim_mode_default = true
vim_mode_initial_state = "insert"
vim_mode_after_submit = "insert"
EOF
        if (( $? != 0 )) || ! mv -f -- "$temporary" "$config"; then
            rm -f -- "$temporary"
            return 1
        fi
        echo "[OK] Created $config with default vim settings"
        return 0
    fi

    cp -p -- "$config" "$temporary" || { rm -f -- "$temporary"; return 1; }
    # Track strings and collections so their contents cannot look like tables.
    awk '
    BEGIN {
        literal = sprintf("%c", 39)
        basic_multi = "\"\"\""
        literal_multi = literal literal literal
        keys[1] = "vim_mode_default"
        keys[2] = "vim_mode_initial_state"
        keys[3] = "vim_mode_after_submit"
        values[keys[1]] = "true"
        values[keys[2]] = values[keys[3]] = "\"insert\""
    }

    function scan(line, i, c, triple) {
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            triple = substr(line, i, 3)
            if (quote != "") {
                if (c == "\\" && (quote == "\"" || quote == basic_multi)) {
                    i++
                } else if (length(quote) == 3 && triple == quote) {
                    i += 2
                    # Four/five closing quotes include quotes in the value.
                    while (substr(line, i + 1, 1) == c) i++
                    quote = ""
                } else if (length(quote) == 1 && c == quote) {
                    quote = ""
                }
            } else if (c == "#") {
                return i
            } else if (triple == basic_multi || triple == literal_multi) {
                quote = triple
                i += 2
            } else if (c == "\"" || c == literal) {
                quote = c
            } else if (c == "[" || c == "{") {
                depth++
            } else if (c == "]" || c == "}") {
                depth--
            }
        }
        return length(line) + 1
    }

    function missing_keys(i) {
        for (i = 1; i <= 3; i++)
            if (!seen[keys[i]]) print keys[i] " = " values[keys[i]]
    }

    function bare_name(name, delimiter) {
        sub(/^[ \t]*/, "", name)
        sub(/[ \t\r]*$/, "", name)
        delimiter = substr(name, 1, 1)
        if ((delimiter == "\"" || delimiter == literal) && substr(name, length(name), 1) == delimiter)
            name = substr(name, 2, length(name) - 2)
        return name
    }

    {
        continuation = (quote != "" || depth != 0)
        comment = scan($0)
        if (skipping) {
            if (comment <= length($0)) print substr($0, comment)
            skipping = (quote != "" || depth != 0)
            next
        }
        if (!continuation && /^[ \t]*\[.*\][ \t\r]*(#.*)?$/) {
            if (in_tui) missing_keys()
            header = substr($0, 1, comment - 1)
            sub(/^[ \t]*\[/, "", header)
            sub(/\][ \t\r]*$/, "", header)
            in_tui = (bare_name(header) == "tui")
            if (in_tui) tui_found = 1
        }
        key = $0
        sub(/=.*/, "", key)
        key = bare_name(key)
        if (in_tui && !continuation && index($0, "=") && (key in values)) {
            if (!seen[key]++) {
                match($0, /^[^=]*=[ \t]*/)
                suffix = (comment <= length($0) ? " " substr($0, comment) : "")
                print substr($0, 1, RLENGTH) values[key] suffix
            }
            skipping = (quote != "" || depth != 0)
            next
        }
        print $0
    }
    END {
        if (!tui_found) {
            print "[tui]"
            missing_keys()
        } else if (in_tui) {
            missing_keys()
        }
    }
    ' "$config" > "$temporary"
    if (( $? != 0 )) || ! mv -f -- "$temporary" "$config"; then
        rm -f -- "$temporary"
        return 1
    fi

    echo "[OK] Configuration updated (if needed)"
}

function restore_stable_configuration() {
    git config --global user.name ${GIT_AUTHOR_NAME}
    git config --global user.email ${GIT_AUTHOR_EMAIL}
    git config --global alias.logline "log --graph --abbrev-commit"
    git config --global core.editor gvim
    git config --global protocol.https.allow always
    git config --global push.default "current"
}

function scodex() {
    local codex_home="${CODEX_HOME:-$HOME/.codex}"
    local config="${codex_home}/config.toml"
    local current
    local choice

    if [ ! -f "$config" ]; then
        echo "Error: config file not found: $config" >&2
        return 1
    fi

    # Detect current mode
    if grep -q '^model_provider[[:space:]]*=[[:space:]]*"custom"[[:space:]]*$' "$config"; then
        current="token"
    elif grep -q '^#[[:space:]]*model_provider[[:space:]]*=[[:space:]]*"custom"[[:space:]]*$' "$config"; then
        current="account"
    else
        echo 'Error: cannot find model_provider = "custom" in:' >&2
        echo "  $config" >&2
        return 1
    fi

    echo
    echo "Current Codex mode: $current"
    echo
    echo "  1 / t) token"
    echo "  2 / a) account"
    echo "  Enter) keep current mode ($current)"
    echo

    printf "Select [1/2/t/a/Enter]: "
    IFS= read -r choice

    case "$choice" in
        "")
            echo "Using $current"
            ;;

        1|t|T|token|Token|TOKEN)
            sed -i 's/^#[[:space:]]*model_provider[[:space:]]*=[[:space:]]*"custom"[[:space:]]*$/model_provider = "custom"/' "$config"
            echo "Using token"
            ;;

        2|a|A|account|Account|ACCOUNT)
            sed -i 's/^model_provider[[:space:]]*=[[:space:]]*"custom"[[:space:]]*$/# model_provider = "custom"/' "$config"
            echo "Using account"
            ;;

        *)
            echo "Invalid selection: $choice" >&2
            return 1
            ;;
    esac

    command codex "$@"
}
