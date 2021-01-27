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
