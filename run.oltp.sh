DATADIR=/data/mariadb-10.5.4
BACKUPDIR=/mnt/data/mariadb-10.5.4-copy

#MYSQLDIR=

set -x
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

startmysql(){
  sync
  sysctl -q -w vm.drop_caches=3
  echo 3 > /proc/sys/vm/drop_caches
  ulimit -n 1000000
  systemctl set-environment MYSQLD_OPTS="$1"
  systemctl start mysql-cd
}

shutdownmysql(){
  echo "Shutting mysqld down..."
  systemctl stop mysql-cd
  systemctl set-environment MYSQLD_OPTS=""
}

waitmysql(){
        set +e

        while true;
        do
                ${MYSQLDIR}mysql -h127.0.0.1 -Bse "SELECT 1" mysql

                if [ "$?" -eq 0 ]
                then
                        break
                fi

                sleep 30

                echo -n "."
        done
        set -e
}

initialstat(){
  cp $CONFIG $OUTDIR
  cp $0 $OUTDIR
}

collect_mysql_stats(){
  ${MYSQLDIR}mysqladmin ext -i10 > $OUTDIR/mysqladminext.txt &
  PIDMYSQLSTAT=$!
}
collect_dstat_stats(){
  vmstat 1 > $OUTDIR/vmstat.out &
  PIDDSTATSTAT=$!
}



#shutdownmysql

RUNDIR=res-oltp-`hostname`-`date +%F-%H-%M`


#server: mariadb
#buffer_pool: 25
#randtype: uniform
#io_capacity: 15000
#storage: NVMe

#echo "XFS defrag"
#xfs_fsr /dev/nvme0n1

rockscache=60
threads=150
randtype="uniform"
memlimit=120

for rockscache in 60  
do

echo "Restoring backup"
#rm -fr $DATADIR
#cp -r $BACKUPDIR $DATADIR
#chown mysql.mysql -R $DATADIR
#fstrim /data

memlimit=$(( 2*$rockscache ))

#startmysql "--innodb-io-capacity=${io} --innodb_io_capacity_max=$iomax --innodb_buffer_pool_size=${BP}GB" &
#sleep 10
#waitmysql

docker run --name ps1  -e MYSQL_ROOT_PASSWORD=secret -e INIT_ROCKSDB=1 --net=host -m ${memlimit}g -v /mnt/data/db/ps-docker:/var/lib/mysql -v /mnt/data/vadim/servers/docker/my-rocks.cnf:/etc/mysql/my.cnf -v /data/tmp:/tmp  -d percona/percona-server:8.0.22 --rocksdb_block_cache_size=${rockscache}G
sleep 30

# perform warmup
#./tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=3600 --threads=56 --report-interval=1 --tables=10 --scale=100 --use_fk=1 run |  tee -a $OUTDIR/res.txt

#for i in $threads
for i in 50 40 30 20 10 5 1
do

runid="BP${rockscache}.threads${i}"

        OUTDIR=$RUNDIR/$runid
        mkdir -p $OUTDIR

echo "buffer_pool: $rockscache"         >> $OUTDIR/params.txt
echo "memlimit: $memlimit"         >> $OUTDIR/params.txt
echo "randtype: $randtype"      >> $OUTDIR/params.txt
echo "threads: $i"              >> $OUTDIR/params.txt
echo "host: `hostname`"         >> $OUTDIR/params.txt
echo "storagae: ssd"         >> $OUTDIR/params.txt
echo "engine: myrocks"         >> $OUTDIR/params.txt
echo "tablesize: $i"         >> $OUTDIR/params.txt

        # start stats collection


        time=1800
        sysbench oltp_read_write --threads=150 --time=$time --tables=40 --table_size=50000000 --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=secret --max-requests=0 --report-interval=1 --mysql-db=sbrocks --mysql-ssl=off  --report_csv=yes --rand-type=$randtype run |  tee -a $OUTDIR/results.txt
#        /mnt/data/vadim/bench/sysbench-tpcc/tpcc.lua --mysql-host=127.0.0.1 --mysql-user=sbtest --mysql-password=sbtest --mysql-db=sbtest --time=$time --threads=$i --report-interval=1 --tables=10 --scale=100 --use_fk=0 --report-csv=yes run |  tee -a $OUTDIR/res.thr${i}.txt


        sleep 30
done

docker stop ps1
docker rm -f ps1
#shutdownmysql

done
