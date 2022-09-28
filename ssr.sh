#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the ShadowsocksR server
#	Version: 2.0.38
#	Author: Toyo
#	Blog: https://doub.io/ss-jc42/
#=================================================

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
Separator_1="——————————————————————————————"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用${Green_background_prefix} sudo su ${Font_color_suffix}来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
  fi
  [[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
  cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  ulimit -n 512000
}
centos_docker_install() {
  sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

  # yum list docker-ce --showduplicates | sort -r
  # sudo yum install docker-ce-<VERSION_STRING> docker-ce-cli-<VERSION_STRING> containerd.io docker-compose-plugin
  sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl start docker && sudo systemctl enable docker
  sudo systemctl disable firewall && sudo systemctl stop firewall
}
debian_docker_install() {
  sudo apt-get remove docker docker-engine docker.io containerd runc;

  sudo apt-get -y update;
  sudo apt-get install -y ca-certificates curl gnupg lsb-release;

  sudo mkdir -p /etc/apt/keyrings;
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg;

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update;
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker
  sudo ufw disable
}
ubuntu_docker_install() {
    sudo apt-get remove docker docker-engine docker.io containerd runc

    sudo apt-get -y update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get -y update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo service docker start && systemctl enable docker
    sudo ufw disable
}
check_docker() {
  # shellcheck disable=SC2006
  docker_ver=`docker --version`
	if [[ -z ${docker_ver} ]]; then
		echo -e "${Info} 没有安装docker，开始安装..."
		${release}_docker_install
	fi
}
build_image() {
  # shellcheck disable=SC2006
  docker_proxy_contain=`docker ps -a | grep network_proxy_server`
	# shellcheck disable=SC2236
	if [[ ! -z ${docker_proxy_contain} ]]; then
		docker rm -f network_proxy_server
	fi
	# shellcheck disable=SC2006
	docker_proxy_image=`docker images | grep network_proxy`
	# shellcheck disable=SC2236
	if [[ ! -z ${docker_proxy_image} ]]; then
		docker rmi network_proxy
	fi
	docker run -d --name network_proxy_server --restart always --net=host pascall/network-proxy
}


check_root
check_sys
check_docker
build_image
