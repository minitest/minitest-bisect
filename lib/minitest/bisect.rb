require "minitest/find_minimal_combination"
require "minitest/server"
require "shellwords"
require "rbconfig"
require "path_expander"

class Minitest::Bisect
  VERSION = "1.3.1"

  class PathExpander < ::PathExpander
    TEST_GLOB = "**/{test_*,*_test,spec_*,*_spec}.rb" # :nodoc:

    attr_accessor :rb_flags

    def initialize args = ARGV # :nodoc:
      super args, TEST_GLOB
      self.rb_flags = []
    end

    ##
    # Overrides PathExpander#process_flags to filter out ruby flags
    # from minitest flags. Only supports -I<paths>, -d, and -w for
    # ruby.

    def process_flags flags
      flags.reject { |flag| # all hits are truthy, so this works out well
        case flag
        when /^-I(.*)/ then
          rb_flags << flag
        when /^-d/ then
          rb_flags << flag
        when /^-w/ then
          rb_flags << flag
        else
          false
        end
      }
    end
  end

  mtbv = ENV["MTB_VERBOSE"].to_i
  SHH = case
        when mtbv == 1 then " > /dev/null"
        when mtbv >= 2 then nil
        else " > /dev/null 2>&1"
        end

  # Borrowed from rake
  RUBY = ENV['RUBY'] ||
    File.join(RbConfig::CONFIG['bindir'],
              RbConfig::CONFIG['ruby_install_name'] +
                RbConfig::CONFIG['EXEEXT']).sub(/.*\s.*/m, '"\&"')

  attr_accessor :tainted, :failures, :culprits, :mode, :seen_bad
  alias :tainted? :tainted

  def self.run files
    new.run files
  rescue => e
    warn e.message
    exit 1
  end

  def initialize
    self.culprits = []
    self.failures = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
  end

  def reset
    self.seen_bad = false
    self.tainted  = false
    failures.clear
    # not clearing culprits on purpose
  end

  def run args
    Minitest::Server.run self

    cmd = nil

    if :until_I_have_negative_filtering_in_minitest != 0 then
      mt_flags = args.dup
      expander = Minitest::Bisect::PathExpander.new mt_flags

      files = expander.process
      rb_flags = expander.rb_flags
      mt_flags += ["--server", $$]

      cmd = bisect_methods build_files_cmd(files, rb_flags, mt_flags)
    else
      cmd = bisect_methods bisect_files args
    end

    puts "Final reproduction:"
    puts

    system cmd.sub(/--server \d+/, "")
  ensure
    Minitest::Server.stop
  end

  def bisect_files files
    self.mode = :files

    files, flags = files.partition { |arg| File.file? arg }
    rb_flags, mt_flags = flags.partition { |arg| arg =~ /^-I/ }
    mt_flags += ["--server", $$]

    puts "reproducing..."
    system "#{build_files_cmd files, rb_flags, mt_flags} #{SHH}"
    abort "Reproduction run passed? Aborting. Try running with MTB_VERBOSE=2 to verify." unless tainted?
    puts "reproduced"

    found, count = files.find_minimal_combination_and_count do |test|
      puts "# of culprit files: #{test.size}"

      system "#{build_files_cmd test, rb_flags, mt_flags} #{SHH}"

      self.tainted?
    end

    puts
    puts "Minimal files found in #{count} steps:"
    puts
    cmd = build_files_cmd found, rb_flags, mt_flags
    puts cmd
    cmd
  end

  def bisect_methods cmd
    self.mode = :methods

    puts "reproducing..."
    t0 = Time.now
    system "#{build_methods_cmd cmd} #{SHH}"
    abort "Reproduction run passed? Aborting. Try running with MTB_VERBOSE=2 to verify." unless tainted?
    puts "reproduced in %.2f sec" % (Time.now - t0)

    # from: {"file.rb"=>{"Class"=>["test_method1", "test_method2"]}}
    #   to: ["Class#test_method1", "Class#test_method2"]
    bad = failures.values.map { |h|
      h.map { |k,vs| vs.map { |v| "#{k}##{v}" } }
    }.flatten

    raise "Nothing to verify against because every test failed. Aborting." if
      culprits.empty? && seen_bad

    # culprits populated by initial reproduction via minitest/server
    found, count = culprits.find_minimal_combination_and_count do |test|
      print "# of culprit methods: #{test.size}"

      t0 = Time.now
      system "#{build_methods_cmd cmd, test, bad} #{SHH}"
      puts " in %.2f sec" % (Time.now - t0)

      self.tainted?
    end

    puts
    puts "Minimal methods found in #{count} steps:"
    puts
    cmd = build_methods_cmd cmd, found, bad
    puts cmd
    puts
    cmd
  end

  def build_files_cmd culprits, rb, mt
    reset

    tests = culprits.flatten.compact.map { |f| %(require "./#{f}") }.join " ; "

    %(#{RUBY} #{rb.shelljoin} -e '#{tests}' -- #{mt.map(&:to_s).shelljoin})
  end

  def build_methods_cmd cmd, culprits = [], bad = nil
    reset

    if bad then
      re = []

      # bad by class, you perv
      bbc = (culprits + bad).map { |s| s.split(/#/, 2) }.group_by(&:first)

      bbc.each do |klass, methods|
        methods = methods.map(&:last).flatten.uniq.map { |method|
          method.gsub(/([`'"!?&\[\]\(\)\|\+])/, '\\\\\1')
        }

        re << /#{klass}#(?:#{methods.join "|"})/.to_s[7..-2] # (?-mix:...)
      end

      re = re.join("|").to_s.gsub(/-mix/, "")

      cmd += " -n \"/^(?:#{re})$/\"" if bad
    end

    if ENV["MTB_VERBOSE"].to_i >= 1 then
      puts
      puts cmd
      puts
    end

    cmd
  end

  ############################################################
  # Server Methods:

  def minitest_start
    self.failures.clear
  end

  def minitest_result file, klass, method, fails, assertions, time
    fails.reject! { |fail| Minitest::Skip === fail }

    if mode == :methods then
      if fails.empty? then
        culprits << "#{klass}##{method}" unless seen_bad # UGH
      else
        self.seen_bad = true
      end
    end

    return if fails.empty?

    self.tainted = true
    self.failures[file][klass] << method
  end
end
