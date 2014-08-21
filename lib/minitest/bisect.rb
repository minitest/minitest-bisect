require "minitest/find_minimal_combination"

class Minitest::Bisect
  VERSION = "1.0.0"

  def self.run cmd
    new.run cmd
  end

  def run cmd
    puts "reproducing..."
    s = repro cmd
    abort "Reproduction run passed? Aborting." unless s
    puts "reproduced"

    culprits, bad = extract_culprits s

    count = 0

    found = culprits.find_minimal_combination do |test|
      count += 1

      puts "# of culprits: #{test.size}"

      repro cmd, test, bad
    end

    puts
    puts "Final found in #{count} steps:"
    puts
    cmd = build_cmd cmd, found, bad
    puts cmd
    puts
    system cmd
  end

  def build_cmd cmd, culprits, bad
    return false if bad and culprits.empty?

    re = Regexp.union(culprits + [bad]).to_s.gsub(/-mix/, "") if bad
    cmd += ["-n", "'/^#{re}$/'"] if bad
    cmd << "-v" unless cmd.include? "-v"

    # cheap but much more readable version of shellwords' shelljoin
    cmd.map { |s| s =~ / / ? "'#{s}'" : s }.join " "
  end

  def extract_culprits s
    a = s.scan(/^(\w+\#\w+) = \d+\.\d+ s = (.)/)
    i = a.index { |(_,r)| r =~ /[EF]/ }
    a.map!(&:first)

    return a[0...i], a[i]
  end

  def repro cmd, culprits = [], bad = nil
    cmd = build_cmd cmd, culprits, bad
    s = `#{cmd}`
    not $?.success? and s
  end
end
