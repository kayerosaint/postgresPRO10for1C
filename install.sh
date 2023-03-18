#!/bin/bash
# Script to install postgresql 10 pro for 1C on Centos 7
# You need root credentials to apply
# If something breaks, then use the "make restore" command to restore the postgresql configuration file

# Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Cyan='\033[0;36m'         # Cyan
Color_Off='\033[0m'       # Reset

# Directives #
POSTGRES=/var/lib/pgpro/1c-10/data/postgresql.conf
TEMP_FILE=tmp.md
TEMP_FILE_1=tmp_1.md
touch='if [ 1 == 1 ]; then sudo touch $1; fi'
set -- $TEMP_FILE && eval "$touch" ; set -- $TEMP_FILE_1 && eval "$touch" ; sudo chmod 0755 $TEMP_FILE_1 $TEMP_FILE
CUR_DIR=$(pwd)

# logs
exec 2>logs+errors

# ssh enable
echo -e "$Cyan \n SSH Enable $Color_Off"
chkconfig sshd on;
service sshd start;
sleep 1;

# net-tools
echo -e "$Cyan \n Install net-tools $Color_Off"
sudo yum -y install net-tools;

# update system
echo -e "$Cyan \n System update, pls wait $Color_Off"
yum update -y >/dev/null ;
yum -y install epel-release >/dev/null ;

# create users?
echo -e "$Cyan \n Create new user? $Color_Off"
  echo "1 - yes, 2 - no"
  read new_user
  case $new_user in
    1)
    sleep 2
    echo -e "$Yellow \n Enter new user name!: $Color_Off"
    read -p "Username: " user
    sudo useradd -m $user
    echo -e "$Yellow \n Enter new user password!: $Color_Off"
    read -s -p "User password: " u_pswd
    sudo passwd $u_pswd ;;
    2)
    echo -e "$Red \n aborted $Color_Off"
    sleep 1 ;;
    *)
    echo -e "$Red \n error $Color_Off"
    sleep 1
    esac

# create users?
echo -e "$Cyan \n Add selected user to group WHEEL? $Color_Off"
  echo "1 - yes, 2 - no"
  read wheel_group
  case $wheel_group in
    1)
    sleep 2
    sed 's/:.*//' /etc/passwd
    echo -e "$Yellow \n Enter the name of the user who be added to the WHEEL group!: $Color_Off"
    read -p "Username: " user_1
    sudo usermod -a -G wheel $user_1
    echo -e "$Yellow \n added $Color_Off" ;;
    2)
    echo -e "$Red \n aborted $Color_Off"
    sleep 1 ;;
    *)
    echo -e "$Red \n error $Color_Off"
    sleep 1
    esac

# install midnight commander
echo -e "$Cyan \n MC install $Color_Off"
echo "" > $TEMP_FILE ; sudo rpm -qa | grep mc-4.* >> $TEMP_FILE
if ! grep -q "mc" $TEMP_FILE; then
  yum install –y mc
else
  echo -e "$Green \n already installed $Color_Off"
fi

## pre install postgres
echo -e "$Cyan \n Prepare for Postgres install $Color_Off"
rpm --import http://repo.postgrespro.ru/keys/GPG-KEY-POSTGRESPRO;
echo [postgrespro-1c] > /etc/yum.repos.d/postgrespro-1c.repo;
echo name=Postgres Pro 1C repo >> /etc/yum.repos.d/postgrespro-1c.repo;
echo baseurl=http://repo.postgrespro.ru/1c-archive/pg1c-10.6/centos/7/os/x86_64/rpms >> /etc/yum.repos.d/postgrespro-1c.repo;
echo gpgcheck=1 >> /etc/yum.repos.d/postgrespro-1c.repo;
echo enabled=1 >> /etc/yum.repos.d/postgrespro-1c.repo;
sleep 1;

# check cache
yum makecache;

# install postgres
echo -e "$Cyan \n Postgres install $Color_Off"
echo "" > $TEMP_FILE ; sudo rpm -qa | grep postgrespro-* >> $TEMP_FILE
if ! grep -q "postgrespro" $TEMP_FILE; then
  yum install -y postgrespro-1c-10-server-10.6-1.el7.x86_64 postgrespro-1c-10-contrib-10.6-1.el7.x86_64
else
  echo -e "$Green \n already installed $Color_Off"
fi

# enable service
/opt/pgpro/1c-10/bin/pg-setup initdb && /opt/pgpro/1c-10/bin/pg-setup service enable && service postgrespro-1c-10 start;

# install htop+aha
echo -e "$Cyan \n htop+aha+html2txt install $Color_Off"
echo "" > $TEMP_FILE ; sudo rpm -qa | grep htop-* >> $TEMP_FILE && sudo rpm -qa | grep aha-* >> $TEMP_FILE && sudo rpm -qa | grep html2text-* >> $TEMP_FILE
if ! grep -q "htop" $TEMP_FILE && ! grep -q "aha" $TEMP_FILE && ! grep -q "html2" $TEMP_FILE ; then
  yum -y install htop aha html2text
