#!/bin/sh

VNTS="$(nvram get vnts_bin)"
vnts_enable=$(nvram get vnts_enable)
vnts_log="$(nvram get vnts_log)"
vnts_port="$(nvram get vnts_port)"
vnts_token="$(nvram get vnts_token)"
vnts_subnet="$(nvram get vnts_subnet)"
vnts_netmask="$(nvram get vnts_netmask)"
vnts_sfinger="$(nvram get vnts_sfinger)"
vnts_web_enable=$(nvram get vnts_web_enable)
vnts_web_port="$(nvram get vnts_web_port)"
vnts_web_user="$(nvram get vnts_web_user)"
vnts_web_pass="$(nvram get vnts_web_pass)"
vnts_web_wan=$(nvram get vnts_web_wan)
[ -z "$VNTS" ] && VNTS=/etc/storage/bin/vnts && nvram set vnts_bin=$VNTS
[ -z "$vnts_port" ] && vnts_port="29872" && nvram set vnts_port=$vnts_port
[ -z "$vnts_web_port" ] && vnts_web_port="29870" && nvram set vnts_web_port=$vnts_web_port
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
github_proxys="$(nvram get github_proxy)"
[ -z "$github_proxys" ] && github_proxys=" "

get_tag() {
	curltest=`which curl`
	logger -t "VNT服务端" "开始获取最新版本..."
    	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
      		tag="$( wget -T 5 -t 3 --user-agent "$user_agent" --max-redirect=0 --output-document=-  https://api.github.com/repos/lmq8267/vnts/releases/latest 2>&1 | grep 'tag_name' | cut -d\" -f4 )"
	 	[ -z "$tag" ] && tag="$( wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=-  https://api.github.com/repos/lmq8267/vnts/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
    	else
      		tag="$( curl --connect-timeout 3 --user-agent "$user_agent"  https://api.github.com/repos/lmq8267/vnts/releases/latest 2>&1 | grep 'tag_name' | cut -d\" -f4 )"
       	[ -z "$tag" ] && tag="$( curl -L --connect-timeout 3 --user-agent "$user_agent" -s  https://api.github.com/repos/lmq8267/vnts/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
        fi
	[ -z "$tag" ] && logger -t "VNT服务端" "无法获取最新版本" 
	nvram set vnts_ver_n=$tag
	if [ -f "$VNTS" ] ; then
		chmod +x $VNTS
		vnts_ver=$($VNTS --version | awk -F 'version:' '{print $2}' | tr -d ' ' | tr -d '\n')
		if [ -z "$vnts_ver" ] ; then
			nvram set vnts_ver=""
		else
			nvram set vnts_ver="v${vnts_ver}"
		fi
	fi
}

dowload_vnts() {
	tag="$1"
	bin_path=$(dirname "$VNTS")
	[ ! -d "$bin_path" ] && mkdir -p "$bin_path"
	logger -t "VNT服务端" "开始下载 https://github.com/lmq8267/vnts/releases/download/${tag}/vnts_mipsel-unknown-linux-musl 到 $VNTS"
	for proxy in $github_proxys ; do
       curl -Lkso "$VNTCLI" "${proxy}https://github.com/lmq8267/vnts/releases/download/${tag}/vnts_mipsel-unknown-linux-musl" || wget --no-check-certificate -q -O "$VNTCLI" "${proxy}https://github.com/lmq8267/vnts/releases/download/${tag}/vnts_mipsel-unknown-linux-musl"
	if [ "$?" = 0 ] ; then
		chmod +x $VNTS
		if [ $(($($VNTS -h | wc -l))) -gt 3 ] ; then
			logger -t "VNT服务端" "$VNTS 下载成功"
			vnts_ver=$($VNTS --version | awk -F 'version:' '{print $2}' | tr -d ' ' | tr -d '\n')
			if [ -z "$vnts_ver" ] ; then
				nvram set vnts_ver=""
			else
				nvram set vnts_ver="v${vnts_ver}"
			fi
			break
       	else
	   		logger -t "VNT服务端" "下载不完整，请手动下载 ${proxy}https://github.com/lmq8267/vnts/releases/download/${tag}/vnts_mipsel-unknown-linux-musl 上传到  $VNTS"
			rm -f $VNTS
	  	fi
	else
		logger -t "VNT服务端" "下载失败，请手动下载 ${proxy}https://github.com/lmq8267/vnts/releases/download/${tag}/vnts_mipsel-unknown-linux-musl 上传到  $VNTS"
   	fi
	done
}

