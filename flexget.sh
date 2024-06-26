#!/bin/bash
# Ver 1.0
# Powerby：翔翎
# Blog：https://blog.20120714.xyz

echoType='echo -e'
echoContent(){
  case $1 in
  # 红色
  "red")
    # shellcheck disable=SC2154
    ${echoType} "\033[31m$2\033[0m"
    ;;
    # 绿色
  "green")
    ${echoType} "\033[32m$2\033[0m"
    ;;
    # 黄色
  "yellow")
    ${echoType} "\033[33m$2\033[0m"
    ;;
    # 蓝色
  "blue")
    ${echoType} "\033[34m$2\033[0m"
    ;;
    # 紫色
  "purple")
    ${echoType} "\033[35m$2\033[0m"
    ;;
    # 天蓝色
  "skyBlue")
    ${echoType} "\033[36m$2\033[0m"
    ;;
    # 白色
  "white")
    ${echoType} "\033[37m$2\033[0m"
    ;;
  esac
}
clear
# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: $ 必须使用root用户运行此脚本！\n" && exit 1
apt install lsof unzip -y || yum install lsof unzip -y
clear
function check_docker(){
  if test -z "$(which docker)"; then
    echoContent yellow "检测到系统未安装docker，开始安装docker"
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
  fi
  if test -z "$(which docker-compose)"; then
    echoContent yellow "检测到系统未安装docker-compose，开始安装docker-compose"
    curl -L "https://github.com/docker/compose/releases/download/v2.10.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  fi
}
function install_flexget(){
  read -p "请设置flexget面板登录密码[最好英数结合，太简单无法生效]：" password
  read -p "是否在本机部署qBittorrent[Y/N]：" yn
  if [[ ${yn} != "Y" ]]&&[[ ${yn} != "y" ]]; then
    read -p "请输入远程qBittorrent下载器的IP地址：" box_ip
    read -p "请输入远程qBittorrent下载器的服务端口：" boxport
    read -p "请输入远程qBittorrent下载器的用户名：" box_user_name
    read -p "请输入远程qBittorrent下载器的登录密码：" box_password
    cat >/root/docker-compose.yml <<EOF
version: "3"
services: 
  flexget:
    image: madwind/flexget
    container_name: flexget
    volumes:
      - /home/flexget/config:/config
      # - /home/flexget/downloads:/downloads
    environment:
      - FG_WEBUI_PASSWD=$password
      - PUID=0
      - PGID=0
      - FG_LOG_LEVEL=INFO
      - TZ=Asia/Shanghai
    ports:
      - "3539:3539"
EOF
  else
    box_ip="127.0.0.1"
    boxport="8088"
    box_user_name="admin"
    box_password="adminadmin"
    read -p "请输入qBittorrent下载文件保存路径(宿主机目录路径)：" downdir 
    cat >/root/docker-compose.yml <<EOF
version: "3"
services: 
  flexget:
    image: madwind/flexget
    container_name: flexget
    volumes:
      - /home/flexget/config:/config
      # - /home/flexget/downloads:/downloads
    environment:
      - FG_WEBUI_PASSWD=$password
      - PUID=0
      - PGID=0
      - FG_LOG_LEVEL=INFO
      - TZ=Asia/Shanghai
    ports:
      - "3539:3539"
  qbittorrent:
    image: ghcr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    network_mode: "host"
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
      - WEBUI_PORT=8088
    volumes:
      - /home/qbittorrent/config:/config
      - ${downdir}:/downloads
      - /home/qbittorrent/watch:/watch  
    restart: unless-stopped
EOF
  fi
  mkdir -p /home/flexget/config && cd /home/flexget/config && wget https://github.com/IvonWei/flexget_qbittorrent_mod/archive/refs/heads/master.zip && unzip master.zip >/dev/null && mv flexget_qbittorrent_mod-master plugins && rm master.zip
  wget -O plugins/nexusphp.py https://raw.githubusercontent.com/Juszoe/flexget-nexusphp/master/nexusphp.py
  read -p "请设置磁盘低于多少G不再添加种子并触发删种操作：" keep_disk_space
  cat >/home/flexget/config/config.yml<<EOF
web_server:
  bind: '0.0.0.0'
  port: 3539

schedules:
  - tasks: []
    interval:
      minutes: 5

  - tasks: [ol_resume, ol_delete, ol_modify, ol_clean]
    interval:
      minutes: 5

variables:
  headers:
    user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36 Edg/88.0.705.74'

templates:
  ## Online
  # 从 qBittorrent 获取数据
  ol_from_qbittorrent_template:
    from_qbittorrent_mod: &ol_from_qbittorrent_mod
      host: ${box_ip}
      port: ${boxport}
      use_ssl: false
      username: '${box_user_name}'
      password: '${box_password}'

  # 基础
  ol_qbittorrent_base_template:
    qbittorrent_mod:
      <<: *ol_from_qbittorrent_mod

  # 添加
  ol_qbittorrent_add_template:
    qbittorrent_mod:
      action:
        add:
          category: RSS
          autoTMM: yes
          reject_on:
            dl_limit: 5242880
            dl_speed: no

  # 删除
  ol_qbittorrent_delete_keeper_template:
    qbittorrent_mod:
      action:
        remove:
          keeper:
            delete_files: yes
            keep_disk_space: ${keep_disk_space}
            dl_limit_interval: 900


  ## 多种操作
  # 清理
  qbittorrent_delete_cleaner_template:
    qbittorrent_mod:
      action:
        remove:
          cleaner:
            delete_files: yes

  # 修改
  qbittorrent_modify_template:
    qbittorrent_mod:
      action:
        modify:
          tag_by_tracker: true

  # 恢复
  qbittorrent_resume_template:
    qbittorrent_mod:
      action:
        resume:
          recheck_torrents: true

  # 种子大小筛选
  content_size:
    content_size:
      min: 500
      max: 50000
      strict: no

tasks:
EOF
  i=0
  read -p "请输入要添加的站点总数量：" times
  while [ $i -lt $times ]
  do
  let i++
  text1=`sed -n '6p' /home/flexget/config/config.yml|sed 's/]//g'|sed 's/^[ ]*//g'`
  read -p "请添加第${i}个站点的名称：" web
  read -p "请输入${web}的Cookie：" Cookie
  read -p "请输入${web}的Rss订阅链接：" rss
  read -p "请输入${web}的上行限制(单位Kb/s,如45000则为限速45Mb/s)：" maxupspeed
  if [[ ${times} -eq 1 ]]; then
    text2="\  ${text1}${web}]"
  else
    if [[ ${i} == 1 ]]; then
      text2="${text1}${web},]"
    elif [[ ${i} -eq ${times} ]]; then
      text2="\  ${text1} ${web}]"
    else
      text2="${text1} ${web},]"
    fi
  fi
  sed -i "6c ${text2}" /home/flexget/config/config.yml
cat >> /home/flexget/config/config.yml <<EOF
  ${web}:
    rss: 
      url: ${rss}
      other_fields:
        - link
    qbittorrent:
      maxupspeed: ${maxupspeed}
      maxdownspeed: 100000
      label: ${web}
    nexusphp:
      cookie: '${Cookie}'
      user-agent: '{? headers.user_agent ?}'
      comment: yes
      discount:
        - free
        - 2xfree
      seeders:
        min: 1
    verify_ssl_certificates: no
    content_size:
      min: 500
      max: 120000
      strict: no
    template:
      - ol_qbittorrent_base_template
      - ol_qbittorrent_add_template
EOF
done >/dev/null
cat >> /home/flexget/config/config.yml<<EOF
  resume: &resume
    priority: 2
    disable: [seen, seen_info_hash, retry_failed]
    if:
      - qbittorrent_state == 'pausedUP' and qbittorrent_downloaded == 0 and qbittorrent_added_on > now - timedelta(hours=1): accept

  delete: &delete
    priority: 3
    disable: [seen, seen_info_hash, retry_failed]
    if:
      - qbittorrent_category in ['RSS'] and (qbittorrent_last_activity < now - timedelta(days=2) or qbittorrent_added_on < now - timedelta(days=7)): accept
      - qbittorrent_state == 'missingFiles' or (qbittorrent_state in ['pausedDL'] and qbittorrent_completed == 0): accept
    sort_by: qbittorrent_last_activity

  modify: &modify
    priority: 4
    disable: [seen, seen_info_hash, retry_failed]
    accept_all: yes

  clean: &clean
    priority: 5
    disable: [seen, seen_info_hash, retry_failed]
    regexp:
      accept:
        - '[Tt]orrent not registered with this tracker'
        - 'Torrent banned'
        - 'Unregistered torrent'
      from: qbittorrent_tracker_msg

  ol_resume:
    <<: *resume
    template:
      - ol_from_qbittorrent_template
      - ol_qbittorrent_base_template
      - qbittorrent_resume_template


  
  ol_delete:
    <<: *delete 
    template:
      - ol_from_qbittorrent_template
      - ol_qbittorrent_base_template      
      - ol_qbittorrent_delete_keeper_template
  

  
  ol_modify:
    <<: *modify
    template:
      - ol_from_qbittorrent_template
      - ol_qbittorrent_base_template
      - qbittorrent_modify_template
  


  ol_clean:
    <<: *clean
    template:
      - ol_from_qbittorrent_template
      - ol_qbittorrent_base_template
      - qbittorrent_delete_cleaner_template
EOF
  echoContent yellow "太好了，所有信息已经准备完毕，开始程序部署"
  docker-compose -f /root/docker-compose.yml up -d
  if [[ $? -eq 0 ]]; then
    sleep 5s
    echoContent yellow "即将开始进入容器，执行安装requests依赖必要操作"
  else
    echoContent red "flexget安装失败了····"
    exit 1
  fi
  docker exec -it flexget bash -c "pip3 install --upgrade requests"
  if [[ $? -eq 0 ]]; then
    if [[ ${yn} == "y" ]]||[[ ${yn} == "Y" ]]; then
      echoContent green "
------------------------------------------------
      恭喜:Flexget、qBittorrent安装完毕
      Flexget端口:3539
      面板登录密码:$password
      配置文件存放路径:/home/flexget/config
------------------------------------------------
      qBittorrent端口:8088
      qBittorrent用户名:admin
      qBittorrent密码:adminadmin
      配置文件存放路径:/home/qbittorrent/config
      下载文件存放路径:${downdir}
------------------------------------------------"
    else
      echoContent green "
------------------------------------------------
      恭喜:Flexget安装完毕
      Flexget端口:3539
      面板登录密码:$password
      配置文件存放路径:/home/flexget/config
------------------------------------------------"
    fi
  else
    echoContent red "⚠️  安装requests依赖失败了····"
    exit 1
  fi
}
function menu(){
  clear
    echoContent green "
###################################################################
#                                                                 #
#           flexget刷流一键安装脚本                               #
#                    Powerby 翔翎                                 #
#                    Blog：https://blog.20120714.xyz              #
#                                                                 #
###################################################################"
echoContent yellow "是否开始执行脚本[Y/N],Ctrl+C退出脚本"
read start
if [[ ${start} == "Y" ]]||[[ ${start} == "y" ]]; then
  check_docker
  install_flexget
else
  echoContent red "输入错误，脚本退出······"
  exit 0
fi
}
menu
