require "minitest/find_minimal_combination"
require "minitest/server"
require "shellwords"

class Minitest::Bisect
  VERSION = "1.1.0"

  SHH = ENV["MTB_VERBOSE"].to_i >= 2 ? nil : " &> /dev/null"

  attr_accessor :tainted, :failures, :culprits, :mode, :seen_bad
  alias :tainted? :tainted

  def self.run files
    new.run files
  end

  def initialize
    self.culprits = []
    self.failures = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }
  end

  def reset
    self.seen_bad = false
    self.tainted  = false
    failures.clear
    # not clearing culprits on purpose
  end

  def run files
    Minitest::Server.run self

    cmd = nil

    if :until_I_have_negative_filtering_in_minitest then
      files, flags = files.partition { |arg| File.file? arg }
      rb_flags, mt_flags = flags.partition { |arg| arg =~ /^-I/ }
      mt_flags += ["--server", $$]

      cmd = bisect_methods build_files_cmd(files, rb_flags, mt_flags)
    else
      cmd = bisect_methods bisect_files files
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
    abort "Reproduction run passed? Aborting." unless tainted?
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
    system "#{build_methods_cmd cmd} #{SHH}"
    abort "Reproduction run passed? Aborting." unless tainted?
    puts "reproduced"

    # from: {"file.rb"=>{"Class"=>["test_method"]}} to: "Class#test_method"
    bad = failures.values.first.to_a.join "#"

    # culprits populated by initial reproduction via minitest/server
    found, count = culprits.find_minimal_combination_and_count do |test|
      puts "# of culprit methods: #{test.size}"

      system "#{build_methods_cmd cmd, test, bad} #{SHH}"

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

    tests = culprits.flatten.compact.map {|f| %(require "./#{f}")}.join " ; "

    %(ruby #{rb.shelljoin} -e '#{tests}' -- #{mt.shelljoin})
  end

  def build_methods_cmd cmd, culprits = [], bad = nil
    reset

    if bad then
      re = []

      # bad by class, you perv
      bbc = (culprits + [bad]).map { |s| s.split(/#/, 2) }.group_by(&:first)

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

  def result file, klass, method, fails, assertions, time
    fails.reject! { |fail| Minitest::Skip === fail }

    if mode == :methods then
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
