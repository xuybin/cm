# 1 拉取镜像(镜像内包含cm的tar.gz文件和cdh的parcel-repo)
```
docker pull registry.cn-shenzhen.aliyuncs.com/xuybin/cm
```
### 可离线导入镜像 
```
docker save registry.cn-shenzhen.aliyuncs.com/xuybin/cm > cm.tar
docker load < cm.tar
```

# 2 编辑集群节点ip和hostname后,保存执行
```
wget https://raw.githubusercontent.com/xuybin/cm/master/cm.sh && chmod +x cm.sh
nano cm.sh
./cm.sh pwd1 pwd2 ...
```

# 3 配置主节点cloudera-scm-server需要的mysql数据库
```
cat /var/log/mysqld.log | grep password
mysql_secure_installation
[...]
Enter current password for root (enter for none):
OK, successfully used password, moving on...
[...]
Set root password? [Y/n] y
New password:
Re-enter new password:
Remove anonymous users? [Y/n] Y
[...]
Disallow root login remotely? [Y/n] N
[...]
Remove test database and access to it [Y/n] Y
[...]
Reload privilege tables now? [Y/n] Y
All done!

mysql -uroot -p
mysql> SELECT DISTINCT CONCAT('User: ''',user,'''@''',host,''';') AS query FROM mysql.user;
+------------------------------------+
| query                              |
+------------------------------------+
| User: 'mysql.session'@'localhost'; |
| User: 'mysql.sys'@'localhost';     |
| User: 'root'@'localhost';          |
+------------------------------------+
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
mysql> show variables like "character%";
+--------------------------+----------------------------+
| Variable_name            | Value                      |
+--------------------------+----------------------------+
| character_set_client     | utf8                       |
| character_set_connection | utf8                       |
| character_set_database   | utf8                       |
| character_set_filesystem | binary                     |
| character_set_results    | utf8                       |
| character_set_server     | utf8                       |
| character_set_system     | utf8                       |
| character_sets_dir       | /usr/share/mysql/charsets/ |
+--------------------------+----------------------------+

mysql> create database hive DEFAULT CHARSET utf8 COLLATE utf8_general_ci;

mysql> create database amon DEFAULT CHARSET utf8 COLLATE utf8_general_ci;

mysql> exit

/opt/cm-5.13.1/share/cmf/schema/scm_prepare_database.sh mysql scm数据库 scm数据库用户名 scm密码 -u具有创建权限的mysql用户名 -p具有创建权限的mysql用户密码

mysql -uroot -p
mysql> SELECT DISTINCT CONCAT('User: ''',user,'''@''',host,''';') AS query FROM mysql.user;
+------------------------------------+
| query                              |
+------------------------------------+
| User: 'mysql.session'@'localhost'; |
| User: 'mysql.sys'@'localhost';     |
| User: 'root'@'localhost';          |
| User: 'scm'@'localhost';           |
+------------------------------------+

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| amon               |
| hive               |
| mysql              |
| performance_schema |
| scm                |
| sys                |
+--------------------+

mysql> exit

```

# 4 启动
### 主节点启动cloudera-scm-server及查看日志
```
systemctl restart cloudera-scm-server
systemctl status cloudera-scm-server
systemctl enable cloudera-scm-server
tail -f /opt/cm-5.13.1/log/cloudera-scm-server/cloudera-scm-server.log
```
### 所有节点启动cloudera-scm-agent及查看日志
```
systemctl restart cloudera-scm-agent
systemctl status cloudera-scm-agent
systemctl enable cloudera-scm-agent
tail -f /opt/cm-5.13.1/log/cloudera-scm-agent/cloudera-scm-agent.log
```
# 5 使用admin:admin登陆http://主节点:7180/
选择 parcels模式,本地路径 /opt/cloudera/parcel-repo

# 6 安装失败或重装清理
```
systemctl stop cloudera-scm-agent &&  systemctl disable cloudera-scm-agent && systemctl stop cloudera-scm-server &&  systemctl disable cloudera-scm-server

rpm -qa |grep cloudera |xargs yum remove -y
rpm -qa |grep postgresql |xargs yum remove -y 
rpm -qa |grep oracle-j2sdk |xargs yum remove -y
rpm -qa |grep mysql |xargs yum remove -y && rm -rf /etc/mysql /var/lib/mysql /var/cache/yum/x86_64/7/mysql* /var/lib/yum/repos/x86_64/7/mysql* /var/log/mysqld.log
ps -ef |grep /opt/cm-5.13.1/
kill -9 ***
rm -rf /etc/init.d/cloudera-* /etc/default/cloudera-* /etc/yum.repos.d/cloudera* && yum clean all && rm -rf /var/cache/yum/yum/x86_64/7/cloudera* /var/lib/yum/repos/x86_64/7/cloudera* /var/cache/yum/x86_64/7/cloudera-*
rm -rf /opt/cm-* /usr/share/cmf /var/lib/cloudera* /var/cache/yum/x86_64/6/cloudera* /var/log/cloudera* /var/run/cloudera* /etc/cloudera* /opt/cloudera*  /etc/rc.d/rc0.d/K10cloudera-* /etc/rc.d/init.d/cloudera* /tmp/*  
cd /etc/rc.d/rc1.d/ && rm -rf K10cloudera-scm-agent K10cloudera-scm-server
cd /etc/rc.d/rc2.d/ && rm -rf K10cloudera-scm-agent K10cloudera-scm-server
cd /etc/rc.d/rc3.d/ && rm -rf K10cloudera-scm-agent K10cloudera-scm-server
cd /etc/rc.d/rc4.d/ && rm -rf K10cloudera-scm-agent K10cloudera-scm-server
cd /etc/rc.d/rc5.d/ && rm -rf K10cloudera-scm-agent K10cloudera-scm-server
cd /etc/rc.d/rc6.d/ && rm -rf K10cloudera-scm-agent K10cloudera-scm-server
find / -path *cloudera*
find / -path *cm-5.13.1*
```