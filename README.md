# Virgo OSGi bundles CLI

CLI tool to manage Virgo OSGi bundles.

These bash scripts will allow you upload, deploy and manage OSGi bundles at [Virgo OSGi server](http://www.eclipse.org/virgo/) and legacy [SpringSource dm Server](http://docs.spring.io/s2-dmserver/2.0.5.RELEASE/user-guide/htmlsingle/user-guide.html).


## Getting Started

This project provides 2 scripts to manage OSGi bundles at different servers:

* `virgo-bundles.sh` - Virgo OSGi server from EclipseRT
* `dmserver-bundles.sh` - SpringSource dm Server (legacy)

Use following format to run scripts:

    ./virgo-bundles.sh <command> [options]

### Commands

Script supports following commands:

* `deploy` - upload and deploy OSGi bundle to Virgo server, required options: `-f`
* `status` - check status of bundle at Virgo server, required options: `-n`, `-v`
* `stop` - stop bundle at Virgo server, required options: `-n`, `-v`
* `start` - start bundle at Virgo server, required options: `-n`, `-v`
* `refresh` - refresh bundle at Virgo server, required options: `-n`, `-v`
* `uninstall` - uninstall bundle from Virgo server, required options: `-n`, `-v`
* `help` - display help information

### Options

Following options are supported by script:

* `-f` _path_ - location of OSGi bundle to upload, e.g. /opt/repo/org.slf4j.api-1.7.2.jar
* `-n` _name_ - bundle symbolic name, e.g. org.slf4j.api
* `-v` _version_ - bundle version, e.g. 1.7.2
* `-t` _type_ - bundle type, possible types: bundle, plan, par, configuration, default: **bundle**
* `-user` _auth_ - user name and password for basic auth, e.g. admin:passwd
* `-url` _url_ - Virgo server URL, e.g. http://virgo.internal:7070
* `-verbose` - enable verbose output

### Examples

Upload and deploy a new OSGi bundle to Virgo server, deployed bundle will be activated:

    ./virgo-bundles.sh deploy -f ~/dev/virgo-test-1.0.0-SNAPSHOT.jar

Check status of deployed bundle, possible bundle states: ACTIVE, RESOLVED:

    ./virgo-bundles.sh status -n virgo-test -v 1.0.0.SNAPSHOT

Stop activated bundle at Virgo server:

    ./virgo-bundles.sh stop -n virgo-test -v 1.0.0.SNAPSHOT -url http://localhost:8081

Start deployed bundle at Virgo server:

    ./virgo-bundles.sh start -n virgo-test -v 1.0.0.SNAPSHOT -verbose

Refresh deployed bundle at Virgo server:

    ./virgo-bundles.sh refresh -n virgo-test -v 1.0.0.SNAPSHOT

Uninstall deployed bundle:

    ./virgo-bundles.sh uninstall -n virgo-test -v 1.0.0.SNAPSHOT


## References

* [Virgo from EclipseRT](http://www.eclipse.org/virgo/) official web site
* [Continuous Deployment with Docker and Virgo](http://eclipsesource.com/blogs/2013/10/25/continuous-deployment-with-docker-and-virgo/)
* [UploadServlet.java](https://eclipse.googlesource.com/virgo/org.eclipse.virgo.kernel/+/3.6.x/org.eclipse.virgo.management.console/src/main/java/org/eclipse/virgo/management/console/UploadServlet.java) from Virgo management console
* [Lates version of SpringSource dm Server](http://dist.springframework.org/release/DMS/springsource-dm-server-2.0.5.RELEASE.zip)