else
  echo -e "$Green \n already installed $Color_Off" && sleep 1
fi
# get stats
echo q | htop -C | aha --line-fix | html2text | grep -v "F1Help" | grep -v "xml version=" > cfg.md && sudo chmod 0755 cfg.md

# permissions
echo -e "$Cyan \n Set permission to postgres folder $Color_Off"
chmod 0700 /var/lib/pgpro/1c-10 && chmod 0700 /var/lib/pgpro/1c-10/data/ && chmod 0644 /var/lib/pgpro/1c-10/data/postgresql.conf

# copy
echo -e "$Cyan \n Copy non-configured file to current location $Color_Off" && sleep 1;
if ! [ -e $CUR_DIR/postgresql_non*.conf ] ; then
  cp /var/lib/pgpro/1c-10/data/postgresql.conf $CUR_DIR/postgresql_non-configured_$(date "+%Y-%m-%d").conf && chmod 755 $CUR_DIR/postgresql_non*.conf;
fi

# number raws
raw_n=$(awk 'END{ print NR }' postgresql_non*.conf);

# Configure postgres
echo -e "$Yellow \n Begin configure postgres $Color_Off"
echo -e "$Yellow \n WARNING! >>>random_page_cost<<< parameter will be set at 1.7 optimized for RAID $Color_Off"
echo -e "$Yellow \n WARNING! >>>effective_io_concurrency<<< parameter will be set at 2 optimized for RAID $Color_Off"
echo -e "$Yellow \n if you want to change it, pls configure manually $Color_Off" && sleep 8;
sudo sed -i "s|#row_security = on|row_security = off|g" $POSTGRES
sudo sed -i "s|#ssl = off|ssl = off|g" $POSTGRES
get1=$(awk -F'/' 'FNR==5 {print $2}' cfg.md | awk -F'G]' '{print $1*1000/1000}') && printf '%.*f\n' 0 $get1 | awk '{print $1*1000/4}' > $TEMP_FILE && get1_1=$(cat $TEMP_FILE) ; printf '%.*f\n' 0 $get1_1 | awk '{print $1"MB"}' > $TEMP_FILE_1 && buffers=$(awk '{print $1}' $TEMP_FILE_1) && sudo sed -i "s|shared_buffers = 128MB|shared_buffers = $buffers|g" $POSTGRES
#buffers=$(awk -F'/' 'FNR==5 {print $2}' cfg.md | awk -F'G]' '{print $1*1000/4"MB"}') && sudo sed -i "s|shared_buffers = 128MB|shared_buffers = $buffers|g" $POSTGRES
sudo sed -i "s|#temp_buffers = 8MB|temp_buffers = 256MB|g" $POSTGRES
get2=$(awk -F'/' 'FNR==5 {print $2}' cfg.md | awk -F'G]' '{print $1*1000/1000}') && printf '%.*f\n' 0 $get2 | awk '{print $1*1000/32}' > $TEMP_FILE && get2_1=$(cat $TEMP_FILE) ; printf '%.*f\n' 0 $get2_1 | awk '{print $1"MB"}' > $TEMP_FILE_1 && mem=$(awk '{print $1}' $TEMP_FILE_1) && sudo sed -i "s|#work_mem = 4MB|work_mem = $mem|g" $POSTGRES
#mem=$(awk -F'/' 'FNR==5 {print $2}' cfg.md | awk -F'G]' '{print $1*1000/32"MB"}') && sudo sed -i "s|#work_mem = 4MB|work_mem = $mem|g" $POSTGRES
sudo sed -i "s|#fsync = on|fsync = on|g" $POSTGRES
sudo sed -i "s|#checkpoint_completion_target = 0.5|checkpoint_completion_target = 0.5|g" $POSTGRES
sudo sed -i "s|#synchronous_commit = on|synchronous_commit = off|g" $POSTGRES
sudo sed -i "s|#min_wal_size = 80MB|min_wal_size = 512MB|g" $POSTGRES
sudo sed -i "s|#max_wal_size = 1GB|max_wal_size = 1GB|g" $POSTGRES
sudo sed -i "s|#commit_delay = 0|commit_delay = 1000|g" $POSTGRES
sudo sed -i "s|#commit_siblings = 5|commit_siblings = 5|g" $POSTGRES
sudo sed -i "s|#bgwriter_delay = 200ms|bgwriter_delay = 20ms|g" $POSTGRES
sudo sed -i "s|#bgwriter_lru_multiplier = 2.0|bgwriter_lru_multiplier = 4.0|g" $POSTGRES
sudo sed -i "s|#bgwriter_lru_maxpages = 100|bgwriter_lru_maxpages = 400|g" $POSTGRES
sudo sed -i "s|#autovacuum = on|autovacuum = on|g" $POSTGRES
a="4" && get3=$(awk -F'thr; ' 'FNR==3 {print $2}' cfg.md | awk -F' running' '{print $1/2}') && printf '%.*f\n' 0 $get3 | awk '{print $1}' > $TEMP_FILE && b=$(awk '{print $1}' $TEMP_FILE)
if [ "$a" -gt "$b" ]; then
  sudo sed -i "s|#autovacuum_max_workers = 3|autovacuum_max_workers = $a|g" $POSTGRES
