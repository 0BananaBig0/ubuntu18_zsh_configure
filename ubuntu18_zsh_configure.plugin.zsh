# *.plugin.zsh - Main entry point
# Get the directory where this script is located
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
PLUGIN_DIR="${0:h}"
# Method 1: Source all scripts from lib directory
for script in "${PLUGIN_DIR}"/function/*.zsh(.N); do
    source "${script}"
done



# Initialize some envs
export LIBRARY_PATH=$LIBRARY_PATH # for compile-time linking, including static libraries and dynamic libraries
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH # for load-time linking, merely including dynamic libraries
export C_INCLUDE_PATH=$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH
export XDG_DATA_DIRS=$XDG_DATA_DIRS # for showing icons
export XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP # for showing icons
export PYTHONPATH=$PYTHONPATH # for python -m pip install modules
# Prevent exe files from appearing in auto-completion
FIGNORE=".exe"
setopt extended_glob  # Enable Zsh extended globbing
alias rp='realpath'



# Congifure git
export GIT_AUTHOR_NAME="Huaxiao Liang"
export GIT_AUTHOR_EMAIL="hxliang666@qq.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_EDITOR="gvim"



# Configure codex
export CODEX_HOME="${HOME}/.local/.codex_home/codex"
alias install_codex="sh ${HOME}/.local/bin/install_codex.sh"
export VISUAL="gvim -f"
export EDITOR="gvim -f"


# Set vi-mode of terminal
VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
MODE_INDICATOR="%F{white}<<<%f"



# Add env
add_to_multiple_env_vars "/usr"
add_to_multiple_env_vars "/usr/local"
add_to_multiple_env_vars "${HOME}/.local"
# Check if a desktop environment is currently running by looking for common desktop processes
if ! ps -e | grep -q -E "gnome*|xfce4*"; then
    # Check if any XFCE-related binaries exist (loop through known binaries)
    xfce_binaries=($(find /usr/bin -name 'xfce*'))
    for bin in "${xfce_binaries[@]}"; do
        if command -v "$bin" >/dev/null 2>&1; then
            export XDG_CURRENT_DESKTOP="XFCE"
            break
        fi
    done
    # If no XFCE binaries found, check for GNOME-related binaries (loop through known binaries)
    gnome_binaries=($(find /usr/bin -name 'gnome*'))
    for bin in "${gnome_binaries[@]}"; do
        if command -v "$bin" >/dev/null 2>&1; then
            export XDG_CURRENT_DESKTOP="GNOME"
            break
        fi
    done
    # For some applications, even if you don't have any desktop environment installed,
    # the XDG_CURRENT_DESKTOP variable must not be empty.
    if [ -z "$XDG_CURRENT_DESKTOP" ]; then
        export XDG_CURRENT_DESKTOP="XFCE"
    fi
fi



# Set ROS melodic
if [ -x "/opt/ros/melodic/setup.zsh" ]; then
    source /opt/ros/melodic/setup.zsh
    export ROS_HOSTNAME=$(hostname -I | awk '{print $1}')
    export ROS_MASTER_URI=http://${ROS_HOSTNAME}:11311
fi
if [ -x "${HOME}/catkin_ws/devel/setup.zsh" ]; then
    source ${HOME}/catkin_ws/devel/setup.zsh
fi
if [ -x "${HOME}/study_ws/devel/setup.zsh" ]; then
    source ${HOME}/study_ws/devel/setup.zsh
fi



# Set MATLAB
if [ -d ${HOME}/Polyspace/R2021a/bin ]; then
    alias matlab='${HOME}/Polyspace/R2021a/bin/matlab >/dev/null 2>&1 &'
fi



# Set CUDA
if [ -d /usr/local/cuda ]; then
    add_to_multiple_env_vars "/usr/local/cuda"
    add_to_env_var "CMAKE_PREFIX_PATH" "/usr/local/cuda/lib64/cmake"
fi



# Set vim , gvim, goneovim and gdb
alias vi='vi -p'
alias vim='vim -p'
alias gvim='gvim -p'
alias nvim='nvim -p'
alias gdb='gdb -q'
alias g++s='g++ -S -fverbose-asm'
alias gccs='gcc -S -fverbose-asm'
alias clang++s='clang++ -S -fverbose-asm'
alias clangs='clang -S -fverbose-asm'



# Set Go language
if command -v go > /dev/null 2>&1; then
    if [ ! -s "${HOME}/.local/.go" ]; then
        mkdir ${HOME}/.local/.go -p
    fi
    add_to_env_var "GOPATH" "${HOME}/.local/.go"
    for p in ${(s.:.)GOPATH}; do
        add_to_env_var "PATH" "$p/bin" "before"
    done
    export GO111MODULE=on
    # Set the GOPROXY environment variable
    export GOPROXY=https://goproxy.cn,direct
    export GOSUMDB=sum.golang.google.cn
fi



# Set Cargo
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
export CARGO_HOME="${HOME}/.cargo"
export RUSTUP_HOME="${HOME}/.rustup"
add_to_env_var "PATH" "${HOME}/.cargo/bin"
if command -v zoxide >/dev/null 2>&1;then
    eval "$(zoxide init zsh)"
fi



# Support wsl2 gui applications
if grep -q WSL2 /proc/version; then
    if is_remote_ssh; then
        export DISPLAY=localhost:10.0
    else
        export DISPLAY=:0
    fi
    # For wsl2 vscode
    export DONT_PROMPT_WSL_INSTALL=1
    # Disable Wayland
    export GDK_BACKEND=x11
    unset WAYLAND_DISPLAY
fi



# Perl settings
if command -v perl > /dev/null 2>&1; then
    if [ ! -d ${HOME}/.local/perl5 ]; then
        mkdir ${HOME}/.local/perl5 -p
    fi
    add_to_env_var "PATH" "${HOME}/.local/perl5/bin"
    add_to_env_var "PERL5LIB" "${HOME}/.local/perl5/lib"
    add_to_env_var "PERL5LIB" "${HOME}/.local/perl5/lib/perl5"
    add_to_env_var "PERL_LOCAL_LIB_ROOT" "${HOME}/.local/perl5"
    PERL_MB_OPT="--install_base \"${HOME}/.local/perl5\""; export PERL_MB_OPT;
    PERL_MM_OPT="INSTALL_BASE=${HOME}/.local/perl5"; export PERL_MM_OPT;
    alias cpanm="cpanm --local-lib=${HOME}/.local/perl5"
    alias pldb="perl -Mdiagnostics"
fi



# Qt6 settings
if [ -d ${HOME}/.Qt6 ]; then
    export Qt6_DIR=${HOME}/.Qt6   # Replace with your Qt install path
    add_to_env_var "PATH" "${Qt6_DIR}/Tools/QtCreator/bin"
    for dir in $Qt6_DIR/*/gcc_64; do
        # Affect not only gcc default options but also g++ default options; Always -I all path listed in C_INCLUDE_PATH
        add_to_multiple_env_vars "${dir}"
        add_to_env_var "CMAKE_PREFIX_PATH" "${dir}/lib/cmake"
    done
    export QT_QPA_PLATFORM=xcb # Not use wayland
    if [[ -f /etc/os-release ]] && grep -q "openSUSE" /etc/os-release; then
        export QT_XCB_GL_INTEGRATION=none
    fi
