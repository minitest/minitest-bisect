# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe.plugin :isolate
Hoe.plugin :seattlerb
Hoe.plugin :rdoc

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
  Dir["example/#{glob}.rb"].map { |s| "require #{s.inspect}" }.join ";"
end

task :repro do
  unless ENV.has_key? "SLEEP" then
    warn "NOTE: Defaulting to sleeping 0.01 seconds per test."
    warn "NOTE: Use SLEEP=0 to disable or any other value to simulate your tests."
  end

  ruby = "ruby -I.:lib"

  banner "Original run that causes the test order dependency bug"
  run "#{ruby} -e '#{req "test*"}' -- --seed 3911"

  banner "Reduce the problem down to the minimal files"
  run "#{ruby} bin/minitest_bisect_files --seed 3911 example/test*.rb"

  banner "Reduce the problem down to the minimal methods"
  run "#{ruby} bin/minitest_bisect #{ruby} -e '#{req "test_bad[14]"}' -- --seed 3911"
end

# vim: syntax=ruby