else
  sudo sed -i "s|#autovacuum_max_workers = 3|autovacuum_max_workers = $b|g" $POSTGRES
fi
sudo sed -i "s|#autovacuum_naptime = 1min|autovacuum_naptime = 20s|g" $POSTGRES
sudo sed -i "s|#max_files_per_process = 1000|max_files_per_process = 8000|g" $POSTGRES
get3=$(awk -F'/' 'FNR==5 {print $2}' cfg.md | awk -F'G]' '{print $1*1000/1000}') && printf '%.*f\n' 0 $get3 | awk '{print $1*1000"MB"}' > $TEMP_FILE && cache_size=$(awk '{print $1}' $TEMP_FILE) && sudo sed -i "s|#effective_cache_size = 4GB|effective_cache_size = $cache_size|g" $POSTGRES
#cache_size=$(awk -F'/' 'FNR==5 {print $2}' cfg.md | awk -F'G]' '{print $1*1000"MB"}') && sudo sed -i "s|#effective_cache_size = 4GB|effective_cache_size = $cache_size|g" $POSTGRES
sudo sed -i "s|#random_page_cost = 4.0|random_page_cost = 1.7|g" $POSTGRES
sudo sed -i "s|#from_collapse_limit = 8|from_collapse_limit = 20|g" $POSTGRES
sudo sed -i "s|#join_collapse_limit = 8|join_collapse_limit = 20|g" $POSTGRES
sudo sed -i "s|#geqo = on|geqo = on|g" $POSTGRES
sudo sed -i "s|#geqo_threshold = 12|geqo_threshold = 12|g" $POSTGRES
sudo sed -i "s|#effective_io_concurrency = 1|effective_io_concurrency = 2|g" $POSTGRES
sudo sed -i "s|#standard_conforming_strings = on|standard_conforming_strings = off|g" $POSTGRES
sudo sed -i "s|#escape_string_warning = on|escape_string_warning = off|g" $POSTGRES
sudo sed -i "s|#max_locks_per_transaction = 64|max_locks_per_transaction = 150|g" $POSTGRES
sudo sed -i "s|max_connections = 100|max_connections = 2000|g" $POSTGRES
echo -e "$Yellow \n Configured $Color_Off" && sleep 2

### chkconfig ###
echo -e "$Cyan \n Now config will be checked, pls wait! $Color_Off" && sleep 2;

if ! grep -q "row_security = off" $POSTGRES; then
  line=$(awk '/row_security/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/row_security/{ print NR; exit }' $POSTGRES)
  done
  echo "row_security = off" >> $POSTGRES && echo -e "$Yellow \n row_security fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/row_security/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/row_security/{ print NR; exit }' $POSTGRES)
    done
    echo "row_security = off" >> $POSTGRES;
  fi
  echo -e "$Green \n row_security ok $Color_Off" && sleep 0.3 ;
fi

# ssl
if ! grep -q "ssl = off" $POSTGRES; then
  line=$(awk '/ssl/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/ssl/{ print NR; exit }' $POSTGRES)
  done
  echo "ssl = off" >> $POSTGRES && echo -e "$Yellow \n ssl fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/ssl/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/ssl/{ print NR; exit }' $POSTGRES)
    done
    echo "ssl = off" >> $POSTGRES;
  fi
  echo -e "$Green \n ssl ok $Color_Off" && sleep 0.3 ;
fi

# shared_buffers
if ! grep -q "shared_buffers = $buffers" $POSTGRES; then
  line=$(awk '/shared_buffers/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/shared_buffers/{ print NR; exit }' $POSTGRES)
  done
  echo "shared_buffers = $buffers" >> $POSTGRES && echo -e "$Yellow \n shared_buffers fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/shared_buffers/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/shared_buffers/{ print NR; exit }' $POSTGRES)
    done
    echo "shared_buffers = $buffers" >> $POSTGRES;
  fi
  echo -e "$Green \n shared_buffers ok $Color_Off" && sleep 0.3 ;
fi

