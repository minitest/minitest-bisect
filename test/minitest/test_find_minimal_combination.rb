#!/usr/bin/ruby -w

$: << "." << "lib"

gem "minitest"
require "minitest/autorun"
require "minitest/find_minimal_combination"

describe Array, :find_minimal_combination do
  def check(*bad)
    lambda { |sample| bad & sample == bad }
  end

  def assert_steps input, bad, exp
    tests = []

    found = input.find_minimal_combination do |test|
      tests << test
      bad & test == bad
    end

    assert_equal bad, found, "algorithm is bad"

    assert_equal exp, tests
  end

  def test_ordering_best_case
    a   = (0..15).to_a
    bad = [0, 1]
    exp = [[0, 1, 2, 3, 4, 5, 6, 7],
           [0, 1, 2, 3],
           [0, 1],
           [0],
           [1],
           [0, 1]]

    assert_steps a, bad, exp
  end

  def test_ordering
    a     = (0..15).to_a
    bad   = [0, 15]

    # lvl              collection
    #
    #  0 |                 A
    #  1 |         B               C
    #  2 |     D       E       F       G
    #  3 |   H   I   J   K   L   M   N   O
    #  4 |  0 1 2 3 4 5 6 7 8 9 A B C D E F
    #
    #  0    +++++++++++++++++++++++++++++++
    #  1    ---------------
    #  1                    ---------------
    #  2    -------         -------
    #  2    +++++++                 +++++++
    #  3    xxxxxxx
    #  3                            xxxxxxx
    #  3    ---                     ---
    #  3    +++                         +++
    #  4    xxx
    #  4                                xxx
    #  4    -                           -
    #  4    +                             +
    #
    #  - = miss
    #  + = hit
    #  x = unwanted test

    exp = [
           # level 1 = B, C
           [0, 1, 2, 3, 4, 5, 6, 7],
           [8, 9, 10, 11, 12, 13, 14, 15],

           # level 2 = DF, DG, EF, EG
           [0, 1, 2, 3, 8, 9, 10, 11],
           [0, 1, 2, 3, 12, 13, 14, 15],

           # level 3
           # [0, 1, 2, 3],     # I think this is bad, we've tested B
           # [12, 13, 14, 15], # again, bad, we've tested C
           [0, 1, 12, 13],
           [0, 1, 14, 15],

           # level 4
           # [0, 1],
           # [14, 15],
           [0, 14],
           [0, 15],
          ]

    assert_steps a, bad, exp
  end

  make_my_diffs_pretty!

  def self.test_find_minimal_combination max, *bad
    define_method "test_find_minimal_combination_#{max}_#{bad.join "_"}" do
      a = (1..max).to_a
      a.find_minimal_combination(&check(*bad)).must_equal bad
    end
  end

  test_find_minimal_combination    8, 5
  test_find_minimal_combination    8, 2, 7
  test_find_minimal_combination    8, 1, 2, 7
  test_find_minimal_combination    8, 1, 4, 7
  test_find_minimal_combination    8, 1, 3, 5, 7

  test_find_minimal_combination    9, 5
  test_find_minimal_combination    9, 9
  test_find_minimal_combination    9, 2, 7
  test_find_minimal_combination    9, 1, 2, 7
  test_find_minimal_combination    9, 1, 4, 7
  test_find_minimal_combination    9, 1, 3, 5, 7

  test_find_minimal_combination 1023, 5
  test_find_minimal_combination 1023, 1005
  test_find_minimal_combination 1023, 802, 907
  test_find_minimal_combination 1023, 7, 15, 166, 1001
  test_find_minimal_combination 1023, 1000, 1001, 1002
  test_find_minimal_combination 1023, 1001, 1003, 1005, 1007

  # test_find_minimal_combination 1024, 1001, 1003, 1005, 1007
  # test_find_minimal_combination 1023, 1001, 1003, 1005, 1007
end
