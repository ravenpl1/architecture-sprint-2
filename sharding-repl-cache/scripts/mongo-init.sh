#!/bin/bash

###
# Инициализируем сервер конфигурации
###

docker compose exec -T configSrv mongosh --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF

###
# Инициализируем шарды
###

docker compose exec -T shard1_replica1 mongosh --port 27021 --quiet <<EOF
rs.initiate(
  {
    _id: "shard1_replicaset", members: [
      {_id: 0, host: "shard1_replica1:27021"},
      {_id: 1, host: "shard1_replica2:27022"},
      {_id: 2, host: "shard1_replica3:27023"}
    ]
  }
);
exit();
EOF

docker compose exec -T shard2_replica1 mongosh --port 27024 --quiet <<EOF
rs.initiate(
  {
    _id: "shard2_replicaset", members: [
      {_id: 0, host: "shard2_replica1:27024"},
      {_id: 1, host: "shard2_replica2:27025"},
      {_id: 2, host: "shard2_replica3:27026"}
    ]
  }
);
exit();
EOF

###
# Конфигурируем роутер: добавляем реплики, включаем шардирование
###

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1_replicaset/shard1_replica1:27021");
sh.addShard("shard1_replicaset/shard1_replica2:27022");
sh.addShard("shard1_replicaset/shard1_replica3:27023");
sh.addShard("shard2_replicaset/shard2_replica1:27024");
sh.addShard("shard2_replicaset/shard2_replica2:27025");
sh.addShard("shard2_replicaset/shard2_replica3:27026");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );

exit();
EOF

###
# Заполняем БД данными
###

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i});
print("Количество записей в БД: " + db.helloDoc.countDocuments() );
exit();
EOF

###
# Выводим количество записей и реплик в shard1
###
docker compose exec -T shard1_replica1 mongosh --port 27021 --quiet <<EOF
use somedb;
print("Количество записей в shard1: " + db.helloDoc.countDocuments());
print("Количество реплик в shard1: " + rs.conf().members.length );
exit();
EOF

###
# Выводим количество записей и реплик в shard2
###
docker compose exec -T shard2_replica1 mongosh --port 27024 --quiet <<EOF
use somedb;
print("Количество записей в shard2: " + db.helloDoc.countDocuments());
print("Количество реплик в shard2: " + rs.conf().members.length );
exit();
EOF
