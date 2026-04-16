require "./spec_helper"

module XPath2
  describe XPath2 do
    it "Test XPath self" do
      tests = [
        {root: HTML, exp: ".", expected: "html"},
        {root: HTML.first_child.not_nil!, exp: ".", expected: "head"},
        {root: HTML, exp: "self::*", expected: "html"},
        {root: HTML.last_child.not_nil!, exp: "self::body", expected: "body"},
      ]
      test_nodes = [
        {root: HTML, exp: "//body/./ul/li/a", expected: 3},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath parent" do
      tests = [
        {root: HTML.last_child.not_nil!, exp: "..", expected: "html"},
        {root: HTML.last_child.not_nil!, exp: "parent::*", expected: "html"},
        {root: HTML, exp: "//title/parent::head", expected: "head"},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end

      a = select_node(HTML, "//li/a")
      n = select_node(a.not_nil!, "parent::*")
      fail "Xpath expression `parent::*` returned node is nil, expecting `li`" if n.nil?
      n.try &.data.should eq("li")
    end

    it "Test XPath Attributes" do
      tests = [
        {root: HTML, exp: "@lang='en'", expected: "html"},
      ]
      test_nodes = [
        {root: HTML, exp: "@lang='zh'", expected: 0},
        {root: HTML, exp: "//@href", expected: 3},
        {root: HTML.last_child.not_nil!, exp: "//a[@*]", expected: 3},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath Sequence" do
      test_nodes = [
        {root: HTML2, exp: "//table/tbody/tr/td/(para, .[not(para)])", expected: 9},
        {root: HTML2, exp: "//table/tbody/tr/td/(para, .[not(para)], ..)", expected: 12},
      ]

      test_nodes.each do |t|
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath Relative path" do
      tests = [
        {root: HTML, exp: "head", expected: "head"},
        {root: HTML, exp: "/head", expected: "head"},
        {root: HTML, exp: "body//li", expected: "li"},
        {root: HTML, exp: "/head/title", expected: "title"},
        {root: HTML, exp: "//title", expected: "title"},
        {root: HTML, exp: "//title/..", expected: "head"},
        {root: HTML, exp: "//title/../..", expected: "html"},
        {root: HTML, exp: "//ul/../footer", expected: "footer"},
      ]
      test_nodes = [
        {root: HTML, exp: "//body/ul/li/a", expected: 3},
        {root: HTML, exp: "//a[@href]", expected: 3},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath Child" do
      tests = [
        {root: HTML, exp: "/child::head", expected: "head"},
        {root: HTML, exp: "/child::head/child::title", expected: "title"},
        {root: HTML, exp: "//title/../child::title", expected: "title"},
        {root: HTML.parent.not_nil!, exp: "//child::*", expected: "html"},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end
    end

    it "Test XPath Descendant" do
      test_nodes = [
        {root: HTML, exp: "descendant::*", expected: 15},
        {root: HTML, exp: "/head/descendant::*", expected: 2},
        {root: HTML, exp: "//ul/descendant::*", expected: 7},  # <li> + <a>
        {root: HTML, exp: "//ul/descendant::li", expected: 4}, # <li>
      ]

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath Ancestor" do
      test_nodes = [
        {root: HTML, exp: "/body/footer/ancestor::*", expected: 2}, # body>html
        {root: HTML, exp: "/body/ul/li/a/ancestor::li", expected: 3},
        {root: HTML, exp: "/body/ul/li/a/ancestor-or-self::li", expected: 3},
      ]

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test Following Siblings" do
      list = select_nodes(HTML, "//li/following-sibling::*")
      list.each do |n|
        fail "expected node is li, but got #{n.data}" unless n.data == "li"
      end

      n = select_node(HTML, "//ul/following-sibling::footer")
      "footer".should eq(n.try &.data)

      list = select_nodes(HTML, "//h1/following::*") # ul>li>a,p,footer
      list.size.should be > 2
      fail "expected node is ul, but got #{list[0].data}" unless list[0].data == "ul"
      fail "expected node is li, but got #{list[1].data}" unless list[1].data == "li"
      fail "expected node is footer, but got #{list[-2].data}" unless list[-2].data == "p"
      fail "expected node is footer, but got #{list[-1].data}" unless list[-1].data == "footer"
    end

    it "Test Preceding Siblings" do
      n = select_node(HTML, "/body/footer/preceding-sibling::*")
      "p".should eq(n.try &.data)

      list = select_nodes(HTML, "/body/footer/preceding-sibling::*") # p,ul,h1
      list.size.should eq(3)

      list = select_nodes(HTML, "//h1/preceding::*") # head>title>meta
      list.size.should eq(3)
      fail "expected node is head, but got #{list[0].data}" unless list[0].data == "head"
      fail "expected node is title, but got #{list[1].data}" unless list[1].data == "title"
      fail "expected node is meta, but got #{list[2].data}" unless list[2].data == "meta"
    end

    it "Test XPath StarWide" do
      tests = [
        {root: HTML, exp: "/head/*", expected: "title"},
        {root: HTML, exp: "@*", expected: "html"},
      ]
      test_nodes = [
        {root: HTML, exp: "//ul/*", expected: 4},
        {root: HTML, exp: "/body/h1/*", expected: 0},
        {root: HTML, exp: "//ul/*/a", expected: 3},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath Node Test Type" do
      tests = [
        {root: HTML, exp: "//title/text()", expected: "Hello"},
        {root: HTML, exp: "//a[@href='/']/text()", expected: "Home"},
      ]
      test_nodes = [
        {root: HTML, exp: "//head/node()", expected: 2},
        {root: HTML, exp: "//ul/node()", expected: 4},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n.try &.data)
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test XPath Position" do
      n = select_node(HTML, "/head[1]")
      fail "XPath expression '/head[1]' returned node is nil" if n.nil?
      HTML.first_child.should eq(n)

      n = select_node(HTML, "/head[last()]")
      fail "XPath expression '/head[last()]' returned node is nil" if n.nil?
      HTML.first_child.should eq(n)

      ul = select_node(HTML, "//ul")

      n = select_node(HTML, "//li[1]")
      fail "XPath expression '//li[1]' returned node is nil" if n.nil?
      ul.not_nil!.first_child.should eq(n)

      n = select_node(HTML, "//li[4]")
      fail "XPath expression '//li[3]' returned node is nil" if n.nil?
      ul.not_nil!.last_child.should eq(n)

      list = select_nodes(HTML2, "//td[2]")
      list.size.should eq(3)
    end

    it "Test XPath Predicate" do
      ul = select_node(HTML, "//ul")
      tests = [
        {root: HTML.parent.not_nil!, exp: "html[@lang='en']", expected: "html"},
        {root: HTML, exp: "//a[@href='/']", expected: "a"},
        {root: HTML, exp: "//meta[@name]", expected: "meta"},
        {root: HTML, exp: "//li[position()=4]", expected: ul.not_nil!.last_child},
        {root: HTML, exp: "//li[position()=1]", expected: ul.not_nil!.first_child},
        {root: HTML, exp: "//a[text()='Home']", expected: select_node(HTML, "//a[1]").not_nil!},
      ]
      test_nodes = [
        {root: HTML, exp: "//li[position()>0]", expected: 4},
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        if t[:expected].is_a?(String)
          t[:expected].should eq(n.try &.data)
        else
          t[:expected].should eq(n)
        end
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end

    it "Test Or and And" do
      list = select_nodes(HTML, "//h1|//footer")
      list.size.should eq(2)
      fail "expected first node of node-set is h1, but got #{list[0].data}" unless list[0].data == "h1"
      fail "expected second node of node-set is footer, but got #{list[1].data}" unless list[1].data == "footer"

      list = select_nodes(HTML, "//a[@id=1 or @id=2]")
      list.size.should eq(2)
      list[0].should eq(select_node(HTML, "//a[@id=1]"))
      list[1].should eq(select_node(HTML, "//a[@id=2]"))

      list = select_nodes(HTML, "//a[@id or @href]")
      list.size.should be > 0
      list[0].should eq(select_node(HTML, "//a[@id=1]"))
      list[1].should eq(select_node(HTML, "//a[@id=2]"))

      tests = [
        {root: HTML, exp: "//a[@id=1 and @href='/']", expected: select_node(HTML, "//a[1]")},
        {root: HTML, exp: "//a[text()='Home' and @id='1']", expected: select_node(HTML, "//a[1]")},
      ]

      tests.each do |t|
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n)
      end
    end

    it "Test Functions" do
      test_evals = [
        {root: HTML, exp: "boolean(//*[@id])", expected: true},
        {root: HTML, exp: "boolean(//*[@x])", expected: false},
        {root: HTML, exp: "name(//title)", expected: "title"},
        {root: HTML, exp: "true()", expected: true},
        {root: HTML, exp: "false()", expected: false},
        {root: HTML, exp: "boolean(0)", expected: false},
        {root: HTML, exp: "boolean(1)", expected: true},
        {root: HTML, exp: "sum(1+2)", expected: 3_f64},
        {root: HTML, exp: "string(sum(1+2))", expected: "3"},
        {root: HTML, exp: "sum(1.1+2)", expected: 3.1},
        {root: HTML, exp: "sum(//a/@id)", expected: 6_f64}, # 1+2+3
        {root: HTML, exp: %(concat("1","2","3")), expected: "123"},
        {root: HTML, exp: %(concat(" ",//a[@id='1']/@href," ")), expected: " / "},
        {root: HTML, exp: "ceiling(5.2)", expected: 6_f64},
        {root: HTML, exp: "floor(5.2)", expected: 5_f64},
        {root: HTML, exp: "substring-before('aa-bb','-')", expected: "aa"},
        {root: HTML, exp: "substring-before('aa-bb','a')", expected: ""},
        {root: HTML, exp: "substring-before('aa-bb','b')", expected: "aa-"},
        {root: HTML, exp: "substring-before('aa-bb','q')", expected: ""},
        {root: HTML, exp: "substring-after('aa-bb','-')", expected: "bb"},
        {root: HTML, exp: "substring-after('aa-bb','a')", expected: "a-bb"},
        {root: HTML, exp: "substring-after('aa-bb','b')", expected: "b"},
        {root: HTML, exp: "substring-after('aa-bb','q')", expected: ""},
        {root: HTML, exp: "replace('aa-bb-cc','bb','ee')", expected: "aa-ee-cc"},
        {root: HTML, exp: %(translate('The quick brown fox.', 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')),
         expected: "THE QUICK BROWN FOX."},
        {root: HTML, exp: "translate('The quick brown fox.', 'brown', 'red')", expected: "The quick red fdx."},
      ]
      tests = [
        {root: HTML, exp: "//*[starts-with(name(),'h1')]", expected: "h1"},
        {root: HTML, exp: "//*[ends-with(name(),'itle')]", expected: "title"},
        {root: HTML, exp: "//h1[normalize-space(text())='This is a H1']", expected: select_node(HTML, "//h1")},
        {root: HTML, exp: "//title[substring(.,1)='Hello']", expected: select_node(HTML, "//title")},
        {root: HTML, exp: "//title[substring(text(),1,4)='Hell']", expected: select_node(HTML, "//title")},
        {root: HTML, exp: "//title[substring(self::*,1,4)='Hell']", expected: select_node(HTML, "//title")},
        {root: HTML, exp: "//li[not(a)]", expected: select_node(HTML, "//ul/li[4]")},
        # preceding-sibling::*
        {root: HTML, exp: "//li[last()]/preceding-sibling::*[2]", expected: select_node(HTML, "//li[position()=2]")},
        # preceding::
        {root: HTML, exp: "//li/preceding::*[1]", expected: select_node(HTML, "//h1")},
      ]
      test_nodes = [
        {root: HTML, exp: "//*[name()='a']", expected: 3},
        {root: HTML, exp: "//*[contains(@href,'a')]", expected: 2},
        {root: HTML, exp: "//*[starts-with(@href,'/a')]", expected: 2},   # a links: /account, /about
        {root: HTML, exp: "//*[ends-with(@href,'t')]", expected: 2},      # a links: /account, /about
        {root: HTML, exp: "//title[substring(child::*,1)]", expected: 0}, # Here substring return boolean (false), should it?
        {root: HTML, exp: "//title[substring(child::*,1) = '']", expected: 1},
        {root: HTML, exp: "//li/a[not(@id='1')]", expected: 2}, # //li/a[@id!=1]
        {root: HTML, exp: "//h1[string-length(normalize-space(' abc ')) = 3]", expected: 1},

        {root: HTML, exp: "//h1[string-length(normalize-space(self::text())) = 12]", expected: 1},
        {root: HTML, exp: "//title[string-length(normalize-space(child::*)) = 0]", expected: 1},
        {root: HTML, exp: "//title[string-length(self::text()) = 5]", expected: 1}, # Hello = 5
        {root: HTML, exp: "//title[string-length(child::*) = 5]", expected: 0},
        {root: HTML, exp: "//ul[count(li)=4]", expected: 1},

      ]

      test_evals.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = do_eval(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n}" unless n == t[:expected]
      end

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        if t[:expected].is_a?(String)
          t[:expected].should eq(n.try &.data)
        else
          t[:expected].should eq(n)
        end
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end

      arr = do_eval(HTML, "boolean(//*[@x])")
      pp arr
    end

    it "Test zero-arg normalize-space and string-length" do
      # normalize-space() with no args should use context node's string value
      # The h1 node has "\nThis is a H1\n" as text, normalize-space should give "This is a H1"
      n = select_node(HTML, "//h1[normalize-space()='This is a H1']")
      fail "normalize-space() zero-arg: expected h1 node" if n.nil?
      n.data.should eq("h1")

      # string-length() with no args should return length of context node's string value
      # title text is "Hello" = 5 chars
      n = select_node(HTML, "//title[string-length()=5]")
      fail "string-length() zero-arg: expected title node" if n.nil?
      n.data.should eq("title")

      # Combined: string-length of normalize-space of context node
      val = do_eval(HTML, "string-length(normalize-space(' hello world '))")
      val.should eq(11_f64)
    end

    it "Test matches() function" do
      # Basic regex match
      val = do_eval(HTML, "matches('hello world', 'hello')")
      val.should eq(true)

      val = do_eval(HTML, "matches('hello world', '^world')")
      val.should eq(false)

      val = do_eval(HTML, "matches('hello world', 'world$')")
      val.should eq(true)

      # Case-insensitive flag
      val = do_eval(HTML, "matches('Hello', 'hello', 'i')")
      val.should eq(true)

      # Use in predicate: find <a> elements whose href matches a pattern
      list = select_nodes(HTML, "//a[matches(@href, '^/a')]")
      list.size.should eq(2) # /about, /account

      # Regex with character class
      list = select_nodes(HTML, "//a[matches(@href, '/a[bc]')]")
      list.size.should eq(2) # /about, /account

      # No match
      list = select_nodes(HTML, "//a[matches(@href, '^https')]")
      list.size.should eq(0)

      # Error: too few args
      expect_raises(XPath2Exception, "matches() must have two or three arguments") do
        do_eval(HTML, "matches('hello')")
      end
    end

    it "Test lower-case() and upper-case() functions" do
      val = do_eval(HTML, "lower-case('HELLO')")
      val.should eq("hello")

      val = do_eval(HTML, "upper-case('hello')")
      val.should eq("HELLO")

      # Mixed case
      val = do_eval(HTML, "lower-case('HeLLo WoRLd')")
      val.should eq("hello world")

      # Use in predicate: case-insensitive name match
      n = select_node(HTML, "//*[lower-case(name())='title']")
      fail "lower-case() in predicate: expected title node" if n.nil?
      n.data.should eq("title")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "lower-case() must have exactly one argument") do
        do_eval(HTML, "lower-case()")
      end
      expect_raises(XPath2Exception, "upper-case() must have exactly one argument") do
        do_eval(HTML, "upper-case()")
      end
    end

    it "Test lang() function" do
      # The html element has lang="en"
      val = do_eval(HTML, "lang('en')")
      val.should eq(true)

      # Should not match a different language
      val = do_eval(HTML, "lang('fr')")
      val.should eq(false)

      # lang() should match subtags: "en" matches "en-US" style
      # Our test HTML has lang="en", so "en" should match exactly
      n = select_node(HTML, "//*[lang('en')]")
      fail "lang() in predicate: expected html node" if n.nil?
      n.data.should eq("html")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "lang() must have exactly one argument") do
        do_eval(HTML, "lang()")
      end
    end

    it "Test id() function" do
      # id('1') should find the <a> element with id="1"
      list = select_nodes(HTML, "id('1')")
      list.size.should eq(1)
      list[0].data.should eq("a")

      # id with multiple space-separated IDs
      list = select_nodes(HTML, "id('1 2')")
      list.size.should eq(2)

      # id with non-existent ID
      list = select_nodes(HTML, "id('nonexistent')")
      list.size.should eq(0)

      # Error: wrong arg count
      expect_raises(XPath2Exception, "id() must have exactly one argument") do
        do_eval(HTML, "id()")
      end
    end

    it "Test generate-id() function" do
      # generate-id() should return a non-empty string
      val = do_eval(HTML, "generate-id(//title)")
      val.should be_a(String)
      val.as(String).should_not be_empty
      val.as(String).starts_with?("id").should be_true

      # Same node should produce same id
      val2 = do_eval(HTML, "generate-id(//title)")
      val.should eq(val2)

      # Different nodes should produce different ids
      val3 = do_eval(HTML, "generate-id(//body)")
      val.should_not eq(val3)

      # Zero-arg form should work (uses context node)
      val4 = do_eval(HTML, "generate-id()")
      val4.should be_a(String)
      val4.as(String).should_not be_empty
    end

    it "Test function-available() function" do
      val = do_eval(HTML, "function-available('contains')")
      val.should eq(true)

      val = do_eval(HTML, "function-available('matches')")
      val.should eq(true)

      val = do_eval(HTML, "function-available('nonexistent')")
      val.should eq(false)

      val = do_eval(HTML, "function-available('document')")
      val.should eq(false)
    end

    it "Test XPath 2.0 tokenize() function" do
      # Basic tokenize with regex
      val = do_eval(HTML, "tokenize('a, b, c', ',\\s*')")
      val.should eq("a b c")

      # Simple delimiter
      val = do_eval(HTML, "tokenize('one-two-three', '-')")
      val.should eq("one two three")

      # Single token (no match for delimiter)
      val = do_eval(HTML, "tokenize('hello', ',')")
      val.should eq("hello")

      # Multiple spaces as delimiter
      val = do_eval(HTML, "tokenize('a  b  c', '\\s+')")
      val.should eq("a b c")

      # Tokenize with pipe delimiter
      val = do_eval(HTML, "tokenize('x|y|z', '\\|')")
      val.should eq("x y z")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "tokenize() must have exactly two arguments") do
        do_eval(HTML, "tokenize('hello')")
      end
    end

    it "Test XPath 2.0 string-join() function" do
      # Join attribute values with comma
      val = do_eval(HTML, "string-join(//a/@id, ',')")
      val.should eq("1,2,3")

      # Join with empty separator
      val = do_eval(HTML, "string-join(//a/@id, '')")
      val.should eq("123")

      # Join with multi-char separator
      val = do_eval(HTML, "string-join(//a/@id, ' - ')")
      val.should eq("1 - 2 - 3")

      # Join single node — should return just the value
      val = do_eval(HTML, "string-join(//title, ',')")
      val.should eq("Hello")

      # Join empty node-set — should return empty string
      val = do_eval(HTML, "string-join(//nonexistent, ',')")
      val.should eq("")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "string-join() must have exactly two arguments") do
        do_eval(HTML, "string-join(//a)")
      end
    end

    it "Test XPath 2.0 abs() function" do
      val = do_eval(HTML, "abs(-5)")
      val.should eq(5_f64)

      val = do_eval(HTML, "abs(3.14)")
      val.should eq(3.14)

      val = do_eval(HTML, "abs(0)")
      val.should eq(0_f64)

      # abs of negative float
      val = do_eval(HTML, "abs(-2.7)")
      val.should eq(2.7)

      # abs in arithmetic expression
      val = do_eval(HTML, "abs(3 - 10)")
      val.should eq(7_f64)

      # Error: wrong arg count
      expect_raises(XPath2Exception, "abs() must have exactly one argument") do
        do_eval(HTML, "abs()")
      end
    end

    it "Test XPath 2.0 compare() function" do
      val = do_eval(HTML, "compare('abc', 'abc')")
      val.should eq(0_f64)

      val = do_eval(HTML, "compare('abc', 'def')")
      val.should eq(-1_f64)

      val = do_eval(HTML, "compare('def', 'abc')")
      val.should eq(1_f64)

      # Compare empty strings
      val = do_eval(HTML, "compare('', '')")
      val.should eq(0_f64)

      # Compare with empty
      val = do_eval(HTML, "compare('a', '')")
      val.should eq(1_f64)

      val = do_eval(HTML, "compare('', 'a')")
      val.should eq(-1_f64)

      # Error: wrong arg count
      expect_raises(XPath2Exception, "compare() must have exactly two arguments") do
        do_eval(HTML, "compare('a')")
      end
    end

    it "Test XPath 2.0 empty() and exists() functions" do
      # empty() on non-empty node-set
      val = do_eval(HTML, "empty(//title)")
      val.should eq(false)

      # empty() on empty node-set
      val = do_eval(HTML, "empty(//nonexistent)")
      val.should eq(true)

      # exists() on non-empty node-set
      val = do_eval(HTML, "exists(//title)")
      val.should eq(true)

      # exists() on empty node-set
      val = do_eval(HTML, "exists(//nonexistent)")
      val.should eq(false)

      # empty/exists on attributes
      val = do_eval(HTML, "empty(//a/@href)")
      val.should eq(false)

      val = do_eval(HTML, "empty(//a/@nonexistent)")
      val.should eq(true)

      val = do_eval(HTML, "exists(//a/@href)")
      val.should eq(true)

      val = do_eval(HTML, "exists(//a/@nonexistent)")
      val.should eq(false)

      # Use in predicates
      n = select_node(HTML, "//ul[exists(li)]")
      fail "exists() in predicate: expected ul" if n.nil?
      n.data.should eq("ul")

      n = select_node(HTML, "//ul[empty(span)]")
      fail "empty() in predicate: expected ul" if n.nil?
      n.data.should eq("ul")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "empty() must have exactly one argument") do
        do_eval(HTML, "empty()")
      end
      expect_raises(XPath2Exception, "exists() must have exactly one argument") do
        do_eval(HTML, "exists()")
      end
    end

    it "Test XPath 2.0 distinct-values() function" do
      # All <a> ids are unique, so distinct-values should return all 3
      nodes = select_nodes(HTML, "distinct-values(//a/@id)")
      nodes.size.should eq(3)

      # Test with //a elements (3 elements, all different values)
      nodes = select_nodes(HTML, "distinct-values(//a)")
      nodes.size.should eq(3)

      # Error: wrong arg count
      expect_raises(XPath2Exception, "distinct-values() must have exactly one argument") do
        select_nodes(HTML, "distinct-values()")
      end
    end

    it "Test XPath 2.0 subsequence() function" do
      # Get li elements starting from position 2 (no length — get all remaining)
      nodes = select_nodes(HTML, "subsequence(//li, 2)")
      nodes.size.should eq(3) # li[2], li[3], li[4]

      # Get 2 li elements starting from position 2
      nodes = select_nodes(HTML, "subsequence(//li, 2, 2)")
      nodes.size.should eq(2) # li[2], li[3]

      # Get first element only
      nodes = select_nodes(HTML, "subsequence(//li, 1, 1)")
      nodes.size.should eq(1)

      # Get last element
      nodes = select_nodes(HTML, "subsequence(//li, 4, 1)")
      nodes.size.should eq(1)

      # Start beyond sequence length — empty result
      nodes = select_nodes(HTML, "subsequence(//li, 10)")
      nodes.size.should eq(0)

      # Length of 0 — empty result
      nodes = select_nodes(HTML, "subsequence(//li, 1, 0)")
      nodes.size.should eq(0)

      # On <a> elements
      nodes = select_nodes(HTML, "subsequence(//a, 2, 1)")
      nodes.size.should eq(1)
      nodes[0].data.should eq("a")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "subsequence() must have two or three arguments") do
        select_nodes(HTML, "subsequence(//li)")
      end
    end

    it "Test XPath 2.0 remove() function" do
      # Remove the 2nd li element
      nodes = select_nodes(HTML, "remove(//li, 2)")
      nodes.size.should eq(3) # li[1], li[3], li[4]

      # Remove the 1st element
      nodes = select_nodes(HTML, "remove(//li, 1)")
      nodes.size.should eq(3) # li[2], li[3], li[4]

      # Remove the last element
      nodes = select_nodes(HTML, "remove(//li, 4)")
      nodes.size.should eq(3) # li[1], li[2], li[3]

      # Remove position beyond range — returns all
      nodes = select_nodes(HTML, "remove(//li, 99)")
      nodes.size.should eq(4)

      # Remove from <a> elements
      nodes = select_nodes(HTML, "remove(//a, 1)")
      nodes.size.should eq(2)

      # Error: wrong arg count
      expect_raises(XPath2Exception, "remove() must have exactly two arguments") do
        select_nodes(HTML, "remove(//li)")
      end
    end

    it "Test XPath 2.0 insert-before() function" do
      # Insert title before 2nd li
      nodes = select_nodes(HTML, "insert-before(//li, 2, //title)")
      nodes.size.should eq(5) # li[1], title, li[2], li[3], li[4]
      nodes[0].data.should eq("li")
      nodes[1].data.should eq("title")
      nodes[2].data.should eq("li")

      # Insert at position 1 (before first)
      nodes = select_nodes(HTML, "insert-before(//li, 1, //title)")
      nodes.size.should eq(5)
      nodes[0].data.should eq("title")
      nodes[1].data.should eq("li")

      # Insert at position beyond length (append at end)
      nodes = select_nodes(HTML, "insert-before(//li, 99, //title)")
      nodes.size.should eq(5)
      nodes[4].data.should eq("title")

      # Insert multiple nodes
      nodes = select_nodes(HTML, "insert-before(//li, 2, //a)")
      nodes.size.should eq(7) # li[1], a[1], a[2], a[3], li[2], li[3], li[4]
      nodes[0].data.should eq("li")
      nodes[1].data.should eq("a")

      # Error: wrong arg count
      expect_raises(XPath2Exception, "insert-before() must have exactly three arguments") do
        select_nodes(HTML, "insert-before(//li, 2)")
      end
    end

    it "Test XPath 2.0 index-of() function" do
      # Find position of the <a> with id="2"
      val = do_eval(HTML, "index-of(//a/@id, '2')")
      val.should eq(2_f64)

      # Find first item
      val = do_eval(HTML, "index-of(//a/@id, '1')")
      val.should eq(1_f64)

      # Find last item
      val = do_eval(HTML, "index-of(//a/@id, '3')")
      val.should eq(3_f64)

      # Not found
      val = do_eval(HTML, "index-of(//a/@id, '99')")
      val.should eq(0_f64)

      # Index-of on element text values
      val = do_eval(HTML, "index-of(//a, 'about')")
      val.should eq(2_f64)

      # Index-of on href attributes
      val = do_eval(HTML, "index-of(//a/@href, '/about')")
      val.should eq(2_f64)

      # Error: wrong arg count
      expect_raises(XPath2Exception, "index-of() must have exactly two arguments") do
        do_eval(HTML, "index-of(//a)")
      end
    end

    it "Test variable binding" do
      # String variable in attribute comparison
      vars = {"target" => "1".as(ExprResult)}
      n = select_node_with_vars(HTML, "//a[@id=$target]", vars)
      fail "variable binding: expected a node" if n.nil?
      n.data.should eq("a")

      # Verify it matched the right one
      list = select_nodes_with_vars(HTML, "//a[@id=$target]", vars)
      list.size.should eq(1)

      # String variable for href matching
      vars = {"path" => "/about".as(ExprResult)}
      n = select_node_with_vars(HTML, "//a[@href=$path]", vars)
      fail "variable binding: expected a node for href" if n.nil?
      n.data.should eq("a")

      # Numeric variable in position predicate
      vars = {"pos" => 2_f64.as(ExprResult)}
      n = select_node_with_vars(HTML, "//li[$pos]", vars)
      fail "variable binding: expected li node" if n.nil?

      # Variable in function argument
      vars = {"prefix" => "/a".as(ExprResult)}
      list = select_nodes_with_vars(HTML, "//a[starts-with(@href, $prefix)]", vars)
      list.size.should eq(2) # /about, /account

      # Variable in evaluate
      vars = {"x" => 5_f64.as(ExprResult)}
      val = do_eval_with_vars(HTML, "$x + 10", vars)
      val.should eq(15_f64)

      # Variable in string function
      vars = {"word" => "Hello".as(ExprResult)}
      val = do_eval_with_vars(HTML, "string-length($word)", vars)
      val.should eq(5_f64)

      # Multiple variables
      vars = {"lo" => 1_f64.as(ExprResult), "hi" => 3_f64.as(ExprResult)}
      list = select_nodes_with_vars(HTML, "//a[@id>=$lo and @id<=$hi]", vars)
      list.size.should eq(3)

      # Boolean variable
      vars = {"flag" => true.as(ExprResult)}
      val = do_eval_with_vars(HTML, "$flag", vars)
      val.should eq(true)

      # Undeclared variable should raise
      expect_raises(XPath2Exception, "undeclared variable") do
        do_eval_with_vars(HTML, "$undefined", Hash(String, ExprResult).new)
      end

      # Compile without variables still works (backward compatible)
      n = select_node(HTML, "//title")
      fail "non-variable compile should still work" if n.nil?
      n.data.should eq("title")
    end

    it "Test Transform functions" do
      nodes = select_nodes(HTML, "reverse(//li)")
      expected = ["", "login", "about", "Home"]
      nodes.size.should eq(expected.size)
      expected.each_with_index do |ex, i|
        nodes[i].value.should eq(ex)
      end

      # Although this xpath itself doesn't make much sense, it does exercise the call path
      # to provide coverage for TransformQuery#evaluate method.
      nodes = select_nodes(HTML, "//h1[reverse(.) = reverse(.)]")
      nodes.size.should eq(1)

      expect_raises(XPath2Exception, "reverse(node-sets) function must have parameter node-set") do
        select_nodes(HTML, "reverse()")
      end

      expect_raises(XPath2Exception, "concat() must have at least two arguments") do
        select_nodes(HTML, "reverse(concat())")
      end
    end

    it "Test Invalid XPath Queries" do
      tests = [
        {HTML, "//*[starts-with(0, 0)]"},
        {HTML, "//*[starts-with(name(), 0)]"},
        {HTML, "//*[ends-with(0, 0)]"},
        {HTML, "//*[ends-with(name(), 0)]"},
        {HTML, "//*[contains(0, 0)]"},
        {HTML, "//*[contains(@href, 0)]"},
        {HTML, "//title[sum('Hello') = 0]"},
        {HTML, "//title[substring(.,'')=0]"},
        {HTML, "//title[substring(.,4,'')=0]"},
        {HTML, "//title[substring(.,4,4)=0]"},
      ]

      tests.each do |t|
        expect_raises(XPath2Exception) do
          select_node(t[0], t[1])
        end
      end
    end

    it "Test Evaluate method" do
      do_evals(HTML, "//html/@lang", ["en"])
      do_evals(HTML, "//title/text()", ["Hello"])
    end

    it "Test Operators and Logical operators" do
      tests = [
        {root: HTML, exp: "//li[1+1]", expected: select_node(HTML, "//li[2]")},
        {root: HTML, exp: "//li[5 div 2]", expected: select_node(HTML, "//li[2]")},
        {root: HTML, exp: "//li[3 mod 2]", expected: select_node(HTML, "//li[1]")},
        {root: HTML, exp: "//li[3 - 2]", expected: select_node(HTML, "//li[1]")},
        {root: HTML, exp: "//a[@id=1 and @href='/']", expected: select_node(HTML, "//a[1]")},
      ]

      test_nodes = [
        {root: HTML, exp: "//li[position() mod 2 = 0 ]", expected: 2}, # //li[2],li[4]
        {root: HTML, exp: "//a[@id>=1]", expected: 3},                 #  //a[@id>=1] == a[1],a[2],a[3]
        {root: HTML, exp: "//a[@id<=2]", expected: 2},                 # //a[@id<=2] == a[1],a[1]
        {root: HTML, exp: "//a[@id<2]", expected: 1},                  # //a[@id>=1] == a[1]
        {root: HTML, exp: "//a[@id!=2]", expected: 2},                 # //a[@id>=1] == a[1],a[3]
        {root: HTML, exp: "//a[@id=1 or @id=3]", expected: 2},         # //a[@id>=1] == a[1],a[3]
      ]

      tests.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_node(t[:root], t[:exp])
        fail "XPath expression `#{t[:exp]}` returned node is nil" if n.nil?
        t[:expected].should eq(n)
      end

      test_nodes.each do |t|
        puts "Testing expression: #{t[:exp]}"
        n = select_nodes(t[:root], t[:exp])
        fail "expected nodes is #{t[:expected]} but got #{n.size}" unless n.size == t[:expected]
      end
    end
  end
end
