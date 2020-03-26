Oracle Database 18c (version 18.4.0)
============================



## Build from source
```sh
git clone git@github.com:KyleAure/oracle-docker-images.git
cd oracle-docker-images/src
./prebuild.sh
```

## Pull from dockerhub
```sh
docker pull kyleaure/oracle-18.4.0-xe-prebuilt
```

## Quick Start

Run with port 1521 (database) open and port 5500 (OEM Express) open.
```sh
docker run -d -p 1521:1521 -p 5500:5500 kyleaure/oracle-18.4.0-xe-prebuilt
```

Expected output (SAMPLE):
```txt
[INFO] The Oracle base remains unchanged with value /opt/oracle
[INFO] #########################
[INFO] DATABASE IS READY TO USE!
[INFO] #########################
[INFO] The following output is now a tail of the alert.log:
[INFO] XEPDB1(3):Undo initialization online undo segments: err:0 start: 715481124 end: 715481236 diff: 112 ms (0.1 seconds)
[INFO] XEPDB1(3):Undo initialization finished serial:0 start:715481118 end:715481242 diff:124 ms (0.1 seconds)
[INFO] XEPDB1(3):Database Characterset for XEPDB1 is AL32UTF8
[INFO] 2020-03-25T23:19:12.079190+00:00
[INFO] XEPDB1(3):Opening pdb with Resource Manager plan: DEFAULT_PLAN
[INFO] Pluggable database XEPDB1 opened read write
[INFO] Starting background process CJQ0
[INFO]2020-03-25T23:19:12.688515+00:00
[INFO] CJQ0 started with pid=59, OS id=626 
[INFO] Completed: ALTER DATABASE OPEN
```

## Connecting to database

### General Information

```txt
hostname: localhost
port: 1521
sid: xe
service name: xe
pdb service name: XEPDB1
username: system
password: oracle
```

Password for SYS & SYSTEM
```txt
oracle
```

### SQLPlus (Local)
Connect to database using SQLPlus on your local system:
```sh
sqlplus sys/oracle@//localhost:1521/XE as sysdba
sqlplus system/oracle@//localhost:1521/XE
sqlplus pdbadmin/oracle@//localhost:1521/XEPDB1
```

### SQLPlus (Container)
Connect to database using SQLPlus from inside the database container:
```sh
docker exec -it --user oracle <container-name> /bin/sh -c 'sqlplus / as sysdba'
docker exec -it --user oracle <container-name> /bin/sh -c 'sqlplus system/oracle'
docker exec -it --user oracle <container-name> /bin/sh -c 'sqlplus pdbadmin@XEPDB1/oracle'
```

### JDBC URLs
Use these URLs to connect to the database using a current JDBC driver
```URL
jdbc:oracle:thin:system/oracle@//localhost:1521:XE
jdbc:oracle:thin:system/oracle@//localhost:1521/XE
jdbc:oracle:thin:system/oracle@//localhost:1521/XEPDB1
```

## Extend image
Support custom DB Initialization and running shell scripts
```Dockerfile
# Dockerfile
FROM kyleaure/oracle-18.4.0-xe-prebuilt

ADD init.sql /opt/oracle/scripts/startup
ADD script.sh /opt/oracle/scripts/startup
```
Running order is alphabetically. 