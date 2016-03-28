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
      @type groonga
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
      @type groonga
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
      ## 17: about 1.5day =
      ##       ((2 ** 0) + (2 ** 1) + ... + (2 ** 17)) / 60.0 / 60.0 / 24.0
      ##     (default)
      ## 18: about 3.0day = ((2 ** 0) + ... + (2 ** 18)) / ...
      ## 19: about 6.0day = ((2 ** 0) + ... + (2 ** 19)) / ...
      # retry_limit 19
      ## Use large value if you load many records.
      ## A value in load command is a chunk.
      # buffer_queue_limit 10000
    </match>

#### How to recover from fluentd down

If fluentd is down, you just restart fluentd. Note that you may resend
the last command if fluentd is down while you are sending update
commands.

You cannot update data until fluentd is up.

#### How to recover from master groonga server down

Here are recover steps when master groonga server is down:

  1. Stop fluentd.
  2. Run `grndump /PATH/TO/SLAVE/GROONGA/SERVER/DB >
     SLAVE_GROONGA_DUMP.grn` on slave groonga server host.
  3. Run `groonga -n /PATH/TO/MASTER/GROONGA/SERVER/DB <
     SLAVE_GROONGA_DUMP.grn` on master groonga server.
  4. Run master groonga server.
  5. Start fluentd.

You cannot update data until you finish to recover.

#### How to recover from slave groonga server down

Here are recover steps when slave groonga server is down:

  1. Run `grndump /PATH/TO/MASTER/GROONGA/SERVER/DB >
     MASTER_GROONGA_DUMP.grn` on master groonga server host.
  2. Run `groonga -n /PATH/TO/SLAVE/GROONGA/SERVER/DB <
     MASTER_GROONGA_DUMP.grn` on slave groonga server.
  3. Run slave groonga server.

You can update data while you recover. If your system can't process
all search requests by only master groonga server, your system will be
down.

You need to recover slave groonga server before fluentd's buffer queue
is full (see `buffer_queue_limit`) or fluentd gives up retrying (see
`retry_limit`). Here are recover steps when you cannot recover slave
groonga server before those situations:

  1. Stop fluentd.
  2. Run `grndump /PATH/TO/MASTER/GROONGA/SERVER/DB >
     MASTER_GROONGA_DUMP.grn` on master groonga server host.
  3. Run `groonga -n /PATH/TO/SLAVE/GROONGA/SERVER/DB <
     MASTER_GROONGA_DUMP.grn` on slave groonga server host.
  4. Run slave groonga server.
  5. Start fluentd.

You cannot update data until you finish to recover.

### Medium system

In medium system, you have three or more slave groonga servers. Fluentd
updates two or more slave groonga servers with the `copy` output
plugin and the `groonga` output plugin.

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

Here is an example configuration file:

    # For master groonga server
    <source>
      @type groonga
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

    # For slave groonga servers
    <match groonga.command.*>
      @type copy

      # The first slave groonga server
      <store>
        @type groonga
        protocol gqtp            # Or use the below line
        # protocol http          # You can use different protocol for
                                 # master groonga server and slave groonga server
        host 192.168.29.2        # IP address of slave groonga server
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
        ## 17: about 1.5day =
        ##       ((2 ** 0) + (2 ** 1) + ... + (2 ** 17)) / 60.0 / 60.0 / 24.0
        ##     (default)
        ## 18: about 3.0day = ((2 ** 0) + ... + (2 ** 18)) / ...
        ## 19: about 6.0day = ((2 ** 0) + ... + (2 ** 19)) / ...
        # retry_limit 19
        ## Use large value if you load many records.
        ## A value in load command is a chunk.
        # buffer_queue_limit 10000
      </store>

      # The second slave groonga server
      <store>
        @type groonga
        protocol gqtp            # Or use the below line
        # protocol http          # You can use different protocol for
                                 # master groonga server and slave groonga server
        host 192.168.29.3        # IP address of slave groonga server
        port 10041               # Port number of slave groonga server

        # Buffer
        # ...
      </store>

      # More slave groonga servers
      # <store>
      #   @type groonga
      #   ...
      # </store>
    </match>

TODO: ...

### Large system

In large system, you have two or more slave groonga server clusters.
Fluentd that connects with master groonga server updates two or more
fluentds that are in slave groonga server clusters with the `copy`
output plugin and the `forward` output plugin. A slave cluster has a
fluentd. Fluentd in slave groonga server clusters updates slave
groonga server in the same slave groonga server cluster by the `copy`
output plugin and `groonga` output plugin.

Here is a diagram of this constitution.

                update                 update
                 and                    and
                search    +---------+  search  +---------+
    +--------+ <--------> | fluentd | <------> | master  |
    |        |            +---------+          | groonga |
    | client |                |                +---------+
    |        |                +------------------------------+
    +--------+          +----------------------------------+ |
    |        |          |        slave cluster             | |
    | client |  search  | +---------+  update  +---------+ | |
    |        | <------> | |  slave  | <------- | fluentd | <-+ update
    +--------|          | | groonga |          +---------+ | |
    |        |          | +---------+   +-----------+      | |
    | client |  search  | +---------+   |                  | |
    |        | <------> | |  slave  | <-+ update           | |
    +--------|          | | groonga |   |                  | |
    |        |          | +---------+   |                  | |
    |  ...   |   ...    |     ...      ...                 | |
                        +----------------------------------+ |
    +--------+          +----------------------------------+ |
    |        |          |        slave cluster             | |
    | client |  search  | +---------+  update  +---------+ | |
    |        | <------> | |  slave  | <------- | fluentd | <-+ update
    +--------|          | | groonga |          +---------+ | |
    |        |          | +---------+   +-----------+      | |
    | client |  search  | +---------+   |                  | |
    |        | <------> | |  slave  | <-+ update           | |
    +--------|          | | groonga |   |                  | |
    |        |          | +---------+   |                  | |
    |  ...   |   ...    |     ...      ...                 | |
                        +----------------------------------+ |
                                      ...                   ...

TODO: ...