update_vnts() {
	get_tag
	[ -z "$tag" ] && logger -t "VNT服务端" "无法获取最新版本" && exit 1
	tag=$(echo $tag | tr -d 'v' | tr -d ' ' | tr -d '\n' )
	if [ ! -z "$tag" ] && [ ! -z "$vnts_ver" ] ; then
		if [ "$stag"x != "$vnts_ver"x ] ; then
			logger -t "VNT服务端" "当前版本${vnts_ver} 最新版本${tag}"
			dowload_vnts $tag
		else
			logger -t "VNT服务端" "当前已是最新版本 ${tag} 无需更新！"
		fi
	fi
	exit 0
}

start_vnts() {
	[ "$vnts_enable" = "1" ] || exit 1
	logger -t "VNT服务端" "正在启动vnts"
	get_tag
 	if [ ! -f "$VNTS" ] ; then
		logger -t "VNT服务端" "主程序${VNTS}不存在，开始在线下载..."
  		[ ! -d /etc/storage/bin ] && mkdir -p /etc/storage/bin
  		[ -z "$tag" ] && tag="1.2.13"
  		dowload_vnts $tag
  	fi
  	[ ! -f "$VNTS" ] && exit 1
  	chmod +x $VNTS
	[ $(($($VNTS -h | wc -l))) -gt 3 ] || logger -t "VNT服务端" "程序${VNTS}不完整，无法运行！" && exit 1
	killall -9 vnts >/dev/null 2>&1
	if [ "$vnts_log" = "1" ] ; then
		path=$(dirname "$VNTS")
		log_path="${path}/log"
		if [ ! -f "${log_path}/log4rs.yaml" ] ; then
			mkdir -p ${log_path}
cat > "${log_path}/log4rs.yaml"<<EOF
refresh_rate: 30 seconds
appenders:
  rolling_file:
    kind: rolling_file
    path: /tmp/vnts.log
    append: true
    encoder:
      pattern: "{d(%Y-%m-%d %H:%M:%S vnts:)} [{f}:{L}] {h({l})} {M}:{m}{n}"
    policy:
      kind: compound
      trigger:
        kind: size
        limit: 1 mb
      roller:
        kind: fixed_window
        pattern: /tmp/vnts.{}.log
        base: 1
        count: 2

root:
  level: info
  appenders:
    - rolling_file
EOF
		fi
		[ ! -L /tmp/vnts.1.log ] && ln -sf /tmp/vnts.log /tmp/vnts.1.log
		[ ! -L /tmp/vnts.2.log ] && ln -sf /tmp/vnts.log /tmp/vnts.2.log
		sed -i 's|limit: 10 mb|limit: 1 mb|g' ${log_path}/log4rs.yaml
		sed -i 's|count: 5|count: 2|g' ${log_path}/log4rs.yaml
		logyaml=$(cat ${log_path}/log4rs.yaml | grep path: | awk -F'path: ' '{print $2}')
		logyaml2=$(cat ${log_path}/log4rs.yaml | grep pattern: | awk -F'pattern: ' '{print $2}')
		if [ "$logyaml" != "/tmp/vnts.log" ] ; then
			sed -i "s|${logyaml}|/tmp/vnts.log|g" ${log_path}/log4rs.yaml
			sed -i "s|${logyaml2}|/tmp/vnts.{}.log|g" ${log_path}/log4rs.yaml
		fi
	
	fi
	CMD=""
	[ -z "$vnts_port" ] || CMD="-p $vnts_port"
	if [ ! -z "$vnts_token" ] ; then
		for token in $vnts_token ; do
			[ -z "$token" ] && continue
			CMD="${CMD} -w ${token}"
		done	
	fi
	[ -z "$vnts_subnet" ] || CMD="${CMD} -g ${vnts_subnet}"
	[ -z "$vnts_netmask" ] || CMD="${CMD} -m ${vnts_netmask}"
	[ "$vnts_sfinger" = "1" ] && CMD="${CMD} -f"
	if [ "$vnts_web_enable" = "1" ] ; then
		[ -z "$vnts_web_port" ] || CMD="${CMD} -P ${vnts_web_port}"
		[ -z "$vnts_web_user" ] || CMD="${CMD} -U ${vnts_web_user}"
		[ -z "$vnts_web_pass" ] || CMD="${CMD} -W ${vnts_web_pass}"
	else
		CMD="${CMD} -P 0"
	fi
	[ "$vnts_log" = "1" ] || CMD="${CMD} -l /dev/null"
	
	vntscmd="cd ${path} ; ./vnts ${CMD} >/tmp/vnts.log 2>&1"
	logger -t "VNT服务端" "运行${vntscmd}"
	eval "$vntscmd" &
	sleep 4
	if [ ! -z "`pidof vnts`" ] ; then
		logger -t "VNT服务端" "运行成功！"
		if [ ! -z "$vnts_port" ] ; then
			iptables -I INPUT -p tcp --dport $vnts_port -j ACCEPT
			iptables -I INPUT -p udp --dport $vnts_port -j ACCEPT
			ip6tables -I INPUT -p tcp --dport $vnts_port -j ACCEPT
			ip6tables -I INPUT -p udp --dport $vnts_port -j ACCEPT
		fi
		if [ "$vnts_web_enable" = "1" ] && [ "$vnts_web_wan" = "1" ] && [ ! -z "$vnts_web_port" ] ; then
			iptables -I INPUT -p tcp --dport $vnts_web_port -j ACCEPT
			iptables -I INPUT -p udp --dport $vnts_web_port -j ACCEPT
			ip6tables -I INPUT -p tcp --dport $vnts_web_port -j ACCEPT
			ip6tables -I INPUT -p udp --dport $vnts_web_port -j ACCEPT
		fi
		echo `date +%s` > /tmp/vnts_time
	else
		logger -t "VNT服务端" "运行失败！"
	fi
	exit 0
}


