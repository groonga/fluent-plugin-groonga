# @title Constitution

# Constitution

You can chose some system constitutions to implemented replication
ready groonga system. This document describes some patterns.

Here are available patterns:

* Master slave replication
* Resending data to recovered slave

Here are unavailable patterns:

* Multi master replication
* Auto slave recovery
* Dynamic slave adding
* Failover
* No SPOF (Single Point of Failure) without downing service level

## Master slave replication

Master slave replication is available. This section describes how to
configure your system constitution.

### Small system

In small system, you just has two servers. One is the master groonga
server and the other is the slave groonga server. You send all update
commands (e.g. `table_create`, `column_create`, `load` and so on.) to
fluentd. In fluentd, the `groonga` input plugin receives commands from
client, passes through them to master groonga server and passes
through responses from master groonga server to client. The `groonga`
input plugin converts update commands to fluent messages when the
`groonga` input plugin passes through comamands and responses. The
fluent messages are sent to slave groonga server by the `groonga`
output plugin.

Here is a diagram of this constitution.

                update               update
                 and                  and
                search  +---------+  search  +---------+
    +--------+ <------> | fluentd | <------> | master  |
    |        |          +---------+          | groonga |
    | client |        update |               +---------+
    |        |              \_/
    |        |  search  +---------+
    +--------+ <------> |  slave  |
                        | groonga |
                        +---------+

Fluentd should be placed at client or master groonga server. If you
have only one client that updates data, client side is reasonable. If
you have multiple clients that update data, master groonga server side
is reasonable.

You can use replication for high performance by providing search
service with multi servers. You can't use replication for high
availability. If master groonga server or fluentd is down, this system
can't update data. (Searching is still available because slabe groonga
server is alive.)

Here is an example configuration file:

    # For master groonga server
    <source>
      type groonga
      protocol gqtp          # Or use the below line
      # protocol http
      bind 127.0.0.1         # For client side fluentd
      # bind 192.168.0.1     # For master groonga server side fluentd
      port 10041
      real_host 192.168.29.1 # IP address of master groonga server
      real_port 10041        # Port number of master groonga server
      # real_port 20041      # Use different port number
                             # for master groonga server side fluentd
    </source>

    # For slave groonga server
    <match groonga.command.*>
      type groonga
      protocol gqtp            # Or use the below line
      # protocol http          # You can use different protocol for
                               # master groonga server and slave groonga server
      host 192.168.29.29       # IP address of slave groonga server
      port 10041               # Port number of slave groonga server

      # Buffer
      flush_interval 1s        # Use small value for less delay replication

      ## Use the following configurations to support resending data to
      ## recovered slave groonga server. If you don't care about slave
      ## groonga server is down case, you don't need the following
      ## configuration.

      ## For supporting resending data after fluentd is restarted
      # buffer_type file
      # buffer_path /var/log/fluent/groonga.*.buffer
      ## Use large value if a record has many data in load command.
      ## A value in load command is a chunk.
      # buffer_chunk_limit 256m
      ## Use large value if you want to support resending data after
      ## slave groonga server is down long time.
      # retry_limit 100
      ## Use large value if you load many records.
      ## A value in load command is a chunk.
      # buffer_queue_limit 10000
    </match>

#### How to recover from fluentd down

#### How to recover from master groonga server down

#### How to recover from slave groonga server down

### Medium system

In medium system, you has two or more groonga slave servers.

Here is a diagram of this constitution.

                update               update
                 and                  and
                search  +---------+  search  +---------+
    +--------+ <------> | fluentd | <------> | master  |
    |        |          +---------+          | groonga |
    | client |               +--------+      +---------+
    |        |                        |
    +--------+  search  +---------+   |
    |        | <------> |  slave  | <-+ update
    | client |          | groonga |   |
    |        |          +---------+   |
    +--------+  search  +---------+   |
    |        | <------> |  slave  | <-+ update
    | client |          | groonga |   |
    |        |          +---------+   |
    +- ...  -+   ...        ...      ...

TODO: ...

