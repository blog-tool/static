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
github="raw.githubusercontent.com/chiakge/Linux-NetSpeed/master"

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
check_version(){
	if [[ -s /etc/redhat-release ]]; then
		version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
	else
		version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
	fi
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="x64"
	else
		bit="x32"
	fi
}

##################################################kernel####################################################################
detele_kernel(){
	if [[ "${release}" == "centos" ]]; then
		rpm_total=`rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | wc -l`
		if [ "${rpm_total}" > "1" ]; then
			echo -e "检测到 ${rpm_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${rpm_total}; integer++)); do
				rpm_del=`rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer}`
				echo -e "开始卸载 ${rpm_del} 内核..."
				rpm --nodeps -e ${rpm_del}
				echo -e "卸载 ${rpm_del} 内核卸载完成，继续..."
			done
			echo --nodeps -e "内核卸载完毕，继续..."
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
		deb_total=`dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | wc -l`
		if [ "${deb_total}" > "1" ]; then
			echo -e "检测到 ${deb_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${deb_total}; integer++)); do
				deb_del=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer}`
				echo -e "开始卸载 ${deb_del} 内核..."
				apt-get purge -y ${deb_del}
				echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
			done
			echo -e "内核卸载完毕，继续..."
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	fi
}
BBR_grub(){
	if [[ "${release}" == "centos" ]]; then
        if [[ ${version} = "6" ]]; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "${Error} /boot/grub/grub.conf 找不到，请检查."
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif [[ ${version} = "7" ]]; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "${Error} /boot/grub2/grub.cfg 找不到，请检查."
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        /usr/sbin/update-grub
    fi
}
installbbrplus(){
	kernel_version="4.14.129-bbrplus"
	if [[ "${release}" == "centos" ]]; then
		wget -N --no-check-certificate https://${github}/bbrplus/${release}/${version}/kernel-${kernel_version}.rpm
		yum install -y kernel-${kernel_version}.rpm
		rm -f kernel-${kernel_version}.rpm
		kernel_version="4.14.129_bbrplus" #fix a bug
	elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
		mkdir bbrplus && cd bbrplus
		wget -N --no-check-certificate http://${github}/bbrplus/debian-ubuntu/${bit}/linux-headers-${kernel_version}.deb
		wget -N --no-check-certificate http://${github}/bbrplus/debian-ubuntu/${bit}/linux-image-${kernel_version}.deb
		dpkg -i linux-headers-${kernel_version}.deb
		dpkg -i linux-image-${kernel_version}.deb
		cd .. && rm -rf bbrplus
	fi
	detele_kernel
	BBR_grub
	echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBRplus${Font_color_suffix}"
}
startbbrplus(){
	remove_all
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbrplus" >> /etc/sysctl.conf
	sysctl -p
	echo -e "${Info}BBRplus启动成功！"
}
check_bbrplus(){
	if [[ "${release}" == "centos" ]]; then
		if [[ ${version} -ge "6" ]]; then
			installbbrplus
		else
			echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "debian" ]]; then
		if [[ ${version} -ge "8" ]]; then
			installbbrplus
		else
			echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	elif [[ "${release}" == "ubuntu" ]]; then
		if [[ ${version} -ge "14" ]]; then
			installbbrplus
		else
			echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
		fi
	else
		echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
	fi
}
check_kernel() {
	kernel_version_full=`uname -r`
	if [[ ${kernel_version_full} = "4.14.129-bbrplus" ]]; then
		run_status=`grep "net.ipv4.tcp_congestion_control" /etc/sysctl.conf | awk -F "=" '{gsub("^[ \t]+|[ \t]+$", "", $2);print $2}'`
		if [[ ${run_status} == "bbrplus" ]]; then
			run_status=`lsmod | grep "bbrplus" | awk '{print $1}'`
			if [[ ${run_status} == "tcp_bbrplus" ]]; then
				echo -e "${Info}BBRplus启动成功！"
			else
				startbbrplus
			fi
		else
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} ${_font_prefix}${kernel_status}${Font_color_suffix} 加速内核 , ${Green_font_prefix}未安装加速模块${Font_color_suffix}"
		fi
	else
		check_bbrplus
	fi
}
##################################################kernel####################################################################

##################################################docker####################################################################
centos_docker_install() {
  sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

  sudo yum install -y yum-utils vim wget
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
  sudo apt-get install -y ca-certificates curl gnupg lsb-release vim wget;

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
    sudo apt-get install -y ca-certificates curl gnupg lsb-release vim wget

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
run_docker() {
  # shellcheck disable=SC2006
  docker_proxy_contain=`docker ps -a | grep network_proxy_server`
	# shellcheck disable=SC2236
	if [[ ! -z ${docker_proxy_contain} ]]; then
		docker rm -f network_proxy_server
	fi
	# shellcheck disable=SC2006
	docker_proxy_image=`docker images | grep pascall/network-proxy`
	# shellcheck disable=SC2236
	if [[ ! -z ${docker_proxy_image} ]]; then
		docker rmi pascall/network-proxy
	fi
	docker run -d --name network_proxy_server --restart always --net=host pascall/network-proxy
}
##################################################docker####################################################################

check_root
check_sys
check_version
check_docker
run_docker
check_kernel