# temp_buffers
if ! grep -q "temp_buffers = 256MB" $POSTGRES; then
  line=$(awk '/temp_buffers/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/temp_buffers/{ print NR; exit }' $POSTGRES)
  done
  echo "temp_buffers = 256MB" >> $POSTGRES && echo -e "$Yellow \n temp_buffers fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/temp_buffers/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/temp_buffers/{ print NR; exit }' $POSTGRES)
    done
    echo "temp_buffers = 256MB" >> $POSTGRES;
  fi
  echo -e "$Green \n temp_buffers ok $Color_Off" && sleep 0.3 ;
fi

# work_mem
if ! grep -q "work_mem = $mem" $POSTGRES; then
  line=$(awk '/work_mem/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/work_mem/{ print NR; exit }' $POSTGRES)
  done
  echo "work_mem = $mem" >> $POSTGRES && echo -e "$Yellow \n work_mem fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/work_mem/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/work_mem/{ print NR; exit }' $POSTGRES)
    done
    echo "work_mem = $mem" >> $POSTGRES;
  fi
  echo -e "$Green \n work_mem ok $Color_Off" && sleep 0.3 ;
fi

# fsync
if ! grep -q "fsync = on" $POSTGRES; then
  line=$(awk '/fsync =/{ print NR; exit }' $POSTGRES) && sed -i "${line}d" $POSTGRES && echo "fsync = on" >> $POSTGRES && echo -e "$Yellow \n fsync fixed $Color_Off" && sleep 0.3 ;
else
  echo -e "$Green \n fsync ok $Color_Off" && sleep 0.3 ;
fi
if ! grep -q "fsync = on" $POSTGRES; then
  line=$(awk '/fsync/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/fsync/{ print NR; exit }' $POSTGRES)
  done
  echo "fsync = on" >> $POSTGRES && echo -e "$Yellow \n fsync fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/fsync/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/fsync/{ print NR; exit }' $POSTGRES)
    done
    echo "fsync = on" >> $POSTGRES;
  fi
  echo -e "$Green \n fsync ok $Color_Off" && sleep 0.3 ;
fi

# checkpoint_completion_target
if ! grep -q "checkpoint_completion_target = 0.5" $POSTGRES; then
  line=$(awk '/checkpoint_completion_target/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/checkpoint_completion_target/{ print NR; exit }' $POSTGRES)
  done
  echo "checkpoint_completion_target = 0.5" >> $POSTGRES && echo -e "$Yellow \n checkpoint_completion_target fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/checkpoint_completion_target/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/checkpoint_completion_target/{ print NR; exit }' $POSTGRES)
    done
    echo "checkpoint_completion_target = 0.5" >> $POSTGRES;
  fi
  echo -e "$Green \n checkpoint_completion_target ok $Color_Off" && sleep 0.3 ;
fi

# synchronous_commit
if ! grep -q "synchronous_commit = off" $POSTGRES; then
  line=$(awk '/synchronous_commit/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/synchronous_commit/{ print NR; exit }' $POSTGRES)
  done
  echo "synchronous_commit = off" >> $POSTGRES && echo -e "$Yellow \n synchronous_commit fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/synchronous_commit/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/synchronous_commit/{ print NR; exit }' $POSTGRES)
    done
    echo "synchronous_commit = off" >> $POSTGRES;
  fi
  echo -e "$Green \n synchronous_commit ok $Color_Off" && sleep 0.3 ;
fi

# min_wal_size
if ! grep -q "min_wal_size = 512MB" $POSTGRES; then
  line=$(awk '/min_wal_size/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/min_wal_size/{ print NR; exit }' $POSTGRES)
  done
  echo "min_wal_size = 512MB" >> $POSTGRES && echo -e "$Yellow \n min_wal_size fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/min_wal_size/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/min_wal_size/{ print NR; exit }' $POSTGRES)
    done
    echo "min_wal_size = 512MB" >> $POSTGRES;
  fi
  echo -e "$Green \n min_wal_size ok $Color_Off" && sleep 0.3 ;
fi

# max_wal_size
if ! grep -q "max_wal_size = 1GB" $POSTGRES; then
  line=$(awk '/max_wal_size/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/max_wal_size/{ print NR; exit }' $POSTGRES)
  done
  echo "max_wal_size = 1GB" >> $POSTGRES && echo -e "$Yellow \n max_wal_size fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/max_wal_size/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/max_wal_size/{ print NR; exit }' $POSTGRES)
    done
    echo "max_wal_size = 1GB" >> $POSTGRES;
  fi
  echo -e "$Green \n max_wal_size ok $Color_Off" && sleep 0.3 ;
fi

# commit_delay
if ! grep -q "commit_delay = 1000" $POSTGRES; then
  line=$(awk '/commit_delay/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/commit_delay/{ print NR; exit }' $POSTGRES)
  done
  echo "commit_delay = 1000" >> $POSTGRES && echo -e "$Yellow \n commit_delay fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/commit_delay/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/commit_delay/{ print NR; exit }' $POSTGRES)
    done
    echo "commit_delay = 1000" >> $POSTGRES;
  fi
  echo -e "$Green \n commit_delay ok $Color_Off" && sleep 0.3 ;
