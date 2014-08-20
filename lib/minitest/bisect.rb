module Minitest; end

class Minitest::Bisect
  VERSION = "1.0.0"

  def self.run cmd
    new.run cmd
  end

  def build_cmd cmd, culprits, bad
    return false if bad and culprits.empty?

    re = Regexp.union(culprits + [bad]).to_s.gsub(/-mix/, "") if bad
    cmd += ["-n", "'/^#{re}$/'"] if bad
    cmd << "-v" unless cmd.include? "-v"

    # cheap but much more readable version of shellwords' shelljoin
    cmd.map { |s| s =~ / / ? "'#{s}'" : s }.join " "
  end

  def bisect cmd, culprits, bad
    puts "# of culprits: #{culprits.size}"
    a, b = culprits.halves
    if repro cmd, a, bad then
      if a.size > 1 then
        bisect cmd, a, bad
      else
        done cmd, a, bad
      end
    elsif repro cmd, b, bad then
      if b.size > 1 then
        bisect cmd, b, bad
      else
        done cmd, b, bad
      end
    else
      raise "logic bug?"
    end
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

  def done cmd, culprits, bad
    puts "No more culprits"
    puts
    cmd = build_cmd(cmd, culprits, bad)
    puts cmd
    puts
    system cmd
  end

  def run cmd
    puts "Reproducing failure..."

    s = repro cmd

    abort "Could not reproduce error. Aborting" unless s

    culprits, bad = extract_culprits s

    puts "OK... reproduced the failure"
    puts "The bad test is: #{bad}"
    puts

    bisect cmd, culprits, bad
  end
end

class Array
  def halves
    n = self.size / 2
    return self[0...n], self[n..-1]
  end
end
