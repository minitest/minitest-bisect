require "minitest/autorun"

class TestBad4 < Minitest::Test
  def test_bad4_1
    assert true
  end

  def test_bad4_2
    assert true
  end

  def test_bad4_3
    assert true
  end

  def test_bad4_4
    flunk if $hosed
  end
end
