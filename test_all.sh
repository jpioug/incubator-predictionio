#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

RUN_MODE=$1

PYTHON_CMD=`which python3`
if [ -z $PYTHON_CMD ] ; then
  PYTHON_CMD=python
fi

PIP_CMD=`which pip3`
if [ -z $PIP_CMD ] ; then
  PIP_CMD=pip
fi

stop_all() {
  if [ -f $PIO_HOME/bin/pio-stop-all ] ; then
    echo "#"
    echo "# Stop $PIO_HOME/bin/pio-stop-all"
    echo "#"
    $PIO_HOME/bin/pio-stop-all
  fi
}

clean_all() {
  echo "#"
  echo "# Clean up"
  echo "#"
  rm -rf $PIO_HOME
  rm -f PredictionIO-*.tar.gz
  $BASE_DIR/sbt/sbt clean
  rm -rf target $BASE_DIR/target
}

build() {
  echo "#"
  echo "# Build PredictionIO"
  echo "#"
  bash $BASE_DIR/make-distribution.sh -Delasticsearch.version=$ELASTICSEARCH_VERSION
#  $BASE_DIR/sbt/sbt common/publishLocal data/publishLocal core/publishLocal dataElasticsearch1/assembly dataElasticsearch/assembly dataHbase/assembly dataHdfs/assembly dataJdbc/assembly dataLocalfs/assembly e2/publishLocal tools/assembly assembly/universal:packageBin
  if [ $? != 0 ] ; then
    echo "Build Failed!"
    exit 1
  fi
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
  echo "#"
  echo "# Deploy PredictionIO"
  echo "#"
  PIO_NAME=`ls PredictionIO-*.tar.gz | sed -e "s/.tar.gz//"`
  if [ ! -e "$BASE_DIR/${PIO_NAME}.tar.gz" ] ; then
    echo "$BASE_DIR/${PIO_NAME}.tar.gz does not exist."
    exit 1
  fi
  tar zxvf ${PIO_NAME}.tar.gz
#  PIO_NAME=`basename $BASE_DIR/assembly/target/universal/*.zip | sed -e "s/.zip//"`
#  if [ ! -e "$BASE_DIR/assembly/target/universal/${PIO_NAME}.zip" ] ; then
#    echo "${PIO_NAME}.zip does not exist."
#    exit 1
#  fi
#  unzip $BASE_DIR/assembly/target/universal/${PIO_NAME}.zip
  mv $PIO_NAME $PIO_HOME

  mkdir $PIO_HOME/vendors

  if [ ! -f $BASE_DIR/$SPARK_FILE ] ; then
    wget http://d3kbcqa49mib13.cloudfront.net/$SPARK_FILE
  fi
  tar zxvfC $BASE_DIR/$SPARK_FILE $PIO_HOME/vendors > /dev/null
  echo "spark.locality.wait.node           0s" > `ls -d $PIO_HOME/vendors/spark-*/conf`/spark-defaults.conf

  get_es_version
  if [ ! -f $BASE_DIR/$ES_FILE ] ; then
    if [ $ES_VERSION = 1 ] ; then
      wget https://download.elasticsearch.org/elasticsearch/elasticsearch/$ES_FILE
    else
      wget https://artifacts.elastic.co/downloads/elasticsearch/$ES_FILE
    fi
  fi
  tar zxvfC $BASE_DIR/$ES_FILE $PIO_HOME/vendors > /dev/null


  ES_NAME=ELASTICSEARCH
  PIO_ENV_FILE=$PIO_HOME/conf/pio-env.sh
  #replace_line "s/# PIO_STORAGE_SOURCES_${ES_NAME}_/PIO_STORAGE_SOURCES_${ES_NAME}_/" $PIO_ENV_FILE
  replace_line "s/PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=${ES_NAME}/" $PIO_ENV_FILE
  replace_line "s/PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=${ES_NAME}/" $PIO_ENV_FILE
  replace_line "s/PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=LOCALFS/" $PIO_ENV_FILE
  replace_line "s/^PIO_STORAGE_SOURCES_PGSQL_/# PIO_STORAGE_SOURCES_PGSQL_/g" $PIO_ENV_FILE
  replace_line "s/# PIO_STORAGE_SOURCES_LOCALFS/PIO_STORAGE_SOURCES_LOCALFS/" $PIO_ENV_FILE
  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_TYPE=elasticsearch' >> $PIO_ENV_FILE
  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_HOSTS=localhost' >> $PIO_ENV_FILE
  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_PORTS=9200' >> $PIO_ENV_FILE
  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_SCHEMES=http' >> $PIO_ENV_FILE
  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_HOME=$PIO_HOME/vendors/elasticsearch-'$ELASTICSEARCH_VERSION >> $PIO_ENV_FILE

#  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_PIO_META_NUM_OF_SHARDS=1' >> $PIO_ENV_FILE
#  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_PIO_META_NUM_OF_REPLICAS=2' >> $PIO_ENV_FILE
#  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_PIO_EVENT_NUM_OF_SHARDS=10' >> $PIO_ENV_FILE
#  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_PIO_EVENT_NUM_OF_REPLICAS=1' >> $PIO_ENV_FILE
  echo 'PIO_STORAGE_SOURCES_ELASTICSEARCH_EVENTDATA_REFRESH=false' >> $PIO_ENV_FILE

  ES_CONF_FILE=$PIO_HOME/vendors/elasticsearch-*/config/elasticsearch.yml
  echo 'http.cors.enabled: true' >> $ES_CONF_FILE
  echo 'http.cors.allow-origin: "*"' >> $ES_CONF_FILE
  echo 'network.host: "0"' >> $ES_CONF_FILE

  echo "# $PIO_ENV_FILE"
  cat $PIO_ENV_FILE
  echo "# $ES_CONF_FILE"
  cat $ES_CONF_FILE
}

