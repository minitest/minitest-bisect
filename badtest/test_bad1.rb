require "minitest/autorun"

class TestBad1 < Minitest::Test
  def test_bad1_1
    $hosed = true
  end

  def test_bad1_2
    assert true
  end

  def test_bad1_3
    assert true
  end

  def test_bad1_4
    assert true
  end
end
