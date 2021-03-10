docker run --name ps1  -e MYSQL_ROOT_PASSWORD=secret -e INIT_ROCKSDB=1 --net=host -v /data/ps-docker:/var/lib/mysql -v /mnt/data/vadim/servers/docker/my-rocks-57.cnf:/etc/mysql/my.cnf -v /data/tmp:/tmp  -d percona/percona-server:5.7
#docker run --name ps1  -e MYSQL_ROOT_PASSWORD=secret -e INIT_ROCKSDB=1 --net=host -v /data/ps-docker:/var/lib/mysql  -d percona/percona-server:5.7
