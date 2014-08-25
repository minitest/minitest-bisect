require "minitest/find_minimal_combination"
require "minitest/server"

class Minitest::Bisect
  VERSION = "1.0.0"

  attr_accessor :tainted, :failures, :culprits
  alias :tainted? :tainted

  def self.run cmd
    new.run cmd
  end

  def initialize
    self.culprits = []
    self.tainted = false
    self.failures = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }
  end

  def run cmd
    Minitest::Server.run self

    puts "reproducing..."
    repro cmd
    abort "Reproduction run passed? Aborting." unless tainted?
    puts "reproduced"

    # from: {"example/helper.rb"=>{"TestBad4"=>["test_bad4_4"]}}
    #   to: "TestBad4#test_bad4_4"
    bad = failures.values.first.to_a.join "#"

    count = 0

    found = culprits.find_minimal_combination do |test|
      count += 1

      puts "# of culprits: #{test.size}"

      repro cmd, test, bad

      self.tainted?
    end

    puts
    puts "Final found in #{count} steps:"
    puts
    cmd = build_cmd cmd, found, bad
    puts cmd
    puts
    system cmd
  ensure
    Minitest::Server.stop
  end

  def build_cmd cmd, culprits, bad
    return false if bad and culprits.empty?

    re = Regexp.union(culprits + [bad]).to_s.gsub(/-mix/, "") if bad
    cmd += ["-n", "'/^#{re}$/'"] if bad
    cmd << "-s" << $$

    # cheap but much more readable version of shellwords' shelljoin
    cmd.map { |s| s =~ / / ? "'#{s}'" : s }.join " "
  end

  def repro cmd, culprits = [], bad = nil
    self.tainted = false
    failures.clear

    cmd = build_cmd cmd, culprits, bad
    system "#{cmd} &> /dev/null"
  end

  def result file, klass, method, fails, assertions, time
    @seen_bad ||= false
    if fails.empty? then
      unless @seen_bad then
        culprits << "#{klass}##{method}" # UGH
      end
    else
      self.tainted = true
      self.failures[file][klass] << method
      @seen_bad = true
    end
  end
end