fi

# commit_siblings
if ! grep -q "commit_siblings = 5" $POSTGRES; then
  line=$(awk '/commit_siblings/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/commit_siblings/{ print NR; exit }' $POSTGRES)
  done
  echo "commit_siblings = 5" >> $POSTGRES && echo -e "$Yellow \n commit_siblings fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/commit_siblings/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/commit_siblings/{ print NR; exit }' $POSTGRES)
    done
    echo "commit_siblings = 5" >> $POSTGRES;
  fi
  echo -e "$Green \n commit_siblings ok $Color_Off" && sleep 0.3 ;
fi

# bgwriter_delay
if ! grep -q "bgwriter_delay = 20ms" $POSTGRES; then
  line=$(awk '/bgwriter_delay/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/bgwriter_delay/{ print NR; exit }' $POSTGRES)
  done
  echo "bgwriter_delay = 20ms" >> $POSTGRES && echo -e "$Yellow \n bgwriter_delay fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/bgwriter_delay/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/bgwriter_delay/{ print NR; exit }' $POSTGRES)
    done
    echo "bgwriter_delay = 20ms" >> $POSTGRES;
  fi
  echo -e "$Green \n bgwriter_delay ok $Color_Off" && sleep 0.3 ;
fi

# bgwriter_lru_multiplier
if ! grep -q "bgwriter_lru_multiplier = 4.0" $POSTGRES; then
  line=$(awk '/bgwriter_lru_multiplier/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/bgwriter_lru_multiplier/{ print NR; exit }' $POSTGRES)
  done
  echo "bgwriter_lru_multiplier = 4.0" >> $POSTGRES && echo -e "$Yellow \n bgwriter_lru_multiplier fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/bgwriter_lru_multiplier/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/bgwriter_lru_multiplier/{ print NR; exit }' $POSTGRES)
    done
    echo "bgwriter_lru_multiplier = 4.0" >> $POSTGRES;
  fi
  echo -e "$Green \n bgwriter_lru_multiplier ok $Color_Off" && sleep 0.3 ;
fi

# bgwriter_lru_maxpages
if ! grep -q "bgwriter_lru_maxpages = 400" $POSTGRES; then
  line=$(awk '/bgwriter_lru_maxpages/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/bgwriter_lru_maxpages/{ print NR; exit }' $POSTGRES)
  done
  echo "bgwriter_lru_maxpages = 400" >> $POSTGRES && echo -e "$Yellow \n bgwriter_lru_maxpages fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/bgwriter_lru_maxpages/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/bgwriter_lru_maxpages/{ print NR; exit }' $POSTGRES)
    done
    echo "bgwriter_lru_maxpages = 400" >> $POSTGRES;
  fi
  echo -e "$Green \n bgwriter_lru_maxpages ok $Color_Off" && sleep 0.3 ;
fi

# autovacuum
if ! grep -q "autovacuum = on" $POSTGRES; then
  line=$(awk '/autovacuum/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum/{ print NR; exit }' $POSTGRES)
  done
  echo "autovacuum = on" >> $POSTGRES && echo -e "$Yellow \n autovacuum fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/autovacuum/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum/{ print NR; exit }' $POSTGRES)
    done
    echo "autovacuum = on" >> $POSTGRES;
  fi
  echo -e "$Green \n autovacuum ok $Color_Off" && sleep 0.3 ;
fi

# autovacuum_max_workers
a="4" && get4=$(awk -F'thr; ' 'FNR==3 {print $2}' cfg.md | awk -F' running' '{print $1/2}') && printf '%.*f\n' 0 $get4 | awk '{print $1}' > $TEMP_FILE && b=$(awk '{print $1}' $TEMP_FILE)
if [ "$a" -gt "$b" ]; then
  sudo sed -i "s|#autovacuum_max_workers = 3|autovacuum_max_workers = $a|g" $POSTGRES
  if ! grep -q "autovacuum_max_workers = $a" $POSTGRES; then
    line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES) &&
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES)
    done
    echo "autovacuum_max_workers = $a" >> $POSTGRES && echo -e "$Yellow \n autovacuum_max_workers fixed $Color_Off" && sleep 0.3 ;
  else
    line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES) &&
    if [ ${line} > "1" ]; then
      while [ ${line} > "0" ]
      do
      sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES)
      done
      echo "autovacuum_max_workers = $a" >> $POSTGRES;
    fi
    echo -e "$Green \n autovacuum_max_workers ok $Color_Off" && sleep 0.3 ;
  fi
