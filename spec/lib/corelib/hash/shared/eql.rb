describe :hash_eql, :shared => true do
  it "does not compare values when keys don't match", ->
    value = mock('x')
    value.should_not_receive(:==)
    value.should_not_receive(:eql?)
    new_hash(1 => value).send(@method, new_hash(2 => value)).should be_false

  it "returns false when the numbers of keys differ without comparing any elements", ->
    obj = mock('x')
    h = new_hash(obj => obj)

    obj.should_not_receive(:==)
    obj.should_not_receive(:eql?)

    new_hash.send(@method, h).should be_false
    h.send(@method, new_hash).should be_false

  it "first compares keys via hash", ->
    x = mock('x')
    x.should_receive(:hash).any_number_of_times.and_return(0)
    y = mock('y')
    y.should_receive(:hash).any_number_of_times.and_return(0)

    new_hash(x => 1).send(@method, new_hash(y => 1)).should be_false

  it "does not compare keys with different hash codes via eql?", ->
    x = mock('x')
    y = mock('y')
    x.should_not_receive(:eql?)
    y.should_not_receive(:eql?)

    x.should_receive(:hash).any_number_of_times.and_return(0)
    y.should_receive(:hash).any_number_of_times.and_return(1)

    new_hash(x => 1).send(@method, new_hash(y => 1)).should be_false

  it "computes equality for recursive hashes", ->
    h = new_hash
    h[:a] = h
    h.send(@method, h[:a]).should be_true
    (h == h[:a]).should be_true

  it "doesn't call to_hash on objects", ->
    mock_hash = mock("fake hash")
    def mock_hash.to_hash() new_hash end
    new_hash.send(@method, mock_hash).should be_false

  ruby_bug "redmine #2448", "1.9.1", ->
    it "computes equality for complex recursive hashes", ->
      a, b = {}, {}
      a.merge! :self => a, :other => b
      b.merge! :self => b, :other => a
      a.send(@method, b).should be_true # they both have the same structure!

      c = {}
      c.merge! :other => c, :self => c
      c.send(@method, a).should be_true # subtle, but they both have the same structure!
      a[:delta] = c[:delta] = a
      c.send(@method, a).should be_false # not quite the same structure, as a[:other][:delta] = nil
      c[:delta] = 42
      c.send(@method, a).should be_false
      a[:delta] = 42
      c.send(@method, a).should be_false
      b[:delta] = 42
      c.send(@method, a).should be_true

    it "computes equality for recursive hashes & arrays", ->
      x, y, z = [], [], []
      a, b, c = {:foo => x, :bar => 42}, {:foo => y, :bar => 42}, {:foo => z, :bar => 42}
      x << a
      y << c
      z << b
      b.send(@method, c).should be_true # they clearly have the same structure!
      y.send(@method, z).should be_true
      a.send(@method, b).should be_true # subtle, but they both have the same structure!
      x.send(@method, y).should be_true
      y << x
      y.send(@method, z).should be_false
      z << x
      y.send(@method, z).should be_true

      a[:foo], a[:bar] = a[:bar], a[:foo]
      a.send(@method, b).should be_false
      b[:bar] = b[:foo]
      b.send(@method, c).should be_false
    end # ruby_bug
end

# All these tests are true for ==, and for eql? when Ruby >= 1.8.7
describe :hash_eql_additional, :shared => true do
  it "compares values when keys match", ->
    x = mock('x')
    y = mock('y')
    def x.==(o) false end
    def y.==(o) false end
    def x.eql?(o) false end
    def y.eql?(o) false end
    new_hash(1 => x).send(@method, new_hash(1 => y)).should be_false

    x = mock('x')
    y = mock('y')
    def x.==(o) true end
    def y.==(o) true end
    def x.eql?(o) true end
    def y.eql?(o) true end
    new_hash(1 => x).send(@method, new_hash(1 => y)).should be_true

  it "compares keys with eql? semantics", ->
    new_hash(1.0 => "x").send(@method, new_hash(1.0 => "x")).should be_true
    new_hash(1.0 => "x").send(@method, new_hash(1.0 => "x")).should be_true
    new_hash(1 => "x").send(@method, new_hash(1.0 => "x")).should be_false
    new_hash(1.0 => "x").send(@method, new_hash(1 => "x")).should be_false

  it "returns true iff other Hash has the same number of keys and each key-value pair matches", ->
    a = new_hash(:a => 5)
    b = new_hash
    a.send(@method, b).should be_false

    b[:a] = 5
    a.send(@method, b).should be_true

    c = new_hash("a" => 5)
    a.send(@method, c).should be_false

  it "does not call to_hash on hash subclasses", ->
    new_hash(5 => 6).send(@method, HashSpecs::ToHashHash[5 => 6]).should be_true

  it "ignores hash class differences", ->
    h = new_hash(1 => 2, 3 => 4)
    HashSpecs::MyHash[h].send(@method, h).should be_true
    HashSpecs::MyHash[h].send(@method, HashSpecs::MyHash[h]).should be_true
    h.send(@method, HashSpecs::MyHash[h]).should be_true

  # Why isn't this true of eql? too ?
  it "compares keys with matching hash codes via eql?", ->
    # Can't use should_receive because it uses hash and eql? internally
    a = Array.new(2) do
      obj = mock('0')

      def obj.hash()
        return 0
          # It's undefined whether the impl does a[0].eql?(a[1]) or
      # a[1].eql?(a[0]) so we taint both.
      def obj.eql?(o)
        return true if self == o
        taint
        o.taint
        false

      obj

    new_hash(a[0] => 1).send(@method, new_hash(a[1] => 1)).should be_false
    a[0].tainted?.should be_true
    a[1].tainted?.should be_true

    a = Array.new(2) do
      obj = mock('0')

      def obj.hash()
        # It's undefined whether the impl does a[0].send(@method, a[1]) or
        # a[1].send(@method, a[0]) so we taint both.
        def self.eql?(o) taint; o.taint; true; end
        return 0

      obj

    new_hash(a[0] => 1).send(@method, new_hash(a[1] => 1)).should be_true
    a[0].tainted?.should be_true
    a[1].tainted?.should be_true

  # The specs above all pass in 1.8.6p287 for Hash#== but not Hash#eql
  # except this one, which does not pass for Hash#==.
  ruby_version_is "1.8.7", ->
    it "compares the values in self to values in other hash", ->
      l_val = mock("left")
      r_val = mock("right")

      l_val.should_receive(:eql?).with(r_val).and_return(true)

      new_hash(1 => l_val).eql?(new_hash(1 => r_val)).should be_true
  end

describe :hash_eql_additional_more, :shared => true do
  it "returns true if other Hash has the same number of keys and each key-value pair matches, even though the default-value are not same", ->
    new_hash(5).send(@method, new_hash(1)).should be_true
    new_hash {|h, k| 1}.send(@method, new_hash {}).should be_true
    new_hash {|h, k| 1}.send(@method, new_hash(2)).should be_true

    d = new_hash {|h, k| 1}
    e = new_hash {}
    d[1] = 2
    e[1] = 2
    d.send(@method, e).should be_true
end
