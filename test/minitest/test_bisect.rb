require "minitest/autorun"
require "minitest/bisect"

module TestMinitest; end

class TestMinitest::TestBisect < Minitest::Test
  def test_sanity
    flunk "write tests or I will kneecap you"
  end
end
