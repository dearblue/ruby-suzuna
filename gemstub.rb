
require_relative "lib/suzuna"

GEMSTUB = Gem::Specification.new do |s|
  s.name = "suzuna"
  s.version = Suzuna::VERSION
  s.platform = "freebsd"
  s.summary = "Soft volume infrastructure for ruby"
  s.description = <<EOS
``suzuna'' is software volume infrastructure for ruby.

Support platform is FreeBSD GEOM only.
EOS
  s.license = "2-clause BSD License"
  s.author = "dearblue"
  s.email = "dearblue@users.sourceforge.jp"
  s.homepage = "http://sourceforge.jp/projects/rutsubo/"

  s.required_ruby_version = ">= 2.0"
  s.add_development_dependency "rspec", "~> 2.14"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_runtime_dependency "gogyou", "~> 0.2"
end
