# README

## Name

fluent-plugin-groonga

## Description

Fluent-plugin-groonga is fluentd plugin collection for
[groonga](http://groonga.org/) users. Groonga users can replicate
their data by fluent-plugin-groonga.

Fluent-plugin-groonga includes an input plugin and an output
plugin. Both of them are named `groonga`.

The input plugin provides groonga compatible interface. It means that
HTTP and GQTP interface. You can use the input plugin as groonga
server. The input plugin receives groonga commands and sends them to
the output plugin through some fluentds.

The output plugin sends received groonga commands to groonga. The
output plugin supports all interfaces, HTTP, GQTP and command
interface.

You can replicate your data by using `copy` output plugin.

## Install

    % gem install fluent-plugin-groonga

## Usage

### The `groonga` input plugin

Here are available parameters:

* `protocol`: It specifies protocol for receiving groonga commands.
  * available values: `http` and `gqtp`
  * default: `http`
* `bind`: It specifies bind address.
   * default: `0.0.0.0`
* `port`: It specifies port number.
   * default: `10041`
* `real_host`: It specifies real groonga server's address. It is required.
   * default: no default.
* `real_port`: It specifies real groonga server's port number.
   * default: `10041`
* `emit_commands`: TODO

Here is an example:

    <source>
      type groonga
      protocol http
      bind 127.0.0.1
      port 10041
      real_host 192.168.0.1
      real_port 10041
    </source>

### The `groonga` output plugin

* `protocol`: It specifies protocol for sending groonga commands to groonga.
  * available values: `http`, `gqtp` and `command`
  * default: `http`
* For `http` and `gqtp` use:
  * `host`: It specifies groonga server's address.
     * default: `localhost`
  * `port`: It specifies groonga server's port number.
     * default: `10041`
* For `command` use:
  * `groonga`: It specifies path of groonga command.
     * default: `groonga`
  * `database`: It specifies path of groonga database. It is required.
     * default: no default.
  * `arguments`: It specifies additional arguments for groonga command.
     * default: no additional arguments.

    <match groonga.command.*>
      type groonga
      protocol command
      database /tmp/groonga/db
    </match>

## Authors

* Kouhei Sutou `<kou@clear-code.com>`

## License

LGPL 2.1. See doc/text/lgpl-2.1.txt for details.

(Kouhei Sutou has a right to change the license including
contributed patches.)

## Mailing list

* English: [groonga-talk](https://lists.sourceforge.net/lists/listinfo/groonga-talk)
* Japanese: [groonga-dev](http://lists.sourceforge.jp/mailman/listinfo/groonga-dev)

## Thanks

* ...
