# @title README

# README

## Name

fluent-plugin-groonga

## Description

Fluent-plugin-groonga is a [Fluentd](http://www.fluentd.org/) plugin collection to use
[Groonga](http://groonga.org/) with Fluentd. Fluent-plugin-groonga
supports the following two usages:

  * Store logs collected by Fluentd to Groonga.

  * Implement replication system for Groonga.

The first usage is normal usage. You can store logs to Groonga and
find logs by full-text search.

The second usage is for Groonga users. Groonga itself doesn't support
replication. But Groonga users can replicate their data by
fluent-plugin-groonga.

Fluent-plugin-groonga includes an input plugin and an output
plugin. Both of them are named `groonga`.

If you want to use fluent-plugin-groonga to store logs to Groonga, you
need to use only `groonga` output plugin.

The following configuration stores all data in `/var/log/messages`
into Groonga:

    <source>
      @type tail
      format syslog
      path /var/log/syslog.1
      pos_file /tmp/messages.pos
      tag log.messages
      read_from_head true
    </source>

    <match log.**>
      @type groonga
      store_table logs

      protocol http
      host 127.0.0.1

      buffer_type file
      buffer_path /tmp/buffer
      flush_interval 1
    </match>

If you want to use fluent-plugin-groonga to implement Groonga
replication system, you need to use both plugins.

The input plugin provides Groonga compatible interface. It means that
HTTP and GQTP interface. You can use the input plugin as Groonga
server. The input plugin receives Groonga commands and sends them to
the output plugin through zero or more Fluentds.

The output plugin sends received Groonga commands to Groonga. The
output plugin supports all interfaces, HTTP, GQTP and command
interface.

You can replicate your data by using `copy` output plugin.

## Install

    % gem install fluent-plugin-groonga

## Usage

There are two usages:

  * Store logs collected by Fluentd to Groonga.

  * Implement replication system for Groonga.

They are described in other sections.

### Store logs into Groonga

You need to use `groonga` output plugin to store logs into Groonga.

The output plugin has auto schema define feature. So you don't need to
define schema in Groonga before running Fluentd. You just run Groonga.

There is one required parameter:

  * `store_table`: It specifies table name for storing logs.

Here is a minimum configuration:

    <match log.**>
      @type groonga
      store_table logs
    </match>

The configuration stores logs into `logs` table in Groonga that runs
on `localhost`.

There are optional parameters:

  * `protocol`: It specifies protocol to communicate Groonga server.

    * Available values: `http`, `gqtp`, `command`

    * Default: `http`

  * `host`: It specifies host name or IP address of Groonga server.

    * Default: `127.0.0.1`

  * `port`: It specifies port number of Groonga server.

    * Default for `http` protocol: `10041`

    * Default for `gqtp` protocol: `10043`

Here is a configuration that specifies optional parameters explicitly:

    <match log.**>
      @type groonga
      store_table logs

      protocol http
      host 127.0.0.1
      port 10041
    </match>

`groonga` output plugin supports buffer. So you can use buffer related
parameters. See
[Buffer Plugin Overview | Fluentd](http://docs.fluentd.org/articles/buffer-plugin-overview)
for details.

Note that there is special tag name. You can't use
`groonga.command.XXX` tag name for this usage. It means that you can't
use the following configuration:

    <match groonga.command.*>
      @type groonga
      # ...
    </match>

`groonga.command.XXX` tag name is reserved for implementing
replication system for Groonga.

### Implement replication system for Groonga

See the following documents how to implement replication system for
Groonga:

  * [Configuration](doc/text/configuration.md)
    ([on the Web](http://groonga.org/fluent-plugin-groonga/en/file.configuration.html))

  * [Constitution](doc/text/constitution.md)
    ([on the Web](http://groonga.org/fluent-plugin-groonga/en/file.constitution.html))

## Authors

  * Kouhei Sutou `<kou@clear-code.com>`

## License

LGPL 2.1. See doc/text/lgpl-2.1.txt for details.

(Kouhei Sutou has a right to change the license including
contributed patches.)

## Mailing list

  * English: [groonga-talk](https://lists.sourceforge.net/lists/listinfo/groonga-talk)

  * Japanese: [groonga-dev](http://lists.sourceforge.jp/mailman/listinfo/groonga-dev)

## Source

The repository for fluent-plugin-groonga is on
[GitHub](https://github.com/groonga/fluent-plugin-groonga/).

## Thanks

  * ...
