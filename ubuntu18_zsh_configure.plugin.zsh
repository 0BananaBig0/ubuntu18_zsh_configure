export LIBRARY_PATH=$LIBRARY_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export C_INCLUDE_PATH=$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH



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



# Set gdb
alias gdb='gdb -q'



# Set CUDA
if [ -d /usr/local/cuda ]; then
  export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
  export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
fi



# Set vim , gvim and goneovim
alias vi='vi -p'
alias vim='vim -p'
alias gvim='gvim -p'
alias nvim='nvim -p'



# Set Go language
if [ -s "$HOME/.local/.go" ]; then
  export GOPATH="$HOME/.local/.go"
  export PATH="$PATH:${GOPATH//://bin:}/bin"
  export GO111MODULE=on
  # Set the GOPROXY environment variable
  export GOPROXY=https://goproxy.io,direct
  # Set environment variable allow bypassing the proxy for specified repos (optional)
  # export GOPRIVATE=git.mycompany.com,github.com/my/private
fi



# Set Cargo
if [ -s "$HOME/.cargo" ]; then
  export PATH=$PATH:$HOME/.cargo/bin
fi
if command -v zoxide >/dev/null 2>&1;then
  eval "$(zoxide init zsh)"
fi



# Set vi-mode of terminal
VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
MODE_INDICATOR="%F{white}<<<%f"



# add env
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export XDG_DATA_DIRS=$XDG_DATA_DIRS:/usr/local/share
if [ -s "$HOME/.local" ]; then
  #add local bin of normal user.
  export PATH=$PATH:$HOME/.local/bin
  #add new dynamic library
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.local/lib
  #add man information
  export XDG_DATA_DIRS=$XDG_DATA_DIRS:$HOME/.local/share
fi



# support wsl2 gui applications
if grep -q WSL2 /proc/version; then
  export DISPLAY=:0
  # for wsl2 vscode
  export DONT_PROMPT_WSL_INSTALL=1
fi



if [ -d ${HOME}/perl5 ]; then
  PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
  PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
  PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
  PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
  PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
fi



if [ -d ${HOME}/wsl_shared_folder/.Qt6 ]; then
  export QTDIR=${HOME}/wsl_shared_folder/.Qt6   # Replace with your Qt install path
  export PATH=${PATH}:$QTDIR/Tools/QtCreator/bin
  for dir in $QTDIR/*/gcc_64; do
    [[ -d "$dir" && ":$PATH:" != *":$dir/bin:"* ]] && PATH="$PATH:$dir/bin"
    [[ -d "$dir" && ":$LIBRARY_PATH:" != *":$dir/lib:"* ]] && LIBRARY_PATH="$LIBRARY_PATH:$dir/lib"
    [[ -d "$dir" && ":$LD_LIBRARY_PATH:" != *":$dir/lib:"* ]] && LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$dir/lib"
    [[ -d "$dir" && ":$C_INCLUDE_PATH:" != *":$dir/include:"* ]] && C_INCLUDE_PATH="$C_INCLUDE_PATH:$dir/include"
    [[ -d "$dir" && ":$CPLUS_INCLUDE_PATH:" != *":$dir/include:"* ]] && CPLUS_INCLUDE_PATH="$CPLUS_INCLUDE_PATH:$dir/include"
  done
  for dir in $QTDIR/*/gcc_64/include/*; do
    [[ -d "$dir" && ":$C_INCLUDE_PATH:" != *":$dir:"* ]] && C_INCLUDE_PATH="$C_INCLUDE_PATH:$dir"
    [[ -d "$dir" && ":$CPLUS_INCLUDE_PATH:" != *":$dir:"* ]] && CPLUS_INCLUDE_PATH="$CPLUS_INCLUDE_PATH:$dir"
  done
  export QT_QPA_PLATFORM=xcb # Not use wayland
fi



if [ -d ${HOME}/.local/share/gem/ruby ]; then
  for dir in ${HOME}/.local/share/gem/ruby/*; do
    [[ -d "$dir" && ":$PATH:" != *":$dir/bin:"* ]] && PATH="$PATH:$dir/bin"
  done
fi
