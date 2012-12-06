# @title Configuration

# Configuration

Fluent-plugin-groonga includes two fluentd plugins. They are the
`groonga` input plugin and the `groonga` output plugin. This documents
describes configuration parameters of them.

## The `groonga` input plugin

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

## The `groonga` output plugin

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

Here is an example:

    <match groonga.command.*>
      type groonga
      protocol command
      database /tmp/groonga/db
    </match>
