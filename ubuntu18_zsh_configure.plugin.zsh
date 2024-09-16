# Set ROS melodic
if [ -x "/opt/ros/melodic/setup.zsh" ]; then
  source /opt/ros/melodic/setup.zsh
fi
if [ -x "$HOME/catkin_ws/devel/setup.zsh" ]; then
  source $HOME/catkin_ws/devel/setup.zsh
fi
if [ -x "$HOME/study_ws/devel/setup.zsh" ]; then
  source $HOME/study_ws/devel/setup.zsh
fi
# Set ROS Network
#ifconfig查看你的电脑ip地址
# export ROS_HOSTNAME=192.168.3.3
# export ROS_MASTER_URI=http://${ROS_HOSTNAME}:11311



# Set MATLAB
if [ -f $HOME/Polyspace/R2021a/bin/matlab ]
then
  alias matlab='$HOME/Polyspace/R2021a/bin/matlab >/dev/null 2>&1 &'
fi



# Set gdb
alias gdb='gdb -q'



# Set CUDA
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}



# Set vim , gvim and goneovim
alias vi='vi -p'
alias vim='vim -p'
alias gvim='gvim -p'
alias nvim='nvim -p'
alias gnvim='$HOME/Downloads/program/goneovim-linux/goneovim -p'



# Set pip
alias pip='python3 -m pip'



# Set Go language
export GOPATH="$HOME/.local/.go"
export PATH="$PATH:${GOPATH//://bin:}/bin"
export GO111MODULE=on
# Set the GOPROXY environment variable
export GOPROXY=https://goproxy.io,direct
# Set environment variable allow bypassing the proxy for specified repos (optional)
# export GOPRIVATE=git.mycompany.com,github.com/my/private
if [ `whoami` = "root" ];then
  if [ -s "$HOME/.local/.go" ]; then
    export PATH="$PATH:$HOME/.local/.go/bin"
  fi
fi



# Set Cargo
export PATH=$PATH:$HOME/.cargo/bin
if [ `whoami` = "root" ];then
  if [ -s "$HOME/.cargo" ]; then
    export PATH="$PATH:$HOME/.cargo/bin"
  fi
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
if [ `whoami` = "root" ];then
  if [ -s "$HOME/.local" ];then
    #add local bin of normal user.
    export PATH="$PATH:$HOME/.local/bin"
    #add new dynamic library
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.local/lib
    #add man information
    export XDG_DATA_DIRS=$XDG_DATA_DIRS:$HOME/.local/share
  fi
fi



# support wsl2 gui applications
if grep -q WSL2 /proc/version; then
  # LOCAL_IP=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
  # export DISPLAY=$LOCAL_IP:0
  export DISPLAY=:0
  # for wsl2 vscode
  export DONT_PROMPT_WSL_INSTALL=1
fi



PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;



# 启动xrdp服务
if [ -f /etc/init.d/xrdp ] && [ "$(id -u)" != 0 ] && [ -z "$(pgrep xrdp-sesman)" ]
then
     echo "1230" | sudo -S /etc/init.d/xrdp start
     if [ $? -ne 0 ]
     then
             echo "failed to start xrdp service!"
     fi
fi

