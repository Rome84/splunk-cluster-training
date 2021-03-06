#!/bin/bash
# Template for bootstrapping.
# This is automatically placed in scenarioX/files/01-helper.sh
# The idea is that bootrapping will just execute any file called *-helper.sh
# living inside the files folder.

# Global Variables
# ================

# nfs mount back to your box.
base="/vagrant"

host_name=$1

# Splunk RPM get latest.
#splunk_rpm="${base}/files/rpm/splunk-6.5.1-f74036626f0c-linux-2.6-x86_64.rpm"
# Instal the newest file based on timestat. Best if you only put one file in there....
splunk_rpm="$(ls -tr ${base}/files/rpm/splunk*.rpm | tail -1)"

splunk_home="/opt/splunk"

splunk_executable="${splunk_home}/bin/splunk"


# Functions
# =========

check_return() {
  return=$1
  if [ $return -eq 0 ]; then
    echo "[OK]"
  else
    echo "Whoops: something went wrong with that last step"
    exit 1
  fi
}

# Main
# ====
# disable SELENUX.
sed -i 's/=enforcing/=disabled/g' /etc/sysconfig/selinux

# Install Splunk
yum -y update
yum clean all

yum -y install ${splunk_rpm}

# Configure splunk.
# ==================

# Make directories for each piece of splunk.

splunk_instances="sh1 sh2 sh3 sh4"
pwd=$(pwd)

for instance in $splunk_instances
do
  splunk_home="/opt/$instance"
  splunk_executable="${splunk_home}/bin/splunk"

  [ -d /opt/$instance ] || mkdir /opt/$instance
  cd /opt/splunk/; tar -cvf - . | (cd /opt/$instance; tar -xvf - )
  chown splunk.splunk /opt/$instance
  cd $pwd

  # Move in all Splunk configs into place.
  cd ${base}/files/$host_name
  files=$(find $instance -type f -print)
  cd $pwd

  for file in $files
  do
    cp ${base}/files/$host_name/$file /opt/$file
    chown splunk.splunk /opt/$file
  done

done
cd $pwd


# Enable services.
# ================
setsebool -P httpd_can_network_connect 1

# Start Splunk for the first time.

splunk_instances="sh1 sh2 sh3 sh4"

for instance in $splunk_instances
do
  splunk_home="/opt/$instance"
  splunk_executable="${splunk_home}/bin/splunk"

  su - splunk -c "export SPLUNK_HOME=${splunk_home}; ${splunk_executable} start --accept-license --answer-yes"
done

exit 0