else
  autovacuum=$b && sudo sed -i "s|#autovacuum_max_workers = 3|autovacuum_max_workers = $b|g" $POSTGRES
  if ! grep -q "autovacuum_max_workers = $b" $POSTGRES; then
    line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES) &&
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES)
    done
    echo "autovacuum_max_workers = $b" >> $POSTGRES && echo -e "$Yellow \n autovacuum_max_workers fixed $Color_Off" && sleep 0.3 ;
  else
    line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES) &&
    if [ ${line} > "1" ]; then
      while [ ${line} > "0" ]
      do
      sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum_max_workers/{ print NR; exit }' $POSTGRES)
      done
      echo "autovacuum_max_workers = $b" >> $POSTGRES;
    fi
    echo -e "$Green \n autovacuum_max_workers ok $Color_Off" && sleep 0.3 ;
  fi
fi

# autovacuum_naptime
if ! grep -q "autovacuum_naptime = 20s" $POSTGRES; then
  line=$(awk '/autovacuum_naptime/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum_naptime/{ print NR; exit }' $POSTGRES)
  done
  echo "autovacuum_naptime = 20s" >> $POSTGRES && echo -e "$Yellow \n autovacuum_naptime fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/autovacuum_naptime/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/autovacuum_naptime/{ print NR; exit }' $POSTGRES)
    done
    echo "autovacuum_naptime = 20s" >> $POSTGRES;
  fi
  echo -e "$Green \n autovacuum_naptime ok $Color_Off" && sleep 0.3 ;
fi

# max_files_per_process
if ! grep -q "max_files_per_process = 8000" $POSTGRES; then
  line=$(awk '/max_files_per_process/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/max_files_per_process/{ print NR; exit }' $POSTGRES)
  done
  echo "max_files_per_process = 8000" >> $POSTGRES && echo -e "$Yellow \n max_files_per_process fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/max_files_per_process/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/max_files_per_process/{ print NR; exit }' $POSTGRES)
    done
    echo "max_files_per_process = 8000" >> $POSTGRES;
  fi
  echo -e "$Green \n max_files_per_process ok $Color_Off" && sleep 0.3 ;
fi

# effective_cache_size
if ! grep -q "effective_cache_size = $cache_size" $POSTGRES; then
  line=$(awk '/effective_cache_size/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/effective_cache_size/{ print NR; exit }' $POSTGRES)
  done
  echo "effective_cache_size = $cache_size" >> $POSTGRES && echo -e "$Yellow \n effective_cache_size fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/effective_cache_size/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/effective_cache_size/{ print NR; exit }' $POSTGRES)
    done
    echo "effective_cache_size = $cache_size" >> $POSTGRES;
  fi
  echo -e "$Green \n effective_cache_size ok $Color_Off" && sleep 0.3 ;
fi

# random_page_cost
if ! grep -q "random_page_cost = 1.7" $POSTGRES; then
  line=$(awk '/random_page_cost/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/random_page_cost/{ print NR; exit }' $POSTGRES)
  done
  echo "random_page_cost = 1.7" >> $POSTGRES && echo -e "$Yellow \n random_page_cost fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/random_page_cost/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/random_page_cost/{ print NR; exit }' $POSTGRES)
    done
    echo "random_page_cost = 1.7" >> $POSTGRES;
  fi
  echo -e "$Green \n random_page_cost ok $Color_Off" && sleep 0.3 ;
fi

# from_collapse_limit
if ! grep -q "from_collapse_limit = 20" $POSTGRES; then
  line=$(awk '/from_collapse_limit/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/from_collapse_limit/{ print NR; exit }' $POSTGRES)
  done
  echo "from_collapse_limit = 20" >> $POSTGRES && echo -e "$Yellow \n from_collapse_limit fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/from_collapse_limit/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/from_collapse_limit/{ print NR; exit }' $POSTGRES)
    done
    echo "from_collapse_limit = 20" >> $POSTGRES;
  fi
  echo -e "$Green \n from_collapse_limit ok $Color_Off" && sleep 0.3 ;
fi

# join_collapse_limit
if ! grep -q "join_collapse_limit = 20" $POSTGRES; then
  line=$(awk '/join_collapse_limit/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/join_collapse_limit/{ print NR; exit }' $POSTGRES)
  done
  echo "join_collapse_limit = 20" >> $POSTGRES && echo -e "$Yellow \n join_collapse_limit fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/join_collapse_limit/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/join_collapse_limit/{ print NR; exit }' $POSTGRES)
    done
    echo "join_collapse_limit = 20" >> $POSTGRES;
  fi
  echo -e "$Green \n join_collapse_limit ok $Color_Off" && sleep 0.3 ;
fi

