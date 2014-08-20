require "minitest/find_minimal_combination"
require "shellwords"

module Minitest; end

class Minitest::BisectFiles
  def self.run files
    new.run files
  end

  def build_cmd cmd, culprits, bad, rb, mt
    return false if bad and culprits.empty?

    tests = (culprits + [bad]).flatten.compact.map {|f| %(require "./#{f}")}
    tests = tests.join " ; "
    shh   = "&> /dev/null"
    cmd   = %(ruby #{rb.shelljoin} -e '#{tests}' -- #{mt.shelljoin} #{shh})

    cmd
  end

  def run files
    files, flags = files.partition { |arg| File.file? arg }
    rb_flags, mt_flags = flags.partition { |arg| arg =~ /^-I/ }

    cmd = build_cmd(nil, files, nil, rb_flags, mt_flags)

    puts "reproducing..."
    abort "Reproduction run passed? Aborting." if system cmd
    puts "reproduced"

    count = 0

    found = files.find_minimal_combination do |test|
      count += 1

      puts "# of culprits: #{test.size}"

      not system build_cmd(nil, test, nil, rb_flags, mt_flags)
    end

    puts
    puts "Final found in #{count} steps:"
    puts
    puts build_cmd nil, found, nil, rb_flags, mt_flags
  end
end
