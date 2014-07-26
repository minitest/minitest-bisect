# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe.plugin :isolate
Hoe.plugin :seattlerb

# Hoe.plugin :compiler
# Hoe.plugin :doofus
# Hoe.plugin :email
# Hoe.plugin :gem_prelude_sucks
# Hoe.plugin :git
# Hoe.plugin :history
# Hoe.plugin :inline
# Hoe.plugin :isolate
# Hoe.plugin :minitest
# Hoe.plugin :perforce
# Hoe.plugin :racc
# Hoe.plugin :rcov
# Hoe.plugin :rdoc
# Hoe.plugin :seattlerb

Hoe.spec "minitest-bisect" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"
  license "MIT"
end

require "rake/testtask"

Rake::TestTask.new(:badtest) do |t|
  t.test_files = Dir["badtest/test*.rb"]
end

task :repro do
  ruby "-Ilib ./bin/minitest_bisect_files badtest/test_bad1.rb badtest/test_bad2.rb badtest/test_bad3.rb badtest/test_bad4.rb --seed=25111"
end

# vim: syntax=ruby
