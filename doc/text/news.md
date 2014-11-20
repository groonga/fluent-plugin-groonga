# @title News

# News

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
