# -*- mode: ruby; coding: utf-8 -*-
#
# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
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
  spec.version = "1.0.0"
  spec.authors = ["Kouhei Sutou"]
  spec.email = ["kou@clear-code.com"]
  spec.summary = "Fluentd plugin collection for groonga users"
  spec.description =
    "Groonga users can replicate their data by fluent-plugin-groonga"
  spec.homepage = "https://github.com/groonga/fluent-plugin-groonga"

  spec.files = ["README.md", "Gemfile", "#{spec.name}.gemspec"]
  spec.files += Dir.glob("lib/**/*.rb")
  spec.files += Dir.glob("doc/text/**/*")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("fluentd")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("bundler")
  spec.add_development_dependency("test-unit")
  spec.add_development_dependency("test-unit-notify")
end
