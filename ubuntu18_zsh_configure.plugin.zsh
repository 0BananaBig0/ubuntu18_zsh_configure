# Set ROS melodic
source /opt/ros/melodic/setup.zsh
source /home/banana/catkin_ws/devel/setup.zsh
source /home/banana/study_ws/devel/setup.zsh
# Set ROS Network
#ifconfig查看你的电脑ip地址
# export ROS_HOSTNAME=192.168.3.3
# export ROS_MASTER_URI=http://${ROS_HOSTNAME}:11311



# Set MATLAB
# alias matlab='/home/banana/Polyspace/R2021a/bin/matlab >/dev/null 2>&1 &'



# Set firefox
alias firefox='firefox >/dev/null 2>&1 &'



# Set gdb
alias gdb='gdb -q'



# Set CUDA
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}



# Set pycharm
# alias pycharm='/snap/pycharm-professional/254/bin/pycharm.sh >/dev/null 2>&1 &'



# Set vim , gvim and goneovim
alias vi='vi -p'
alias vim='vim -p'
alias gvim='gvim -p'
alias nvim='nvim -p'
alias gnvim='/home/banana/Downloads/program/Goneovim-v0.4.13-linux/goneovim -p'

# Set PDF
alias pdf='/home/banana/Downloads/program/PDF-Studio-11/start &'



# Set pip
alias pip='python3 -m pip'



# Set Go language
# Set the GOPROXY environment variable
export GOPROXY=https://goproxy.io,direct
# Set environment variable allow bypassing the proxy for specified repos (optional)
export GOPRIVATE=git.mycompany.com,github.com/my/private



# Set Cargo
export PATH=$PATH:~/.cargo/bin
