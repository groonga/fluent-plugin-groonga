# @title News

# News

## 1.2.3: 2018-01-16

### Improvements

* in: `command_name_position`: Added a new parameter to control
  command format. The default behavior isn't changed.

### Fixes

* out: Fixed a bug that existing column may be tried to create when
  Groonga command messages and data load messages are mixed.

## 1.2.2: 2017-11-22

### Fixes

* out: Fixed a bug that command execution order may be swapped.

## 1.2.1: 2017-05-01

### Fixes

* in: Fixed to wait until write back is completed to client.
  Without this change, fluentd couldn't send back response correctly.

## 1.2.0: 2017-04-26

### Improvements

* Supported recent fluentd v0.14 API.
  Since fluentd 0.14.12, compatibility layer is unexpectedly broken,
  fluent-plugin-groonga had been also affected because
  fluent-plugin-groonga relied on it. Note that fluent-plugin-groonga
  does not work with fluentd v0.12 because it does not use
  compatibility layer anymore. We recommends to use latest release,
  but if you still stay with fluentd v0.12, you need to use
  fluent-plugin-groonga 1.1.7.

## 1.1.7: 2017-04-04

### Fixes

* in: Fixed a typo about configuration parameter.
  It causes unexpected error because of unknown option.

## 1.1.6: 2016-10-03

### Improvements

* Supported "100-continue" case.
  HTTP response shouldn't be finished when a HTTP client requests
  "100-continue". curl, PHP HTTP client and so on use "100-continue"
  when they send a large POST data. The input groonga plugin should
  support "100-conitnue".
* Ignored invalid JSON.
* Added more information to logs.

## 1.1.5: 2016-09-28

### Improvements

* Sent error response on error.

## 1.1.4: 2016-09-28

### Improvements

* Supported invalid request URL.
* Added error class to log.
* Added log on failing to connect to Groonga.

## 1.1.3: 2016-09-02

### Improvements

* Supported Fluentd 0.14.

* Stopped to emit requests when real Groonga server returns error
  responses. `load` request and `object_remove` request are
  exceptions. They are always emitted if real Groonga server returns
  error responses. Because they may be effected when Groonga server
  returns error responses.

* Updated the default emit target command list to reflect the recent
  Groonga command list.

## 1.1.2: 2016-06-05

### Improvements

* in http: Supported `Host` rewriting. It supports groonga-httpd again.
  [groonga-dev:04037][Reported by Hiroaki TACHIKAWA]

### Thanks

* Hiroaki TACHIKAWA

## 1.1.1: 2016-05-27

### Improvements

* in: Stopped using deprecated API.
  [GitHub#6][Reported by okkez]

### Thanks

* okkez

## 1.1.0: 2016-01-24

### Improvements

* out: Stopped to try to create pseudo columns such as `_key`.
* out: Supported boolean value.
* in: Supported `plugin_register` and `plugin_unregister`.

## 1.0.9: 2014-11-20

### Improvements

* out: Added log message with host, port and command name on Groonga
  command execution error.
* out: Added `WITH_POSITION` index flag automatically when it is
  needed.
* out: Supported creating index for existing column.

### Fixes

* out: Fixed a bug that needless `WITH_SECTION` flags is used.
* out: Fixed a bug that wrong index name is used.

## 1.0.8: 2014-11-05

### Fixes

* out: Fixed a bug that index flags aren't separated with `|`.

## 1.0.7: 2014-11-05

### Improvements

* out: Added `WITH_POSITION` index flags when any tokenizer is set to
  lexicon.

## 1.0.6: 2014-11-05

### Improvements

* out: Renamed `table` parameter name to `store_table`.
  `table` parameter is still usable for backward compatibility.
* out: Supported table definition by `<table>` configuration.
  See sample/store-apache.conf for details.
* out: Supported specifying column type and creating indexes for auto
  created columns by `<mapping>` configuration.
  See sample/store-apache.conf for details.

## 1.0.5: 2014-10-21

### Improvements

* Supported time value in string.

## 1.0.4: 2014-10-20

### Improvements

* Supported the latest http_parser gem.
* Removed no buffer mode. Use `flush_interval 0` for no buffer like
  behavior.
* Changed the default port number to `10043` for `gqtp` protocol usage.
  Because Groonga changed the default port number for `gqtp` protocol.
* Reduced the number of `load` calls. It improves `load` performance.
* Supported auto schema define. You don't need to define schema in Groonga
  before running Fluentd.
* Added document to use fluent-plugin-groonga to store logs into Groonga.
  It fits normal Fluentd usage.

## 1.0.3: 2013-09-29

### Improvements

* Added license information to gemspec.
  [GitHub#1][Reported by Benjamin Fleischer]
* Supported groonga-command-parser.

### Thanks

* Benjamin Fleischer

## 1.0.2: 2013-08-08

### Improvements

* Supported non-buffer mode.
* Required gqtp gem >= 1.0.3.

## 1.0.1: 2012-12-29

### Improvements

* Added more destructive emit commands ("delete", "register", "truncate").
* [out] Used close instead of sending "shutdown".
* Placed documents to http://groonga.org/fluent-plugin-groonga/en/.
* [doc] Updated documents:
  * Added the documents of configuration and constitution.
  * Added recover steps.
  * Added documentation about master slave replication in
    [small/medium/large] system.

## 1.0.0: 2012-11-29

The first release!!!
