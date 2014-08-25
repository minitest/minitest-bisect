require "minitest/find_minimal_combination"
require "minitest/server"
require "shellwords"

class Minitest::Bisect
  VERSION = "1.0.0"
  SHH = " &> /dev/null"

  attr_accessor :tainted, :failures, :culprits, :mode, :seen_bad
  alias :tainted? :tainted

  def self.run files
    new.run files
  end

  def initialize
    self.mode = :files
    self.culprits = []
    self.tainted = false
    self.failures = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }
  end

  def reset
    self.tainted = false
    self.failures.clear
    # not clearing culprits on purpose
  end

  def run files
    Minitest::Server.run self

    bisect_methods bisect_files files
  ensure
    Minitest::Server.stop
  end

  def bisect_files files
    files, flags = files.partition { |arg| File.file? arg }
    rb_flags, mt_flags = flags.partition { |arg| arg =~ /^-I/ }
    mt_flags += ["-s", $$]

    puts "reproducing..."
    system "#{build_files_cmd files, rb_flags, mt_flags} #{SHH}"
    abort "Reproduction run passed? Aborting." unless tainted?
    puts "reproduced"

    found, count = files.find_minimal_combination_and_count do |test|
      puts "# of culprits: #{test.size}"

      system "#{build_files_cmd test, rb_flags, mt_flags} #{SHH}"

      self.tainted?
    end

    puts
    puts "Final found in #{count} steps:"
    puts
    cmd = build_files_cmd found, rb_flags, mt_flags
    puts cmd
    cmd
  end

  def bisect_methods cmd
    self.mode = :methods
    self.seen_bad = false

    puts "reproducing..."
    system "#{build_methods_cmd cmd} #{SHH}"
    abort "Reproduction run passed? Aborting." unless tainted?
    puts "reproduced"

    # from: {"example/helper.rb"=>{"TestBad4"=>["test_bad4_4"]}}
    #   to: "TestBad4#test_bad4_4"
    bad = failures.values.first.to_a.join "#"

    found, count = culprits.find_minimal_combination_and_count do |test|
      puts "# of culprits: #{test.size}"

      system "#{build_methods_cmd cmd, test, bad} #{SHH}"

      self.tainted?
    end

    puts
    puts "Final found in #{count} steps:"
    puts
    cmd = build_methods_cmd cmd, found, bad
    puts cmd
    puts
    system cmd
  end

  def build_files_cmd culprits, rb, mt
    reset

    tests = culprits.flatten.compact.map {|f| %(require "./#{f}")}.join " ; "

    %(ruby #{rb.shelljoin} -e '#{tests}' -- #{mt.shelljoin})
  end

  def build_methods_cmd cmd, culprits = [], bad = nil
    reset

    re = Regexp.union(culprits + [bad]).to_s.gsub(/-mix/, "") if bad
    cmd += " -n '/^#{re}$/'" if bad # += because we need a copy

    cmd
  end

  def result file, klass, method, fails, assertions, time
    case mode
    when :methods then
      if fails.empty? then
        culprits << "#{klass}##{method}" unless seen_bad # UGH
      else
        self.seen_bad = true
      end
    end

    unless fails.empty?
      self.tainted = true
      self.failures[file][klass] << method
    end
  end
end
