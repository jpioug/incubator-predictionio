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

import NativePackagerHelper._
import RpmConstants._
import com.typesafe.sbt.packager.linux.LinuxSymlink

enablePlugins(RpmPlugin, DebianPlugin)

name := "predictionio"

maintainer in Linux := "Apache Software Foundation"
packageSummary in Linux := "Apache PredictionIO"
packageDescription := "Apache PredictionIO is an open source Machine Learning Server built on top of state-of-the-art open source stack for developers and data scientists create predictive engines for any machine learning task."

version in Rpm := version.value.replace("-", "_")
rpmRelease := "1"
rpmVendor := "apache"
rpmUrl := Some("http://predictionio.incubator.apache.org/")
rpmLicense := Some("Apache License Version 2.0")

maintainerScripts in Rpm := maintainerScriptsAppendFromFile((maintainerScripts in Rpm).value)(
   Pre -> (sourceDirectory.value / "rpm" / "scriptlets" / "preinst"),
   Postun -> (sourceDirectory.value / "rpm" / "scriptlets" / "postun")
)

mappings in Universal ++= {
  val releaseFile = baseDirectory.value / ".." / "RELEASE.md"
  val envFile = baseDirectory.value / "src" / "universal" / "conf" / "pio-env.sh.template"
  val buildPropFile = baseDirectory.value / ".." / "project" / "build.properties"
  val sbtFile = baseDirectory.value / ".." / "sbt" / "sbt"
  Seq(releaseFile -> "RELEASE",
      envFile -> "conf/pio-env.sh",
      buildPropFile -> "project/build.properties",
      sbtFile -> "sbt/sbt")
}

mappings in Universal := {
  val universalMappings = (mappings in Universal).value
  universalMappings filter {
    case (file, name) => !name.endsWith(".template") && !name.endsWith("travis")
  }
}

linuxPackageMappings := {
    val mappings = linuxPackageMappings.value
    mappings map {  linuxPackage =>
        val linuxFileMappings = linuxPackage.mappings map {
            case (f, n) if f.getName equals "conf" => f -> s"/etc/${name.value}"
            case (f, n) if f.getName equals "pio-env.sh.template" => f -> s"/etc/${name.value}/pio-env.sh"
            case (f, n) if f.getParent endsWith "conf" => f -> s"/etc/${name.value}/${f.getName}"
            case (f, n) if f.getName equals "log" => f -> s"/var/log/${name.value}"
            case (f, n) if f.getName equals "pio.log" => f -> s"/var/log/${name.value}/pio.log"
            case (f, n) => f -> n
        }

        val fileData = linuxPackage.fileData.copy(
            user = s"${name.value}",
            group = s"${name.value}"
        )

        linuxPackage.copy(
            mappings = linuxFileMappings,
            fileData = fileData
        )
    }
}

linuxPackageSymlinks := {
  Seq(LinuxSymlink("/usr/bin/pio", s"/usr/share/${name.value}/bin/pio"),
      LinuxSymlink("/usr/bin/pio-daemon", s"/usr/share/${name.value}/bin/pio-daemon"))
}