start_all() {
  echo "#"
  echo "# Start $PIO_HOME/bin/pio-start-all"
  echo "#"
  $PIO_HOME/bin/pio-start-all
}

build_template() {
  echo "#"
  echo "# Build $TEMPLATE_NAME"
  echo "#"
  mkdir -p $TEMPLATE_DIR
  cd $TEMPLATE_DIR
  rm -rf $TEMPLATE_NAME
  git clone https://github.com/jpioug/$TEMPLATE_NAME.git
  cd $TEMPLATE_NAME

  $PIO_CMD app new MyApp1
  $PIO_CMD app list

  ACCESS_KEY=`$PIO_CMD app list | grep MyApp1 | sed -e "s/.* | \(.*\) | (.*/\1/"`

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

  curl -s -i -X POST "http://localhost:9200/_refresh?pretty"
  curl -s -i -X GET "http://localhost:7070/events.json?accessKey=$ACCESS_KEY"

  if [ ! -f ../sample_movielens_data.txt ] ; then
    curl https://raw.githubusercontent.com/apache/spark/master/data/mllib/sample_movielens_data.txt --create-dirs -o ../sample_movielens_data.txt
  fi
  cp ../sample_movielens_data.txt data/sample_movielens_data.txt
  time $PYTHON_CMD data/import_eventserver.py --access_key $ACCESS_KEY

  replace_line "s/INVALID_APP_NAME/MyApp1/" engine.json

  $PIO_CMD build --verbose
}

train_template() {
  echo "#"
  echo "# Train $TEMPLATE_NAME"
  echo "#"
  cd $TEMPLATE_DIR/$TEMPLATE_NAME
  $PIO_CMD train
}

deploy_template() {
  echo "#"
  echo "# Deploy $TEMPLATE_NAME"
  echo "#"
  cd $TEMPLATE_DIR/$TEMPLATE_NAME
  $PIO_CMD deploy &
  sleep 15
  curl -s -H "Content-Type: application/json" -d '{ "user": "1", "num": 4 }' http://localhost:8000/queries.json
  echo
  kill $!
}


if [ x"$RUN_MODE" = "xtemplate" ] ; then
  BASE_DIR=/tmp/pio_run.$$
  mkdir -p $BASE_DIR
  cd $BASE_DIR

  PIO_HOME=/usr/share/predictionio
else # default
  cd `dirname $0`
  BASE_DIR=`pwd`

  ELASTICSEARCH_VERSION=5.3.1
  SPARK_FILE=spark-1.6.3-bin-hadoop2.6.tgz
  #ES_FILE=elasticsearch-1.7.6.tar.gz
  ES_FILE=elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz

  PIO_HOME=$BASE_DIR/PredictionIO-bin

  stop_all
  clean_all

  build
  deploy_all
  start_all
fi

PIO_CMD=$PIO_HOME/bin/pio
TEMPLATE_DIR=$BASE_DIR/template
TEMPLATE_NAME=incubator-predictionio-template-recommender

PIP_CMD install --upgrade predictionio

$PIO_CMD status

build_template
train_template
deploy_template
