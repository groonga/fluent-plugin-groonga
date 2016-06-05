# -*- mode: ruby; coding: utf-8 -*-
#
# Copyright (C) 2012-2016  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Gem::Specification.new do |spec|
  spec.name = "fluent-plugin-groonga"
  spec.version = "1.1.3"
  spec.authors = ["Kouhei Sutou"]
  spec.email = ["kou@clear-code.com"]
  spec.summary = "Fluentd plugin to store data into Groonga and implement Groonga replication system."
  spec.description =
    "There are two usages. 1) Store data into Groonga. 2) Implement Groonga replication system. See documentation for details."
  spec.homepage = "https://github.com/groonga/fluent-plugin-groonga"
  spec.license = "LGPL-2.1"

  spec.files = ["README.md", "Gemfile", "#{spec.name}.gemspec"]
  spec.files += [".yardopts"]
  spec.files += Dir.glob("lib/**/*.rb")
  spec.files += Dir.glob("sample/**/*")
  spec.files += Dir.glob("doc/text/**/*")
  spec.test_files += Dir.glob("test/**/*")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("fluentd")
  spec.add_runtime_dependency("groonga-client", ">= 0.1.0")
  spec.add_runtime_dependency("groonga-command-parser")

  spec.add_development_dependency("rake")
  spec.add_development_dependency("bundler")
  spec.add_development_dependency("packnga", ">= 1.0.1")
  spec.add_development_dependency("test-unit")
  spec.add_development_dependency("test-unit-notify")
  spec.add_development_dependency("redcarpet")
end
