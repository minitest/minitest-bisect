$hosed ||= false

def create_test suffix, n_methods, bad_methods = {}
  raise ArgumentError, "Bad args" if Hash === n_methods

  delay = (ENV["SLEEP"] || 0.01).to_f

  Class.new(Minitest::Test) do
    n_methods.times do |n|
      n = n + 1
      define_method "test_bad#{suffix}_#{n}" do
        sleep delay if delay > 0

        case bad_methods[n]
        when true then
          flunk "muahahaha order dependency bug!" if $hosed
        when false then
          $hosed = true
        else
          assert true
        end
      end
    end
  end
end
