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

    * recommended value: greater than `1`.

    * default: `1`

Note that there is one exception about the number of recommended
workers. Users should use `1` worker when commands contain DDL such as
`table_create` and `column_create`. Because execution order of these
commands may be swapped. In such a case, replication will fail.

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

  * `command_name_position`: It specifies where Groonga command's
    name.

    If `tag` is specified, the plugin puts Groonga command's name to
    tag as `groonga.command.#{COMMAND_NAME}` format and record
    is the arguments of the command.

    If `record` is specified, the plugin puts both Groonga command's
    name and arguments to record as `{"name": "#{COMMAND_NAME}",
    "arguments": {...}}` format. Tag is always `groonga.command`.

    `record` is suitable when you want to implement replication. If
    you `tag` for replication, Groonga command's order may be changed.

    * Available values: `tag`, `record`

    * default: `tag`

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
      command_name_position record
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
