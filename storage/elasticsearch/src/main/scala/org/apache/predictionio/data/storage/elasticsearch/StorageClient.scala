/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.predictionio.data.storage.elasticsearch

import org.apache.http.HttpHost
import org.apache.predictionio.data.storage.BaseStorageClient
import org.apache.predictionio.data.storage.StorageClientConfig
import org.apache.predictionio.data.storage.StorageClientException
import org.elasticsearch.client.RestClient

import grizzled.slf4j.Logging

case class ESClient(hosts: Seq[HttpHost], config: StorageClientConfig) {
  def open(): RestClient = {
    try {
      RestClient.builder(hosts: _*).build()
    } catch {
      case e: Throwable =>
        throw new StorageClientException(e.getMessage, e)
    }
  }

  def getNumberOfShards(index: String): Option[Int] = {
    config.properties.get(s"${index}_NUM_OF_SHARDS").map(_.toInt)
  }

  def getNumberOfReplicas(index: String): Option[Int] = {
    config.properties.get(s"${index}_NUM_OF_REPLICAS").map(_.toInt)
  }

  def getEventDataRefresh(): String = {
    config.properties.getOrElse("EVENTDATA_REFRESH", "true")
  }
}

class StorageClient(val config: StorageClientConfig) extends BaseStorageClient
    with Logging {
  override val prefix = "ES"

  val client = ESClient(ESUtils.getHttpHosts(config), config)
}
