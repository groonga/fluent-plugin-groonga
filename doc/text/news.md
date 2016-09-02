# @title News

# News

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
