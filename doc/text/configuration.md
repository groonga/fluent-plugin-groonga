# @title Configuration

# Configuration

Fluent-plugin-groonga includes two Fluentd plugins. They are the
`groonga` input plugin and the `groonga` output plugin. This documents
describes configuration parameters of them.

## The `groonga` input plugin

The behavior of `groonga` input plugin is customized in `system`
directive and `source` directive parameters.

Here is recommended parameter in `system` directive:

  * `workers`: It specifies the number of workers. The point of view
    in performance, the recommended value is greater than 1 to process
    requests in parallel.

    * recommended value: greater than 1.

    * default: `1`

Here are available parameters in `source` directive:

  * `protocol`: It specifies protocol for receiving Groonga commands.

    * available values: `http` and `gqtp`

    * default: `http`

  * `bind`: It specifies bind address.

    * default: `0.0.0.0`

  * `port`: It specifies port number.

    * default: `10041`

  * `real_host`: It specifies real Groonga server's address. It is required.

    * default: no default.

  * `real_port`: It specifies real Groonga server's port number.

    * default: `10041`

  * `emit_commands`: TODO

Here is an example:

    <system>
      workers 2
    </system>

    <source>
      @type groonga
      protocol http
      bind 127.0.0.1
      port 10041
      real_host 192.168.0.1
      real_port 10041
    </source>

## The `groonga` output plugin

  * `protocol`: It specifies protocol for sending Groonga commands to Groonga.

    * available values: `http`, `gqtp` and `command`

    * default: `http`

  * For `http` and `gqtp` use:

    * `host`: It specifies Groonga server's address.

      * default: `localhost`

    * `port`: It specifies Groonga server's port number.

      * default: `10041`

  * For `command` use:

    * `groonga`: It specifies path of `groonga` command.

      * default: `groonga`

    * `database`: It specifies path of Groonga database. It is required.

      * default: no default.

    * `arguments`: It specifies additional arguments for `groonga` command.

      * default: no additional arguments.

Here is an example:

    <match groonga.command.*>
      @type groonga
      protocol command
      database /tmp/groonga/db
    </match>
