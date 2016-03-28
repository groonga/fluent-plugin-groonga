# @title Constitution

# Constitution

You can chose some system constitutions to implemented replication
ready Groonga system. This document describes some patterns.

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

In small system, you just has two servers. One is the master Groonga
server and the other is the slave Groonga server. You send all update
commands (e.g. `table_create`, `column_create`, `load` and so on.) to
fluentd. In fluentd, the `groonga` input plugin receives commands from
client, passes through them to master Groonga server and passes
through responses from master Groonga server to client. The `groonga`
input plugin converts update commands to fluent messages when the
`groonga` input plugin passes through comamands and responses. The
fluent messages are sent to slave Groonga server by the `groonga`
output plugin.

Here is a diagram of this constitution.

                update               update
                 and                  and
                search  +---------+  search  +---------+
    +--------+ <------> | fluentd | <------> | master  |
    |        |          +---------+          | Groonga |
    | client |        update |               +---------+
    |        |              \_/
    |        |  search  +---------+
    +--------+ <------> |  slave  |
                        | Groonga |
                        +---------+

Fluentd should be placed at client or master Groonga server. If you
have only one client that updates data, client side is reasonable. If
you have multiple clients that update data, master Groonga server side
is reasonable.

You can use replication for high performance by providing search
service with multi servers. You can't use replication for high
availability. If master Groonga server or fluentd is down, this system
can't update data. (Searching is still available because slave Groonga
server is alive.)

Here is an example configuration file:

    # For master Groonga server
    <source>
      @type groonga
      protocol gqtp          # Or use the below line
      # protocol http
      bind 127.0.0.1         # For client side Fluentd
      # bind 192.168.0.1     # For master Groonga server side Fluentd
      port 10041
      real_host 192.168.29.1 # IP address of master Groonga server
      real_port 10041        # Port number of master Groonga server
      # real_port 20041      # Use different port number
                             # for master Groonga server side Fluentd
    </source>

    # For slave Groonga server
    <match groonga.command.*>
      @type groonga
      protocol gqtp            # Or use the below line
      # protocol http          # You can use different protocol for
                               # master Groonga server and slave Groonga server
      host 192.168.29.29       # IP address of slave Groonga server
      port 10041               # Port number of slave Groonga server

      # Buffer
      flush_interval 1s        # Use small value for less delay replication

      ## Use the following configurations to support resending data to
      ## recovered slave Groonga server. If you don't care about slave
      ## Groonga server is down case, you don't need the following
      ## configuration.

      ## For supporting resending data after fluentd is restarted
      # buffer_type file
      # buffer_path /var/log/fluent/groonga.*.buffer
      ## Use large value if a record has many data in load command.
      ## A value in load command is a chunk.
      # buffer_chunk_limit 256m
      ## Use large value if you want to support resending data after
      ## slave Groonga server is down long time.
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

#### How to recover from master Groonga server down

Here are recover steps when master Groonga server is down:

  1. Stop fluentd.
  2. Run `grndump /PATH/TO/SLAVE/GROONGA/SERVER/DB >
     SLAVE_GROONGA_DUMP.grn` on slave Groonga server host.
  3. Run `groonga -n /PATH/TO/MASTER/GROONGA/SERVER/DB <
     SLAVE_GROONGA_DUMP.grn` on master Groonga server.
  4. Run master Groonga server.
  5. Start fluentd.

You cannot update data until you finish to recover.

#### How to recover from slave Groonga server down

Here are recover steps when slave Groonga server is down:

  1. Run `grndump /PATH/TO/MASTER/GROONGA/SERVER/DB >
     MASTER_GROONGA_DUMP.grn` on master Groonga server host.
  2. Run `groonga -n /PATH/TO/SLAVE/GROONGA/SERVER/DB <
     MASTER_GROONGA_DUMP.grn` on slave Groonga server.
  3. Run slave Groonga server.

You can update data while you recover. If your system can't process
all search requests by only master Groonga server, your system will be
down.

You need to recover slave Groonga server before fluentd's buffer queue
is full (see `buffer_queue_limit`) or fluentd gives up retrying (see
`retry_limit`). Here are recover steps when you cannot recover slave
Groonga server before those situations:

  1. Stop fluentd.
  2. Run `grndump /PATH/TO/MASTER/GROONGA/SERVER/DB >
     MASTER_GROONGA_DUMP.grn` on master Groonga server host.
  3. Run `groonga -n /PATH/TO/SLAVE/GROONGA/SERVER/DB <
     MASTER_GROONGA_DUMP.grn` on slave Groonga server host.
  4. Run slave Groonga server.
  5. Start fluentd.

You cannot update data until you finish to recover.