stop_vnts() {
	logger -t "VNT服务端" "正在关闭vnts ..."
	scriptname=$(basename $0)
	if [ ! -z "$scriptname" ] ; then
		eval $(ps -w | grep "$scriptname" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}')
		eval $(ps -w | grep "$scriptname" | grep -v $$ | grep -v grep | awk '{print "kill -9 "$1";";}')
	fi
	killall -9 vnts >/dev/null 2>&1
	if [ ! -z "$vnts_port" ] ; then
		iptables -D INPUT -p tcp --dport $vnts_port -j ACCEPT 2>/dev/null
		iptables -D INPUT -p udp --dport $vnts_port -j ACCEPT 2>/dev/null
		ip6tables -D INPUT -p tcp --dport $vnts_port -j ACCEPT 2>/dev/null
		ip6tables -D INPUT -p udp --dport $vnts_port -j ACCEPT 2>/dev/null
	fi
	if [ "$vnts_web_enable" = "1" ] && [ "$vnts_web_wan" = "1" ] && [ ! -z "$vnts_web_port" ] ; then
		iptables -D INPUT -p tcp --dport $vnts_web_port -j ACCEPT 2>/dev/null
		iptables -D INPUT -p udp --dport $vnts_web_port -j ACCEPT 2>/dev/null
		ip6tables -D INPUT -p tcp --dport $vnts_web_port -j ACCEPT 2>/dev/null
		ip6tables -D INPUT -p udp --dport $vnts_web_port -j ACCEPT 2>/dev/null
	fi
	[ ! -z "`pidof vnts`" ] && logger -t "VNT服务端" "进程已关闭!"
}

case $1 in
start)
	start_vnts &
	;;
stop)
	stop_vnts
	;;
restart)
	stop_vnts
	start_vnts &
	;;
update)
	update_vnts &
	;;
*)
	echo "check"
	#exit 0
	;;
esac