fi



# Mentor  settings
add_to_env_var "LD_LIBRARY_PATH" "/EDA/library/lib"
if [[ -d /EDA/Mentor ]]; then
    export Mentor_Dir=/EDA/Mentor
    export MGLS_LICENSE_FILE=$Mentor_Dir/license/license.dat
    export MGC_LICENSE_FILE=$Mentor_Dir/license/license.dat
    export LM_LICENSE_FILE=$Mentor_Dir/license/license.dat
    add_to_env_var "CALIBRE_HOME" "${Mentor_Dir}/calibre"
    add_to_env_var "QUESTA_HOME" "${Mentor_Dir}/questasim"
    add_to_env_var "TESSENT_HOME" "${Mentor_Dir}/tessent"
    add_to_env_var "OASYS_HOME" "${Mentor_Dir}/oasys"
    for dir in $Mentor_Dir/^(*[0-9]*)/bin; do
        add_to_env_var "PATH" "${dir}"
    done
fi



# Synopsys settings
if [[ -d /EDA/Synopsys ]]; then
    export Synopsys_Dir=/EDA/Synopsys
    export SNPSLMV_LICENSE_FILE=27000@Banana
    export LM_LICENSE_FILE=27000@Banana
    export SNPSLMD_LICENSE_FILE=${Synopsys_Dir}/license/Synopsys.dat
    export LM_LICENSE_FILE=$SNPSLMD_LICENSE_FILE
    if [[ -d $Synopsys_Dir/vcs/vcs ]]; then
        export VCS_HOME=$Synopsys_Dir/vcs/vcs
        export VCS_ARCH_OVERRIDE=linux
        export VCS_TARGET_ARCH="amd64"
        alias vcs64="vcs -full64"
    fi
    if [[ -d $Synopsys_Dir/verdi/verdi ]]; then
        export VERDI_HOME=$Synopsys_Dir/verdi/verdi
        export LD_LIBRARY_PATH=$VERDI_HOME/share/PLI/lib/LINUX64:$LD_LIBRARY_PATH
        export VERDI_DIR=$VERDI_HOME
        alias verdi="verdi -full64 &"
    fi
    if [[ -d $Synopsys_Dir/scl/scl ]]; then
        export SCL_HOME=$Synopsys_Dir/scl/scl
        alias load_syn="$SCL_HOME/linux64/bin/lmgrd -c $SNPSLMD_LICENSE_FILE -l /tmp/syn.debug.log"
    fi
    for dir in $Synopsys_Dir/^(*[0-9]*)/^(*[0-9]*)/bin; do
        [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
    done
fi



# Alias pip3
for dir in ${HOME}/.local/lib/python3*/site-packages; do
    if [[ -d $dir/pip ]]; then
        alias pip='python3 -m pip'
        alias pip3='python3 -m pip'
    fi
done



# Ruby and rbenv configuration
if command -v rbenv > /dev/null 2>&1; then
    if [ ! -s "${HOME}/.rbenv/bin" ]; then
        mkdir ${HOME}/.rbenv/bin -p
    fi
    add_to_env_var "PATH" "${HOME}/.rbenv/bin"
    eval "$(rbenv init - zsh)"
fi



# Set env for eda-rocky8
BOSIOS="/data/bosios"
if [ -d "${BOSIOS}" ]; then
    # Configure nvm and nodejs
    if [ -d "${BOSIOS}/nvm" ]; then
        export NVM_DIR="${BOSIOS}/nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        # 获取所有版本目录，按版本号排序，取最新的
        LATEST_VERSION=$(ls -d ${BOSIOS}/nvm/versions/node/*/ | sort -V | tail -1 | xargs basename)
        NODE_PATH="${BOSIOS}/nvm/versions/node/${LATEST_VERSION}"
        if [ -n "$LATEST_VERSION" ]; then
            NODE_PATH="${NVM_DIR}/${LATEST_VERSION}"
            add_to_multiple_env_vars "${NODE_PATH}"
        fi
    fi
    for OS_PATH in ${BOSIOS}/*; do
        add_to_multiple_env_vars "${OS_PATH}"
    done
    if [ -d "${BOSIOS}/node_modules" ]; then
        for OS_PATH in ${BOSIOS}/node_modules/*; do
            add_to_multiple_env_vars "${OS_PATH}"
        done
        add_to_env_var "PATH" "${BOSIOS}/node_modules/.bin"
    fi

    # Configure python3 pip install
    add_to_env_var "PYTHONPATH" "/data/bosios/python/lib64/python3.12/site-packages"
    add_to_env_var "PYTHONPATH" "/data/bosios/python/lib/python3.12/site-packages"
    alias python3='python3.12'
    alias pip='python3.12 -m pip'
    alias pip3='python3.12 -m pip'

    # Configure eda
    if [[ -s "/data/eda/bashrc/bashrc.eda" ]]; then
        source /data/eda/bashrc/bashrc.eda
    fi
fi
