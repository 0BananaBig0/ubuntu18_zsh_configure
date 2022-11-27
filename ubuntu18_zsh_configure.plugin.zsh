# Set ROS melodic
if [ -x "/opt/ros/melodic/setup.zsh" ]; then
  source /opt/ros/melodic/setup.zsh
fi
if [ -x "/home/banana/catkin_ws/devel/setup.zsh" ]; then
  source /home/banana/catkin_ws/devel/setup.zsh
fi
if [ -x "/home/banana/study_ws/devel/setup.zsh" ]; then
  source /home/banana/study_ws/devel/setup.zsh
fi
# Set ROS Network
#ifconfig查看你的电脑ip地址
# export ROS_HOSTNAME=192.168.3.3
# export ROS_MASTER_URI=http://${ROS_HOSTNAME}:11311



# Set MATLAB
# alias matlab='/home/banana/Polyspace/R2021a/bin/matlab >/dev/null 2>&1 &'



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
alias gnvim='/home/banana/Downloads/program/goneovim-linux/goneovim -p'



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
  if [ -s "/home/banana/.local/.go" ]; then
    export PATH="$PATH:/home/banana/.local/.go/bin"
  fi
fi



# Set Cargo
export PATH=$PATH:$HOME/.cargo/bin
if [ `whoami` = "root" ];then
  if [ -s "/home/banana/.cargo" ]; then
    export PATH="$PATH:/home/banana/.cargo/bin"
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
  if [ -s "/home/banana/.local" ];then
    #add local bin of normal user.
    export PATH="$PATH:/home/banana/.local/bin"
    #add new dynamic library
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/banana/.local/lib
    #add man information
    export XDG_DATA_DIRS=$XDG_DATA_DIRS:/home/banana/.local/share
  fi
fi
