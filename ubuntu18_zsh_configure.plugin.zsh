# Initialize some envs
export LIBRARY_PATH=$LIBRARY_PATH # for compile-time linking, including static libraries and dynamic libraries
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH # for load-time linking, merely including dynamic libraries
export C_INCLUDE_PATH=$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH
export XDG_DATA_DIRS=$XDG_DATA_DIRS # for showing icons
export XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP # for showing icons
# Prevent exe files from appearing in auto-completion
FIGNORE=".exe"
setopt extended_glob  # Enable Zsh extended globbing



# Congifure git
export GIT_AUTHOR_NAME="Huaxiao Liang"
export GIT_AUTHOR_EMAIL="hxliang666@qq.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_EDITOR="gvim"
export GIT_EXTERNAL_DIFF='gvimdiff'



# Set vi-mode of terminal
VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
MODE_INDICATOR="%F{white}<<<%f"



# Add env
[[ -d "/usr/local/bin" && ":$PATH:" != *":/usr/local/bin:"* ]] && PATH="$PATH:/usr/local/bin"
[[ -d "/usr/lib" && ":$LD_LIBRARY_PATH:" != *":/usr/lib:"* ]] && LD_LIBRARY_PATH="/usr/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
[[ -d "/usr/local/lib" && ":$LD_LIBRARY_PATH:" != *":/usr/local/lib:"* ]] && LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
[[ -d "/usr/lib" && ":$LIBRARY_PATH:" != *":/usr/lib:"* ]] && LIBRARY_PATH="/usr/lib${LIBRARY_PATH:+:${LIBRARY_PATH}}"
[[ -d "/usr/local/lib" && ":$LIBRARY_PATH:" != *":/usr/local/lib:"* ]] && LIBRARY_PATH="/usr/local/lib:$LIBRARY_PATH"
[[ -d "/usr/share" && ":$XDG_DATA_DIRS:" != *":/usr/share:"* ]] && XDG_DATA_DIRS="/usr/share${XDG_DATA_DIRS:+:${XDG_DATA_DIRS}}"
[[ -d "/usr/local/share" && ":$XDG_DATA_DIRS:" != *":/usr/local/share:"* ]] && XDG_DATA_DIRS="/usr/local/share:$XDG_DATA_DIRS"
if [ -s "$HOME/.local" ]; then
  [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
  [[ -d "$HOME/.local/lib" && ":$LD_LIBRARY_PATH:" != *":$HOME/.local/lib:"* ]] && LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
  [[ -d "$HOME/.local/lib" && ":$LIBRARY_PATH:" != *":$HOME/.local/lib:"* ]] && LIBRARY_PATH="$HOME/.local/lib:$LIBRARY_PATH"
  [[ -d "$HOME/.local/share" && ":$XDG_DATA_DIRS:" != *":$HOME/.local/share:"* ]] && XDG_DATA_DIRS="$HOME/.local/share:$XDG_DATA_DIRS"
fi
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



# Personal functions
find_root_path() {
  # Step 1: Define an array of root patterns
  local root_patterns=(".git" ".hg" ".projections.json" ".project" ".svn" ".root" ".vscode" "SConstruct")
  local current_path="$PWD"

  # Step 2: Traverse up to the root
  while [[ "$current_path" != "$HOME" && "$current_path" != "/home/$SUDO_USER" && "$current_path" != "/" ]]; do
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
  local source_path="$HOME/.vim/.c_cpp"
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



# Set ROS melodic
if [ -x "/opt/ros/melodic/setup.zsh" ]; then
  source /opt/ros/melodic/setup.zsh
  export ROS_HOSTNAME=$(hostname -I | awk '{print $1}')
  export ROS_MASTER_URI=http://${ROS_HOSTNAME}:11311
fi
if [ -x "$HOME/catkin_ws/devel/setup.zsh" ]; then
  source $HOME/catkin_ws/devel/setup.zsh
fi
if [ -x "$HOME/study_ws/devel/setup.zsh" ]; then
  source $HOME/study_ws/devel/setup.zsh
fi



# Set MATLAB
if [ -d $HOME/Polyspace/R2021a/bin ]; then
  alias matlab='$HOME/Polyspace/R2021a/bin/matlab >/dev/null 2>&1 &'
fi



# Set CUDA
if [ -d /usr/local/cuda ]; then
  [[ -d "/usr/local/cuda/bin" && ":$PATH:" != *":/usr/local/cuda/bin:"* ]] && PATH="/usr/local/cuda/bin:$PATH"
  [[ -d "/usr/local/cuda/lib64" && ":$LD_LIBRARY_PATH:" != *":/usr/local/cuda/lib64:"* ]] && LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
  [[ -d "/usr/local/cuda/lib64/cmake" && ":$CMAKE_PREFIX_PATH:" != *":/usr/local/cuda/lib64/cmake:"* ]] && CMAKE_PREFIX_PATH="/usr/local/cuda/lib64/cmake${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
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
  if [ ! -s "$HOME/.local/.go" ]; then
    mkdir $HOME/.local/.go -p
  fi
  [[ -d "$HOME/.local/.go" && ":$GOPATH:" != *":$HOME/.local/.go:"* ]] && export GOPATH="$HOME/.local/.go${GOPATH:+:${GOPATH}}"
  [[ -d "${GOPATH//://bin:}/bin" && ":$PATH:" != *":${GOPATH//://bin:}/bin:"* ]] && PATH="${GOPATH//://bin:}/bin:$PATH"
  export GO111MODULE=on
  # Set the GOPROXY environment variable
  export GOPROXY=https://goproxy.io,direct
  # Set environment variable allow bypassing the proxy for specified repos (optional)
  # export GOPRIVATE=git.mycompany.com,github.com/my/private
fi



# Set Cargo
if [ -s "$HOME/.cargo" ]; then
  [[ -d "$HOME/.cargo/bin" && ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && PATH="$HOME/.cargo/bin:$PATH"
fi
if command -v zoxide >/dev/null 2>&1;then
  eval "$(zoxide init zsh)"
fi



# Support wsl2 gui applications
if grep -q WSL2 /proc/version; then
  export DISPLAY=:0
  # For wsl2 vscode
  export DONT_PROMPT_WSL_INSTALL=1
  # Disable Wayland
  export GDK_BACKEND=x11
  unset WAYLAND_DISPLAY
fi



# Perl settings
if command -v perl > /dev/null 2>&1; then
  if [ ! -d $HOME/.local/perl5 ]; then
    mkdir $HOME/.local/perl5 -p
  fi
  [[ -d "$HOME/.local/perl5/bin" && ":$PATH:" != *":$HOME/.local/perl5/bin:"* ]] && PATH="$HOME/.local/perl5/bin:$PATH"
  [[ -d "$HOME/.local/perl5/lib" && ":$PERL5LIB:" != *":$HOME/.local/perl5/lib:"* ]] && export PERL5LIB="$HOME/.local/perl5/lib${PERL5LIB:+:${PERL5LIB}}"
  [[ -d "$HOME/.local/perl5/lib/perl5" && ":$PERL5LIB:" != *":$HOME/.local/perl5/lib/perl5:"* ]] && export PERL5LIB="$HOME/.local/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
  [[ -d "$HOME/.local/perl5" && ":$PERL_LOCAL_LIB_ROOT:" != *":$HOME/.local/perl5:"* ]] && export PERL_LOCAL_LIB_ROOT="$HOME/.local/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
  PERL_MB_OPT="--install_base \"$HOME/.local/perl5\""; export PERL_MB_OPT;
  PERL_MM_OPT="INSTALL_BASE=$HOME/.local/perl5"; export PERL_MM_OPT;
  alias cpanm="cpanm --local-lib=$HOME/.local/perl5"
  alias pldb="perl -Mdiagnostics"
fi



# Qt6 settings
if [ -d $HOME/.Qt6 ]; then
  export Qt6_DIR=$HOME/.Qt6   # Replace with your Qt install path
  export PATH=$Qt6_DIR/Tools/QtCreator/bin:$PATH
  for dir in $Qt6_DIR/*/gcc_64; do
    [[ -d "$dir" && ":$PATH:" != *":$dir/bin:"* ]] && PATH="$dir/bin:$PATH"
    [[ -d "$dir" && ":$LIBRARY_PATH:" != *":$dir/lib:"* ]] && LIBRARY_PATH="$dir/lib:$LIBRARY_PATH"
    [[ -d "$dir" && ":$LD_LIBRARY_PATH:" != *":$dir/lib:"* ]] && LD_LIBRARY_PATH="$dir/lib:$LD_LIBRARY_PATH"
    # Affect not only gcc default options but also g++ default options; Always -I all path listed in C_INCLUDE_PATH
    [[ -d "$dir" && ":$C_INCLUDE_PATH:" != *":$dir/include:"* ]] && C_INCLUDE_PATH="$dir/include${C_INCLUDE_PATH:+:${C_INCLUDE_PATH}}"
    # Affect g++ default options; Always -I all path listed in CPLUS_INCLUDE_PATH
    # [[ -d "$dir" && ":$CPLUS_INCLUDE_PATH:" != *":$dir/include:"* ]] && CPLUS_INCLUDE_PATH="$dir/include${CPLUS_INCLUDE_PATH:+:${CPLUS_INCLUDE_PATH}}"
    [[ -d "$dir" && ":$CMAKE_PREFIX_PATH:" != *":$dir/lib/cmake:"* ]] && CMAKE_PREFIX_PATH="$dir/lib/cmake${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
  done
  # for dir in $Qt6_DIR/*/gcc_64/include/*; do
  #   [[ -d "$dir" && ":$C_INCLUDE_PATH:" != *":$dir:"* ]] && C_INCLUDE_PATH="$dir:$C_INCLUDE_PATH"
  #   [[ -d "$dir" && ":$CPLUS_INCLUDE_PATH:" != *":$dir:"* ]] && CPLUS_INCLUDE_PATH="$dir:$CPLUS_INCLUDE_PATH"
  # done
  export QT_QPA_PLATFORM=xcb # Not use wayland
  if [[ -f /etc/os-release ]] && grep -q "openSUSE" /etc/os-release; then
    export QT_XCB_GL_INTEGRATION=none
  fi
fi



# Mentor  settings
if [[ -d /EDA/library ]]; then
  export LD_LIBRARY_PATH=/EDA/library/lib:$LD_LIBRARY_PATH
fi
if [[ -d $HOME/tessent_2023 ]]; then
  export Mentor_Dir=$HOME/tessent_2023
  export MGLS_LICENSE_FILE=$Mentor_Dir/license/license.dat
  export MGC_LICENSE_FILE=$Mentor_Dir/license/license.dat
  export LM_LICENSE_FILE=$Mentor_Dir/license/license.dat
  if [[ -d $Mentor_Dir/calibre ]]; then
    export CALIBRE_HOME=$Mentor_Dir/calibre
  fi
  setopt extended_glob  # Enable Zsh extended globbing
  for dir in $Mentor_Dir/^(*[0-9]*)/bin; do
    [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
  done
fi
if [[ -d /EDA/Mentor ]]; then
  export Mentor_Dir=/EDA/Mentor
  export MGLS_LICENSE_FILE=$Mentor_Dir/license/license.dat
  export MGC_LICENSE_FILE=$Mentor_Dir/license/license.dat
  export LM_LICENSE_FILE=$Mentor_Dir/license/license.dat
  if [[ -d $Mentor_Dir/calibre ]]; then
    export CALIBRE_HOME=$Mentor_Dir/calibre
  fi
  for dir in $Mentor_Dir/^(*[0-9]*)/bin; do
    [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
  done
fi



# Synopsys settings
if [[ -d /EDA/Synopsys ]]; then
  export Synopsys_Dir=/EDA/Synopsys
  export SNPSLMV_LICENSE_FILE=27000@Banana
  export LM_LICENSE_FILE=27000@Banana
  export SNPSLMD_LICENSE_FILE=$Synopsys_Dir/license/Synopsys.dat
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
    alias load_syn="$SCL_HOME/linux64/bin/lmgrd -c $SNPSLMD_LICENSE_FILE"
  fi
  for dir in $Synopsys_Dir/^(*[0-9]*)/^(*[0-9]*)/bin; do
    [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
  done
fi



# Alias pip3
for dir in $HOME/.local/lib/python3*/site-packages; do
  if [[ -d $dir/pip ]]; then
    alias pip='python3 -m pip'
    alias pip3='python3 -m pip'
  fi
done
