#!/bin/bash

# sudo -u postgres dropuser shinsuke
# sudo -u postgres createuser -s shinsuke
# createdb pio
# psql -c "create user pio with password 'pio'" pio

# sed -i "s/\.\.\/\.\/conf/\/Users\/shinsuke\/workspace\/predictionio\/conf/" */.classpath

cd `dirname $0`
BASE_DIR=`pwd`

SPARK_FILE=spark-1.6.3-bin-hadoop2.6.tgz
#ES_FILE=elasticsearch-2.4.3.tar.gz
ES_FILE=elasticsearch-5.1.2.tar.gz

PIO_BIN_DIR=$BASE_DIR/PredictionIO-bin

if [ -f $PIO_BIN_DIR/bin/pio-stop-all ] ; then
    $PIO_BIN_DIR/bin/pio-stop-all
fi

rm -rf $PIO_BIN_DIR
rm -f PredictionIO-*.tar.gz

$BASE_DIR/sbt/sbt clean
rm -rf target $BASE_DIR/target
bash $BASE_DIR/make-distribution.sh

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

if [ ! -f $BASE_DIR/$ES_FILE ] ; then
    #wget https://download.elasticsearch.org/elasticsearch/elasticsearch/$ES_FILE
    wget https://artifacts.elastic.co/downloads/elasticsearch/$ES_FILE
fi
tar zxvfC $BASE_DIR/$ES_FILE $PIO_BIN_DIR/vendors > /dev/null

sed -i '' "s/# PIO_STORAGE_SOURCES_ELASTICSEARCH/PIO_STORAGE_SOURCES_ELASTICSEARCH/" $PIO_BIN_DIR/conf/pio-env.sh
# sed -i '' "s/# PIO_STORAGE_SOURCES_ELASTICSEARCH_HOSTS/PIO_STORAGE_SOURCES_ELASTICSEARCH_HOSTS/" $PIO_BIN_DIR/conf/pio-env.sh
# sed -i '' "s/# PIO_STORAGE_SOURCES_ELASTICSEARCH_PORTS/PIO_STORAGE_SOURCES_ELASTICSEARCH_PORTS/" $PIO_BIN_DIR/conf/pio-env.sh
# sed -i '' "s/# PIO_STORAGE_SOURCES_ELASTICSEARCH_HOME/PIO_STORAGE_SOURCES_ELASTICSEARCH_HOME/" $PIO_BIN_DIR/conf/pio-env.sh

sed -i '' "s/PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_METADATA_SOURCE=ELASTICSEARCH/" $PIO_BIN_DIR/conf/pio-env.sh
sed -i '' "s/PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_EVENTDATA_SOURCE=ELASTICSEARCH/" $PIO_BIN_DIR/conf/pio-env.sh
sed -i '' "s/PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=PGSQL/PIO_STORAGE_REPOSITORIES_MODELDATA_SOURCE=LOCALFS/" $PIO_BIN_DIR/conf/pio-env.sh

sed -i '' "s/^PIO_STORAGE_SOURCES_PGSQL_/# PIO_STORAGE_SOURCES_PGSQL_/g" $PIO_BIN_DIR/conf/pio-env.sh

sed -i '' "s/# PIO_STORAGE_SOURCES_LOCALFS/PIO_STORAGE_SOURCES_LOCALFS/" $PIO_BIN_DIR/conf/pio-env.sh

echo 'http.cors.enabled: true' >> $PIO_BIN_DIR/vendors/elasticsearch-*/config/elasticsearch.yml
echo 'http.cors.allow-origin: "*"' >> $PIO_BIN_DIR/vendors/elasticsearch-*/config/elasticsearch.yml

echo "$PIO_BIN_DIR/bin/pio-start-all"
#ES_JAVA_OPTS="-Dmapper.allow_dots_in_name=true" $PIO_BIN_DIR/bin/pio-start-all
# $PIO_BIN_DIR/bin/pio-start-all

# $BASE_DIR/tmp/run.sh | tee /tmp/pio_template.log