### Medium system

In medium system, you have three or more slave Groonga servers. Fluentd
updates two or more slave Groonga servers with the `copy` output
plugin and the `groonga` output plugin.

Here is a diagram of this constitution.

                update               update
                 and                  and
                search  +---------+  search  +---------+
    +--------+ <------> | fluentd | <------> | master  |
    |        |          +---------+          | Groonga |
    | client |               +--------+      +---------+
    |        |                        |
    +--------+  search  +---------+   |
    |        | <------> |  slave  | <-+ update
    | client |          | Groonga |   |
    |        |          +---------+   |
    +--------+  search  +---------+   |
    |        | <------> |  slave  | <-+ update
    | client |          | Groonga |   |
    |        |          +---------+   |
    +- ...  -+   ...        ...      ...

Here is an example configuration file:

    # For master Groonga server
    <source>
      @type groonga
      protocol gqtp          # Or use the below line
      # protocol http
      bind 127.0.0.1         # For client side Fluentd
      # bind 192.168.0.1     # For master Groonga server side Fluentd
      port 10041
      real_host 192.168.29.1 # IP address of master Groonga server
      real_port 10041        # Port number of master Groonga server
      # real_port 20041      # Use different port number
                             # for master Groonga server side fluentd
    </source>

    # For slave Groonga servers
    <match groonga.command.*>
      @type copy

      # The first slave Groonga server
      <store>
        @type groonga
        protocol gqtp            # Or use the below line
        # protocol http          # You can use different protocol for
                                 # master Groonga server and slave Groonga server
        host 192.168.29.2        # IP address of slave Groonga server
        port 10041               # Port number of slave Groonga server

        # Buffer
        flush_interval 1s        # Use small value for less delay replication

        ## Use the following configurations to support resending data to
        ## recovered slave Groonga server. If you don't care about slave
        ## Groonga server is down case, you don't need the following
        ## configuration.

        ## For supporting resending data after fluentd is restarted
        # buffer_type file
        # buffer_path /var/log/fluent/groonga1.*.buffer
        ## Use large value if a record has many data in load command.
        ## A value in load command is a chunk.
        # buffer_chunk_limit 256m
        ## Use large value if you want to support resending data after
        ## slave Groonga server is down long time.
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

      # The second slave Groonga server
      <store>
        @type groonga
        protocol gqtp            # Or use the below line
        # protocol http          # You can use different protocol for
                                 # master Groonga server and slave Groonga server
        host 192.168.29.3        # IP address of slave Groonga server
        port 10041               # Port number of slave Groonga server

        # Buffer
        # ...
      </store>

      # More slave Groonga servers
      # <store>
      #   @type groonga
      #   ...
      # </store>
    </match>

TODO: ...

### Large system

In large system, you have two or more slave Groonga server clusters.
Fluentd that connects with master Groonga server updates two or more
fluentds that are in slave Groonga server clusters with the `copy`
output plugin and the `forward` output plugin. A slave cluster has a
fluentd. Fluentd in slave Groonga server clusters updates slave
Groonga server in the same slave Groonga server cluster by the `copy`
output plugin and `groonga` output plugin.

Here is a diagram of this constitution.

                update                 update
                 and                    and
                search    +---------+  search  +---------+
    +--------+ <--------> | fluentd | <------> | master  |
    |        |            +---------+          | Groonga |
    | client |                |                +---------+
    |        |                +------------------------------+
    +--------+          +----------------------------------+ |
    |        |          |        slave cluster             | |
    | client |  search  | +---------+  update  +---------+ | |
    |        | <------> | |  slave  | <------- | fluentd | <-+ update
    +--------|          | | Groonga |          +---------+ | |
    |        |          | +---------+   +-----------+      | |
    | client |  search  | +---------+   |                  | |
    |        | <------> | |  slave  | <-+ update           | |
    +--------|          | | Groonga |   |                  | |
    |        |          | +---------+   |                  | |
    |  ...   |   ...    |     ...      ...                 | |
                        +----------------------------------+ |
    +--------+          +----------------------------------+ |
    |        |          |        slave cluster             | |
    | client |  search  | +---------+  update  +---------+ | |
    |        | <------> | |  slave  | <------- | fluentd | <-+ update
    +--------|          | | Groonga |          +---------+ | |
    |        |          | +---------+   +-----------+      | |
    | client |  search  | +---------+   |                  | |
    |        | <------> | |  slave  | <-+ update           | |
    +--------|          | | Groonga |   |                  | |
    |        |          | +---------+   |                  | |
    |  ...   |   ...    |     ...      ...                 | |
                        +----------------------------------+ |
                                      ...                   ...

TODO: ...
