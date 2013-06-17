# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "annex/version"

Gem::Specification.new do |s|
  s.name        = "annex"
  s.version     = Annex::VERSION
  s.authors     = ["Jeff Rafter"]
  s.email       = ["jeffrafter@gmail.com"]
  s.homepage    = "http://github.com/jeffrafter/annex"
  s.summary     = %q{Quickly provision servers using chef-solo and no central server.}
  s.description = %q{Annex leverages chef-solo to allow you to provision and update mutliple servers by looking up network topology on the fly utilizing a distributed repository to manage recipes"}

  s.rubyforge_project = "annex"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency("fog", [">= 0"])
  s.add_runtime_dependency("json", [">= 0"])
end
