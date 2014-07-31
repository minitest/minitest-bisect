# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe.plugin :isolate
Hoe.plugin :seattlerb

Hoe.spec "minitest-bisect" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"
  license "MIT"
end

require "rake/testtask"

Rake::TestTask.new(:badtest) do |t|
  t.test_files = Dir["badtest/test*.rb"]
end

def banner text
  puts
  puts "#" * 70
  puts "# #{text} ::"
  puts "#" * 70
  puts
end

def run cmd
  sh cmd do end
end

def req glob
  Dir["badtest/#{glob}.rb"].map { |s| "require #{s.inspect}" }.join ";"
end

task :repro do
  ruby = "#{Gem.ruby} -I.:lib"

  banner "Original run that causes the test order dependency bug"
  run "#{ruby} -e '#{req "test*"}' -- --seed 3911"

  banner "Reduce the problem down te the minimal files"
  run "#{ruby} bin/minitest_bisect_files --seed 3911 badtest/test*.rb"

  banner "Reduce the problem down te the minimal tests"
  run "#{ruby} bin/minitest_bisect #{ruby} -e '#{req "test_bad[14]"}' -- --seed 3911"
end

# vim: syntax=ruby
