#!/bin/bash

cd `dirname $0`

BASE_DIR=`pwd`
SPARK_FILE=spark-1.6.3-bin-hadoop2.6.tgz
#ES_FILE=elasticsearch-1.7.6.tar.gz
ES_FILE=elasticsearch-5.2.0.tar.gz
PIO_BIN_DIR=$BASE_DIR/PredictionIO-bin
TEMPLATE_DIR=$BASE_DIR/template
PATH=$PATH:$BASE_DIR/PredictionIO-bin/bin

stop_all() {
  if [ -f $PIO_BIN_DIR/bin/pio-stop-all ] ; then
    $PIO_BIN_DIR/bin/pio-stop-all
  fi
}

clean_all() {
  rm -rf $PIO_BIN_DIR
  rm -f PredictionIO-*.tar.gz
  $BASE_DIR/sbt/sbt clean
  rm -rf target $BASE_DIR/target
}

build() {
  bash $BASE_DIR/make-distribution.sh
}

replace_line() {
  REPLACEMENT=$1
  FILE=$2
  if [ `uname` = "Linux" ] ; then
    sed -i "$REPLACEMENT" "$FILE"
  else
    sed -i '' "$REPLACEMENT" "$FILE"
  fi
}

get_es_version() {
  echo $ES_FILE | grep elasticsearch-1 > /dev/null
  if [ $? = 0 ] ; then
    ES_VERSION=1
    return
  fi
  echo $ES_FILE | grep elasticsearch-5 > /dev/null
  if [ $? = 0 ] ; then
    ES_VERSION=5
    return
  fi
  echo "Unsupported $ES_FILE"
  exit 1
}

deploy_all() {
  PIO_NAME=`ls PredictionIO-*.tar.gz | sed -e "s/.tar.gz//"`
  if [ ! -e "$BASE_DIR/${PIO_NAME}.tar.gz" ] ; then
    echo "$BASE_DIR/${PIO_NAME}.tar.gz does not exist."
    exit 1
  fi
  tar zxvf ${PIO_NAME}.tar.gz
  mv $PIO_NAME $PIO_BIN_DIR

  mkdir $PIO_BIN_DIR/vendors

  if [ ! -f $BASE_DIR/$SPARK_FILE ] ; then
    wget http://d3kbcqa49mib13.cloudfront.net/$SPARK_FILE
  fi
  tar zxvfC $BASE_DIR/$SPARK_FILE $PIO_BIN_DIR/vendors > /dev/null

  get_es_version
  if [ ! -f $BASE_DIR/$ES_FILE ] ; then
    if [ $ES_VERSION = 1 ] ; then
      wget https://download.elasticsearch.org/elasticsearch/elasticsearch/$ES_FILE
    else
      wget https://artifacts.elastic.co/downloads/elasticsearch/$ES_FILE
    fi
  fi
  tar zxvfC $BASE_DIR/$ES_FILE $PIO_BIN_DIR/vendors > /dev/null


  if [ $ES_VERSION = 1 ] ; then
    ES_NAME=ELASTICSEARCH
  else
    ES_NAME=ELASTICSEARCH5
  fi
  PIO_ENV_FILE=$PIO_BIN_DIR/conf/pio-env.sh
  replace_line "s/# PIO_STORAGE_SOURCES_${ES_NAME}_/PIO_STORAGE_SOURCES_${ES_NAME}_/" $PIO_ENV_FILE
  replace_line "s/PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=${ES_NAME}/" $PIO_ENV_FILE
  replace_line "s/PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=${ES_NAME}/" $PIO_ENV_FILE
  replace_line "s/PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=LOCALFS/" $PIO_ENV_FILE
  replace_line "s/^PIO_STORAGE_SOURCES_PGSQL_/# PIO_STORAGE_SOURCES_PGSQL_/g" $PIO_ENV_FILE
  replace_line "s/# PIO_STORAGE_SOURCES_LOCALFS/PIO_STORAGE_SOURCES_LOCALFS/" $PIO_ENV_FILE

  ES_CONF_FILE=$PIO_BIN_DIR/vendors/elasticsearch-*/config/elasticsearch.yml
  echo 'http.cors.enabled: true' >> $ES_CONF_FILE
  echo 'http.cors.allow-origin: "*"' >> $ES_CONF_FILE
}

start_all() {
  echo "$PIO_BIN_DIR/bin/pio-start-all"
  $PIO_BIN_DIR/bin/pio-start-all
}

build_template() {
  cd $TEMPLATE_DIR
  rm -rf incubator-predictionio-template-recommender
  git clone https://github.com/jpioug/incubator-predictionio-template-recommender.git
  cd incubator-predictionio-template-recommender

  pio app new MyApp1
  pio app list

  ACCESS_KEY=`pio app list | grep MyApp1 | sed -e "s/.* | \(.*\) | (.*/\1/"`

  curl -s -i -X POST http://localhost:7070/events.json?accessKey=$ACCESS_KEY \
    -H "Content-Type: application/json" \
    -d '{
  "event" : "rate",
  "entityType" : "user",
  "entityId" : "u0",
  "targetEntityType" : "item",
  "targetEntityId" : "i0",
  "properties" : {
    "rating" : 5
  }
  "eventTime" : "2014-11-02T09:39:45.618-08:00"
}'

  curl -s -i -X POST http://localhost:7070/events.json?accessKey=$ACCESS_KEY \
    -H "Content-Type: application/json" \
    -d '{
  "event" : "buy",
  "entityType" : "user",
  "entityId" : "u1",
  "targetEntityType" : "item",
  "targetEntityId" : "i2",
  "eventTime" : "2014-11-10T12:34:56.123-08:00"
}'

  curl -s -i -X GET "http://localhost:9200/_refresh?pretty"
  curl -s -i -X GET "http://localhost:7070/events.json?accessKey=$ACCESS_KEY"

  if [ ! -f ../sample_movielens_data.txt ] ; then
    curl https://raw.githubusercontent.com/apache/spark/master/data/mllib/sample_movielens_data.txt --create-dirs -o ../sample_movielens_data.txt
  fi
  cp ../sample_movielens_data.txt data/sample_movielens_data.txt
  python data/import_eventserver.py --access_key $ACCESS_KEY

  replace_line "s/INVALID_APP_NAME/MyApp1/" engine.json

  pio build --verbose
}

train_template() {
  pio train
}

deploy_template() {
  pio deploy &
  sleep 15
  curl -s -H "Content-Type: application/json" -d '{ "user": "1", "num": 4 }' http://localhost:8000/queries.json
  echo
  kill $!
}


stop_all
clean_all

build
deploy_all
start_all

pio status

build_template
train_template
deploy_template

