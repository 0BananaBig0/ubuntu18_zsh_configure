# Initialize some envs
export LIBRARY_PATH=$LIBRARY_PATH # for static libraries
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH # for dynamic libraries
export C_INCLUDE_PATH=$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH
export XDG_DATA_DIRS=$XDG_DATA_DIRS # for showing icons
export XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP # for showing icons



# Set vi-mode of terminal
VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
MODE_INDICATOR="%F{white}<<<%f"



# Add env
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



# Set Go language
if [ -s `which go` ]; then
  if [ ! -s "$HOME/.local/.go" ]; then
    mkdir $HOME/.local/.go -p
  fi
  [[ -d "$HOME/.local/.go" && ":$GOPATH:" != *":$HOME/.local/.go:"* ]] && GOPATH="$HOME/.local/.go${GOPATH:+:${GOPATH}}"
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



if [ -d $HOME/perl5 ]; then
  [[ -d "$HOME/perl5/bin" && ":$PATH:" != *":$HOME/perl5/bin:"* ]] && PATH="$HOME/perl5/bin:$PATH"
  [[ -d "$HOME/perl5/lib" && ":$PERL5LIB:" != *":$HOME/perl5/lib:"* ]] && PERL5LIB="$HOME/perl5/lib${PERL5LIB:+:${PERL5LIB}}"
  [[ -d "$HOME/perl5" && ":$PERL_LOCAL_LIB_ROOT:" != *":$HOME/perl5:"* ]] && PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
  PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
  PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
fi



# Qt6 settings
if [ -d $HOME/.Qt6 ]; then
  export Qt6_DIR=$HOME/.Qt6   # Replace with your Qt install path
  export PATH=$Qt6_DIR/Tools/QtCreator/bin:$PATH
  for dir in $Qt6_DIR/*/gcc_64; do
    [[ -d "$dir" && ":$PATH:" != *":$dir/bin:"* ]] && PATH="$dir/bin:$PATH"
    [[ -d "$dir" && ":$LIBRARY_PATH:" != *":$dir/lib:"* ]] && LIBRARY_PATH="$dir/lib:$LIBRARY_PATH"
    [[ -d "$dir" && ":$LD_LIBRARY_PATH:" != *":$dir/lib:"* ]] && LD_LIBRARY_PATH="$dir/lib:$LD_LIBRARY_PATH"
    [[ -d "$dir" && ":$C_INCLUDE_PATH:" != *":$dir/include:"* ]] && C_INCLUDE_PATH="$dir/include${C_INCLUDE_PATH:+:${C_INCLUDE_PATH}}"
    [[ -d "$dir" && ":$CPLUS_INCLUDE_PATH:" != *":$dir/include:"* ]] && CPLUS_INCLUDE_PATH="$dir/include${CPLUS_INCLUDE_PATH:+:${CPLUS_INCLUDE_PATH}}"
    [[ -d "$dir" && ":$CMAKE_PREFIX_PATH:" != *":$dir/lib/cmake:"* ]] && CMAKE_PREFIX_PATH="$dir/lib/cmake${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
  done
  # for dir in $Qt6_DIR/*/gcc_64/include/*; do
  #   [[ -d "$dir" && ":$C_INCLUDE_PATH:" != *":$dir:"* ]] && C_INCLUDE_PATH="$dir:$C_INCLUDE_PATH"
  #   [[ -d "$dir" && ":$CPLUS_INCLUDE_PATH:" != *":$dir:"* ]] && CPLUS_INCLUDE_PATH="$dir:$CPLUS_INCLUDE_PATH"
  # done
  export QT_QPA_PLATFORM=xcb # Not use wayland
fi



# Ruby settings
if [ -d $HOME/.local/share/gem/ruby ]; then
  for dir in $HOME/.local/share/gem/ruby/*/gems/*/exe; do
    [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
  done
fi


