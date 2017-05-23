#!/bin/bash
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

set -e
export PYTHONPATH=$PIO_HOME/tests:$PYTHONPATH
echo "Sleeping $SLEEP_TIME seconds for all services to be ready..."
sleep $SLEEP_TIME

# create S3 bucket in localstack
aws --endpoint-url=http://localstack:4572 --region=us-east-1 s3 mb s3://pio_bucket

eval $@