# geqo
if ! grep -q "geqo = on" $POSTGRES; then
  line=$(awk '/geqo/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/geqo/{ print NR; exit }' $POSTGRES)
  done
  echo "geqo = on" >> $POSTGRES && echo -e "$Yellow \n geqo fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/geqo/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/geqo/{ print NR; exit }' $POSTGRES)
    done
    echo "geqo = on" >> $POSTGRES;
  fi
  echo -e "$Green \n geqo ok $Color_Off" && sleep 0.3 ;
fi

# geqo_threshold
if ! grep -q "geqo_threshold = 12" $POSTGRES; then
  line=$(awk '/geqo_threshold/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/geqo_threshold/{ print NR; exit }' $POSTGRES)
  done
  echo "geqo_threshold = 12" >> $POSTGRES && echo -e "$Yellow \n geqo_threshold fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/geqo_threshold/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/geqo_threshold/{ print NR; exit }' $POSTGRES)
    done
    echo "geqo_threshold = 12" >> $POSTGRES;
  fi
  echo -e "$Green \n geqo_threshold ok $Color_Off" && sleep 0.3 ;
fi

# effective_io_concurrency
if ! grep -q "effective_io_concurrency = 2" $POSTGRES; then
  line=$(awk '/effective_io_concurrency/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/effective_io_concurrency/{ print NR; exit }' $POSTGRES)
  done
  echo "effective_io_concurrency = 2" >> $POSTGRES && echo -e "$Yellow \n effective_io_concurrency fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/effective_io_concurrency/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/effective_io_concurrency/{ print NR; exit }' $POSTGRES)
    done
    echo "effective_io_concurrency = 2" >> $POSTGRES;
  fi
  echo -e "$Green \n effective_io_concurrency ok $Color_Off" && sleep 0.3 ;
fi

# standard_conforming_strings
if ! grep -q "standard_conforming_strings = off" $POSTGRES; then
  line=$(awk '/standard_conforming_strings/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/standard_conforming_strings/{ print NR; exit }' $POSTGRES)
  done
  echo "standard_conforming_strings = off" >> $POSTGRES && echo -e "$Yellow \n standard_conforming_strings fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/standard_conforming_strings/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/standard_conforming_strings/{ print NR; exit }' $POSTGRES)
    done
    echo "standard_conforming_strings = off" >> $POSTGRES;
  fi
  echo -e "$Green \n standard_conforming_strings ok $Color_Off" && sleep 0.3 ;
fi

# escape_string_warning
if ! grep -q "escape_string_warning = off" $POSTGRES; then
  line=$(awk '/escape_string_warning/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/escape_string_warning/{ print NR; exit }' $POSTGRES)
  done
  echo "escape_string_warning = off" >> $POSTGRES && echo -e "$Yellow \n escape_string_warning fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/escape_string_warning/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/escape_string_warning/{ print NR; exit }' $POSTGRES)
    done
    echo "escape_string_warning = off" >> $POSTGRES;
  fi
  echo -e "$Green \n escape_string_warning ok $Color_Off" && sleep 0.3 ;
fi

# max_locks_per_transaction
if ! grep -q "max_locks_per_transaction = 150" $POSTGRES; then
  line=$(awk '/max_locks_per_transaction/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/max_locks_per_transaction/{ print NR; exit }' $POSTGRES)
  done
  echo "max_locks_per_transaction = 150" >> $POSTGRES && echo -e "$Yellow \n max_locks_per_transaction fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/max_locks_per_transaction/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/max_locks_per_transaction/{ print NR; exit }' $POSTGRES)
    done
    echo "max_locks_per_transaction = 150" >> $POSTGRES;
  fi
  echo -e "$Green \n max_locks_per_transaction ok $Color_Off" && sleep 0.3 ;
fi

# max_connections
if ! grep -q "max_connections = 2000" $POSTGRES; then
  line=$(awk '/max_connections/{ print NR; exit }' $POSTGRES) &&
  while [ ${line} > "0" ]
  do
  sed -i "${line}d" $POSTGRES && line=$(awk '/max_connections/{ print NR; exit }' $POSTGRES)
  done
  echo "max_connections = 2000" >> $POSTGRES && echo -e "$Yellow \n max_connections fixed $Color_Off" && sleep 0.3 ;
else
  line=$(awk '/max_connections/{ print NR; exit }' $POSTGRES) &&
  if [ ${line} > "1" ]; then
    while [ ${line} > "0" ]
    do
    sed -i "${line}d" $POSTGRES && line=$(awk '/max_connections/{ print NR; exit }' $POSTGRES)
    done
    echo "max_connections = 2000" >> $POSTGRES;
  fi
  echo -e "$Green \n max_connections ok $Color_Off" && sleep 0.3 ;
fi

