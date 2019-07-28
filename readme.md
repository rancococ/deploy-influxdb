
## InfluxDB

### influxdb
```
port:8086
environment
    - INFLUXDB_DB=db0
    - INFLUXDB_ADMIN_ENABLED=true
    - INFLUXDB_ADMIN_USER=admin 
    - INFLUXDB_ADMIN_PASSWORD=supersecretpassword
    - INFLUXDB_USER=telegraf
    - INFLUXDB_USER_PASSWORD=secretpassword
volume
    $PWD:/var/lib/influxdb
```
