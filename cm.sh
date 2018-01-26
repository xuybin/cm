#!/bin/bash

ntp_master='172.16.105.230'
ntp_master_hostname='ntp-master'
nodes_ip=(
'172.16.105.230'
'172.16.105.231'
'172.16.105.232'
'172.16.105.233'
'172.16.105.234'
)
nodes_hostname=(
'ntp-master'
'node1'
'node2'
'node3'
'node4'
)

etc_hosts="echo -e '
127.0.0.1       localhost.localdomain  localhost

172.16.105.230  ntp-master.localdomain ntp-master
172.16.105.231  node1.localdomain      node1
172.16.105.232  node2.localdomain      node2
172.16.105.233  node3.localdomain      node3
172.16.105.234  node4.localdomain      node4
'>/etc/hosts"

nodes_pwd=($*)
if [ ${#nodes_ip[@]} -ne ${#nodes_hostname[@]} ] || [ ${#nodes_pwd[@]} -ne ${#nodes_hostname[@]} ] ;then
  echo "nodes_ip与nodes_hostname数量必须相等"
  exit 1
fi

etc_sysconfig_network="echo -e '
NETWORKING=yes
NETWORKING_IPV6=no
#HOSTNAME=
'>/etc/sysconfig/network"

etc_ntp_conf="echo -e '
# 让硬件时间与系统时间一起同步
SYNC_HWCLOCK=yes
# 本地与上层服务器差值保存目录
driftfile  /var/lib/ntp/drift
# pid文件和日志文件路径
pidfile   /var/run/ntpd.pid
logfile /var/log/ntp.log
# ntp的默认设置
restrict default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
# 允许本地所有操作
restrict 127.0.0.1
restrict -6 ::1
# 允许内网其他机器从此同步时间
restrict 192.168.0.0 mask 255.255.0.0 nomodify notrap nopeer noquery
restrict 172.16.0.0 mask 255.240.0.0 nomodify notrap nopeer noquery
restrict 10.0.0.0 mask 255.0.0.0 nomodify notrap nopeer noquery
# 允许上层时间服务器主动修改本机时间
restrict ntp1.aliyun.com nomodify notrap nopeer noquery
restrict ntp2.aliyun.com nomodify notrap nopeer noquery
restrict ntp3.aliyun.com nomodify notrap nopeer noquery
restrict ntp4.aliyun.com nomodify notrap nopeer noquery
restrict ntp5.aliyun.com nomodify notrap nopeer noquery
restrict ntp6.aliyun.com nomodify notrap nopeer noquery
# 外部时间服务器
server ntp1.aliyun.com iburst minpoll 4 maxpoll 10
server ntp2.aliyun.com iburst minpoll 4 maxpoll 10
server ntp3.aliyun.com iburst minpoll 4 maxpoll 10
server ntp4.aliyun.com iburst minpoll 4 maxpoll 10
server ntp5.aliyun.com iburst minpoll 4 maxpoll 10
server ntp6.aliyun.com iburst minpoll 4 maxpoll 10
# 外部时间服务器不可用时，以本地时间作为时间服务
server  127.127.1.0   # local clock
fudge   127.127.1.0   stratum 10
# 给客户端设置认证信息
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
'>/etc/ntp.conf"


etc_sysconfig_ntpdate="echo -e '
# Options for ntpdate
OPTIONS=\"-p 2\"
# Number of retries before giving up
RETRIES=2
# 让硬件时间与系统时间一起同步
SYNC_HWCLOCK=yes
'>/etc/sysconfig/ntpdate"

etc_mycnf="sed -i '/^# innodb_buffer_pool_size = 128M/ s:.*:\
key_buffer_size = 32M\n\
max_allowed_packet = 32M\n\
thread_stack = 256K\n\
thread_cache_size = 64\n\
query_cache_limit = 8M\n\
query_cache_size = 64M\n\
query_cache_type = 1\n\
\n\
max_connections = 550\n\
read_buffer_size = 2M\n\
read_rnd_buffer_size = 16M\n\
sort_buffer_size = 8M\n\
join_buffer_size = 8M\n\
\n\
innodb_file_per_table = 1\n\
innodb_flush_log_at_trx_commit  = 2\n\
innodb_log_buffer_size = 64M\n\
innodb_buffer_pool_size = 4G\n\
innodb_thread_concurrency = 8\n\
innodb_flush_method = O_DIRECT\n\
innodb_log_file_size = 512M\n\
\n\
sql_mode=STRICT_ALL_TABLES\n\
init_connect=\"SET NAMES utf8\"\n\
\n\
character_set_server=utf8\n\
:'  /etc/my.cnf "

etc_profile="sed -i '/^# \/etc\/profile/ s:.*:export JAVA_HOME=/usr/java/default\nexport PATH=\$JAVA_HOME/bin\:\$PATH\nexport CLASSPATH=.\:\$JAVA_HOME/lib\:\$CLASSPATH\n:' /etc/profile "
etc_rclocal="sed -i '/^# that this script will be executed during boot./ s:.*:echo never > \/sys\/kernel\/mm\/transparent_hugepage\/defrag\necho never > \/sys\/kernel\/mm\/transparent_hugepage\/enabled\n:' /etc/rc.local "
etc_sysctlconf="sed -i '/^# For more information/ s:.*:vm.swappiness=10\n:' /etc/sysctl.conf "
cloudera_scm_server="sed -i '/^CMF_DEFAULTS=\${CMF_DEFAULTS/ s:.*:CMF_DEFAULTS=/opt/cm-5.13.1/etc/default\n:' /opt/cm-5.13.1/etc/init.d/cloudera-scm-server " 
cloudera_scm_agent="sed -i '/^CMF_DEFAULTS=\${CMF_DEFAULTS/ s:.*:CMF_DEFAULTS=/opt/cm-5.13.1/etc/default\n:' /opt/cm-5.13.1/etc/init.d/cloudera-scm-agent " 
mkdir -p /root/rpm && mkdir -p /root/parcel-repo
docker run --rm  -v /root/rpm:/opt/cloudera/rpm  -v /root/parcel-repo:/opt/cloudera/parcel-repo  registry.cn-shenzhen.aliyuncs.com/xuybin/cm

yum install sshpass -y   
rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub && ssh-keygen -t rsa -f /root/.ssh/id_rsa -P '' -q
for i in "${!nodes_ip[@]}"; do
  hostname clouderaManager &&  sshpass -p "${nodes_pwd[$i]}" ssh-copy-id root@${nodes_ip[$i]}
  scp /root/.ssh/*  ${nodes_ip[$i]}:/root/.ssh/
done
yum remove sshpass -y -q
 
for i in "${!nodes_ip[@]}"; do
  printf "##########################################################\n%s\t INSTALL ENV TO %s\t%s\n" "$i" "${nodes_ip[$i]}" "${nodes_hostname[$i]}"
  ssh ${nodes_ip[$i]} "\
  		rm -rf /etc/yum.repos.d/cloudera* /opt/cloudera/*   /opt/cm-*  /var/lib/cloudera-scm-server/* \
      && systemctl stop firewalld && systemctl disable firewalld  \
      && yum -y install ntpdate ntp crontabs && ${etc_ntp_conf} && ${etc_sysconfig_ntpdate} && ntpdate -u ntp1.aliyun.com \
      && yum remove java-1.7.0-openjdk* -y && yum remove java-1.8.0-openjdk* -y && ${etc_profile} && source /etc/profile \
      && sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config \
      && sed -i 's/GRUB_CMDLINE_LINUX=\"rd/GRUB_CMDLINE_LINUX=\"ipv6.disable=1 rd/' /etc/default/grub && grub2-mkconfig -o /boot/grub2/grub.cfg \
      && ${etc_hosts} && hostname ${nodes_hostname[$i]} && ${etc_sysconfig_network} && sed -i \"s/#HOSTNAME=/HOSTNAME=${nodes_hostname[$i]}/\" /etc/sysconfig/network \
      && ${etc_rclocal} && chmod +x /etc/rc.d/rc.local  && echo never > /sys/kernel/mm/transparent_hugepage/defrag && echo never > /sys/kernel/mm/transparent_hugepage/enabled \
      && ${etc_sysctlconf} && sysctl -p \
      && mkdir -p /opt/cloudera/rpm  /var/spool/cron\
    "
    scp /root/rpm/*  ${nodes_ip[$i]}:/opt/cloudera/rpm/
    ssh ${nodes_ip[$i]} "useradd -r -M -d /opt/cm-5.13.1/run/cloudera-scm-server  -s /sbin/nologin -c 'Cloudera Manager' cloudera-scm"
    
    ssh ${nodes_ip[$i]} "\
    	tar zxf /opt/cloudera/rpm/cloudera-manager-centos7.tar.gz -C /opt/ \
    	&& rm -rf /etc/init.d/cloudera-scm-server /etc/init.d/cloudera-scm-agent \
   		&& ${cloudera_scm_agent} && ln -f -s /opt/cm-5.13.1/etc/init.d/cloudera-scm-agent /etc/init.d/ \
    	&& sed -i \"s/server_host=localhost/server_host=${ntp_master_hostname}/\" /opt/cm-5.13.1/etc/cloudera-scm-agent/config.ini \
    	&& yum localinstall -y  /opt/cloudera/rpm/jdk8.rpm \
    "
  if [ "${nodes_ip[$i]}" == "${ntp_master}" ]; then
    ssh ${nodes_ip[$i]} "\
			echo ''>/var/spool/cron/root && crontab -l \
      && systemctl stop crond && systemctl disable crond \
      && systemctl start ntpd &&  systemctl enable ntpd \
      && ${cloudera_scm_server} && ln -f -s /opt/cm-5.13.1/etc/init.d/cloudera-scm-server /etc/init.d/ \
      && mkdir -p /usr/share/java /var/lib/cloudera-scm-server /opt/cloudera/parcel-repo && chown -R cloudera-scm:cloudera-scm /var/lib/cloudera-scm-server /opt/cloudera/parcel-repo \
      && mv -f /opt/cloudera/rpm/mysql-connector-java.jar /usr/share/java/ \
      && wget -q -O '/tmp/mysql-community-release-el7-5.noarch.rpm' http://repo.mysql.com/mysql57-community-release-el7-11.noarch.rpm &&yum localinstall -y /tmp/mysql-community-release-el7-5.noarch.rpm && yum -y install mysql-server \
      &&rm -rf /var/lib/mysql /var/log/mysqld.log && ${etc_mycnf} && systemctl restart mysqld && systemctl enable mysqld \
    "
    scp /root/parcel-repo/* ${nodes_ip[$i]}:/opt/cloudera/parcel-repo/
  else
    ssh ${nodes_ip[$i]} "\
			echo -e '0-59/10 * * * * /usr/sbin/ntpdate ntp-master\n' >/var/spool/cron/root && crontab -l  \
      && systemctl start crond && systemctl enable crond \
      && systemctl stop ntpd &&  systemctl disable ntpd \
    "
  fi
  
  ssh ${nodes_ip[$i]} "\
  	systemctl daemon-reload \
  	&& rename sha1 sha /opt/cloudera/parcel-repo/* \
  	&& chown -R cloudera-scm:cloudera-scm /opt/cloudera /opt/cm-5.13.1 \
    && rm -rf /opt/cloudera/rpm/cloudera-manager-centos7.tar.gz  /opt/cloudera/rpm/jdk8.rpm \ 
  "
done
rm -r -f /root/rpm  /root/parcel-repo
          