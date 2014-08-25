require "minitest/find_minimal_combination"
require "shellwords"
require "minitest/server"

class Minitest::BisectFiles
  attr_accessor :tainted, :failures
  alias :tainted? :tainted

  def self.run files
    new.run files
  end

  def initialize
    self.tainted = false
    self.failures = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }
  end

  def run files
    Minitest::Server.run self

    files, flags = files.partition { |arg| File.file? arg }
    rb_flags, mt_flags = flags.partition { |arg| arg =~ /^-I/ }
    mt_flags += ["-s", $$]

    puts "reproducing..."
    system build_cmd(nil, files, nil, rb_flags, mt_flags)
    abort "Reproduction run passed? Aborting." unless tainted?
    puts "reproduced"

    count = 0

    found = files.find_minimal_combination do |test|
      count += 1

      puts "# of culprits: #{test.size}"

      system build_cmd(nil, test, nil, rb_flags, mt_flags)

      self.tainted?
    end

    puts
    puts "Final found in #{count} steps:"
    puts
    puts build_cmd nil, found, nil, rb_flags, mt_flags
  ensure
    Minitest::Server.stop
  end

  def build_cmd cmd, culprits, bad, rb, mt
    return false if bad and culprits.empty?

    self.tainted = false
    failures.clear

    tests = (culprits + [bad]).flatten.compact.map {|f| %(require "./#{f}")}
    tests = tests.join " ; "
    shh   = "&> /dev/null"

    %(ruby #{rb.shelljoin} -e '#{tests}' -- #{mt.shelljoin} #{shh})
  end

  def result file, klass, method, fails, assertions, time
    unless fails.empty?
      self.tainted = true
      self.failures[file][klass] << method
    end
  end
end