# full check
if awk -v str='max_connections|max_locks_per_transaction|escape_string_warning|row_security|ssl|shared_buffers|temp_buffers|work_mem|fsync|checkpoint_completion_target|synchronous_commit|min_wal_size|max_wal_size|commit_delay|commit_siblings|bgwriter_delay|bgwriter_lru_multiplier|bgwriter_lru_maxpages|autovacuum|autovacuum_max_workers|autovacuum_naptime|max_files_per_process|effective_cache_size|random_page_cost|from_collapse_limit|join_collapse_limit|geqo|geqo_threshold|effective_io_concurrency|standard_conforming_strings' -f search.awk $POSTGRES ; then
  echo -e "$Green \n CONFIGURATION FILE OK! $Color_Off"
else
  make restore >/dev/null
  echo -e "$Red \n WARNING! Postgres configuration file was corrupted and will be restored! YOU NEED TO RUN THIS SCRIPT AGAIN! $Color_Off"
fi
if [ "$raw_n" -gt "658" ] ; then
  echo -e "$Green \n CONFIGURATION FILE OK! $Color_Off" > /dev/null;
else
  make restore >/dev/null
  echo -e "$Red \n WARNING! Postgres configuration file was corrupted and will be restored to default! YOU NEED TO RUN THIS SCRIPT AGAIN! $Color_Off" && sleep 5 && exit
fi

# postgres restart
echo -e "$Cyan \n Restart postgres $Color_Off"
sudo service postgrespro-1c-10 restart > /dev/null;

# chk status
echo -e "$Cyan \n Check service postgres status $Color_Off"
sudo service postgrespro-1c-10 status > $TEMP_FILE ;
awk -F'Active:' 'FNR==3 {print $2}' $TEMP_FILE | awk -F'since' '{print "\033[33m"$1" \033[0m";}' && sleep 2;
if grep -q "failed" $TEMP_FILE; then
echo -e "$Red \n WARNING! Postgres didnt start properly. Script was stopped! $Color_Off" && sleep 3 &&
exit;
fi

# create path
echo -e "$Cyan \n Create path, symlink, permission $Color_Off" && sleep 1;
service postgrespro-1c-10 stop ;

sqldata=/home/sqldata
if [ -d "$sqldata" ]; then
  echo -e "$Green \n directory exist! $Color_Off $sqldata" && sleep 1;
else
  mkdir /home/sqldata && echo -e "$Yellow \n Directory created! $Color_Off $sqldata" && sleep 1;
fi

ls -l /home/sqldata > $TEMP_FILE &&
if ! grep -q "postgres postgres" $TEMP_FILE; then
  chown postgres /home/sqldata ;
else
  echo "" ;
fi

stat -c "%a" /home/sqldata > $TEMP_FILE && cat $TEMP_FILE | tr -d '\n' >/dev/null && if echo "700" >/dev/null ; then
  echo -e "$Green \n Permissions ok for.. $Color_Off $sqldata" && sleep 1;
else
  chmod 0700 /home/sqldata ;
fi

sqldata1=/home/sqldata/data
if [ -d "$sqldata1" ]; then
  echo -e "$Green \n directory exist! $Color_Off $sqldata1" && sleep 1;
else
  sudo mv /var/lib/pgpro/1c-10/data /home/sqldata && echo -e "$Yellow \n Directory moved! $Color_Off $sqldata1" && sleep 1;
fi

ln -s /home/sqldata/data /var/lib/pgpro/1c-10/data ;
service postgrespro-1c-10 start ;

# open firewall
echo -e "$Cyan \n Open firewall $Color_Off" && sleep 0.5;
firewall-cmd --permanent --add-port=5432/tcp && firewall-cmd --reload ;

# chk secure_path
echo -e "$Cyan \n Check secure path $Color_Off" && sleep 1 ;
if ! grep -q "Defaults    secure_path =" /etc/sudoers; then
  line=$(awk '/Defaults    secure_path =/{ print NR; exit }' /etc/sudoers) && sed -i "${line}d" /etc/sudoers && echo "Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/opt/pgpro/1c-10/bin/" >> /etc/sudoers && echo -e "$Yellow \n secure_path corrected $Color_Off" && sleep 0.3
else
  echo -e "$Green \n secure_path ok $Color_Off" && sleep 0.3
fi

# change postgres password
echo -e "$Yellow \n WARNING! Postges password will be set >>000<<< , you could change it manually $Color_Off" && sleep 5;
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '000';"

# copy postgres config file to current dirrectory
echo -e "$Cyan \n Copy config file to current location $Color_Off" && sleep 1;
cp /var/lib/pgpro/1c-10/data/postgresql.conf $CUR_DIR/postgresql_configured_$(date "+%Y-%m-%d").conf && sudo rm -rf $CUR_DIR/cfg.md && sudo rm -rf $CUR_DIR/$TEMP_FILE $CUR_DIR/$TEMP_FILE_1 $CUR_DIR/0 $CUR_DIR/1;
service postgrespro-1c-10 status
