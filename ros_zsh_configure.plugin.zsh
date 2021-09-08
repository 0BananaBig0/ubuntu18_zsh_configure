# Set ROS melodic
source /opt/ros/melodic/setup.zsh
source /home/banana/catkin_ws/devel/setup.zsh
source /home/banana/study_ws/devel/setup.zsh

# Set ROS Network
#ifconfig查看你的电脑ip地址
export ROS_HOSTNAME=192.168.3.3
export ROS_MASTER_URI=http://${ROS_HOSTNAME}:11311

#Set Java-13
#export JAVA_HOME=/usr/lib/jvm/jdk-13
#export CLASSPATH=.:${JAVA_HOME}/lib
#export PATH=${JAVA_HOME}/bin:$PATH

#Set MATLAB
alias matlab='/home/banana/Polyspace/R2021a/bin/matlab >/dev/null 2>&1 &'

#Set firefox
alias firefox='firefox >/dev/null 2>&1 &'

#Set gdb
alias gdb='gdb -q'

#Set CUDA
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}


#Set pycharm
alias pycharm='/snap/pycharm-professional/254/bin/pycharm.sh >/dev/null 2>&1 &'


#Set gvim
alias gvim='gvim -p'



#Set PDF
alias pdf='/home/banana/Downloads/program/PDF-Studio-11/start &'



# set wine
# export WINEARCH=win32



# set pip
alias pip='python3 -m pip'
