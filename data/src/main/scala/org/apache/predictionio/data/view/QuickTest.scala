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


package org.apache.predictionio.data.view

import org.apache.predictionio.data.storage.Storage

import scala.concurrent.ExecutionContext.Implicits.global // TODO

import org.joda.time.DateTime

import scala.language.implicitConversions

class TestHBLEvents(s: Storage) {
  def run(): Unit = {
    val r = s.getLEvents().find(
      appId = 1,
      startTime = None,
      untilTime = None,
      entityType = Some("pio_user"),
      entityId = Some("3")).toList

    println(r)
  }
}

class TestSource(val appId: Int, storage: Storage) {
  @transient lazy val batchView = new LBatchView(appId,
    None, None, storage)

  def run(): Unit = {
    println(batchView.events)
  }
}

object QuickTest {

  def main(args: Array[String]) {
    Storage.using { implicit s =>
      val t = new TestHBLEvents(s)
      t.run()

      // val ts = new TestSource(args(0).toInt, s)
      // ts.run()
    }
  }
}

object TestEventTime {

  // implicit def back2list(es: EventSeq) = es.events

  def main(args: Array[String]) {
    Storage.using { implicit s =>
      val batchView = new LBatchView(9, None, None, s)
      val e = batchView.events.filter(
        eventOpt = Some("rate"),
        startTimeOpt = Some(new DateTime(1998, 1, 1, 0, 0))
        // untilTimeOpt = Some(new DateTime(1997, 1, 1, 0, 0))
      )
      // untilTimeOpt = Some(new DateTime(2000, 1, 1, 0, 0)))

      e.foreach { println }
      println()
      println()
      println()
      val u = batchView.aggregateProperties("pio_item")
      u.foreach { println }
      println()
      println()
      println()

      // val l: Seq[Event] = e
      val l = e.map { _.entityId }
      l.foreach { println }
    }
  }

}
