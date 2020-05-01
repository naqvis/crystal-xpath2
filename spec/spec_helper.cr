require "spec"
require "../src/xpath2"

module XPath2
  HTML  = example()
  HTML2 = example2()

  def self.select_node(root : TNode, str)
    nav = TNodeNavigator.new(root, root)
    expr = compile(str)
    n = expr.select(nav)
    if n.move_next
      return n.current.as(TNodeNavigator).curr.not_nil!
    end
    nil
  end

  def self.select_nodes(root : TNode, str)
    nav = TNodeNavigator.new(root, root)
    expr = compile(str)
    t = expr.select(nav)
    arr = Array(TNode).new
    while t.move_next
      arr << t.current.as(TNodeNavigator).curr.not_nil!
    end
    arr
  end

  def self.do_eval(root : TNode, str)
    nav = TNodeNavigator.new(root, root)
    expr = compile(str)
    v = expr.evaluate(nav)
    v
    # nodes = Array(TNodeNavigator).new
    # if (iter = v.as?(NodeIterator))
    #   while iter.move_next
    #     nodes << iter.current.as(TNodeNavigator)
    #   end
    # end
    # nodes
  end

  def self.do_evals(root : TNode, exp, expected)
    nav = TNodeNavigator.new(root, root)
    expr = compile(exp)
    v = expr.evaluate(nav)
    if (iter = v.as?(NodeIterator))
      nodes = Array(TNodeNavigator).new
      while iter.move_next
        nodes << iter.current.as(TNodeNavigator)
      end

      fail "expected value, got #{expected}" unless expected.is_a?(Array(String))
      fail "expected size : #{expected.size}, got : #{nodes.size}" unless nodes.size == expected.size

      expected.each_with_index do |e, i|
        nodes[i].value.should eq(e)
      end
      return
    end

    v.should eq(expected)
  end

  record Attribute, key : String, value : String

  class TNode
    property parent : TNode?
    property first_child : TNode?
    property last_child : TNode?
    property prev_sibling : TNode?
    property next_sibling : TNode?

    property type : NodeType
    property data : String
    property attr : Array(Attribute)

    def initialize(@data = "", @type = NodeType::Root)
      @attr = Array(Attribute).new
    end

    def value
      return data if type == NodeType::Text
      io = IO::Memory.new
      output(io, self)
      io.to_s
    end

    private def output(io : IO, node : TNode)
      io << node.data if node.type == NodeType::Text
      child = node.first_child
      while child
        output(io, child)
        child = child.next_sibling
      end
    end

    def create_child_node(data, typ)
      m = TNode.new(data, typ)
      m.parent = self
      if @first_child.nil?
        @first_child = m
      else
        @last_child.not_nil!.next_sibling = m
        m.prev_sibling = @last_child
      end
      @last_child = m
      m
    end

    def append_node(data, typ)
      m = TNode.new(data, typ)
      m.parent = @parent
      @next_sibling = m
      m.prev_sibling = self
      if (p = @parent)
        p.last_child = m
      end
      m
    end

    def add_attribute(k, v)
      @attr << Attribute.new(k, v)
    end
  end

  class TNodeNavigator
    include NodeNavigator
    property curr : TNode
    property root : TNode
    property attr : Int32

    def initialize(@curr, @root)
      @attr = -1
    end

    def node_type : NodeType
      return NodeType::Attribute if @curr.type == NodeType::Element && @attr != -1
      @curr.type
    end

    def local_name : String
      return @curr.attr[@attr].key unless @attr == -1
      @curr.data
    end

    def prefix : String
      ""
    end

    def value : String
      case @curr.type
      when .text?, .comment?
        @curr.data
      when .element?
        return @curr.attr[@attr].value unless @attr == -1
        String.build do |sb|
          nod = @curr.first_child
          while nod
            sb << nod.data.strip if nod.type == NodeType::Text
            nod = nod.next_sibling
          end
        end
      else
        ""
      end
    end

    def copy : NodeNavigator
      n2 = TNodeNavigator.new(@curr, @root)
      n2.attr = @attr.dup
      n2
    end

    def move_to_root
      @curr = @root
    end

    def move_to_parent
      if (node = @curr.parent)
        @curr = node
        return true
      end
      false
    end

    def move_to_next_attribute : Bool
      if (cur = @curr)
        return false if @attr >= cur.attr.size - 1
      end
      @attr += 1
      true
    end

    def move_to_child : Bool
      if (node = @curr.first_child)
        @curr = node
        return true
      end
      false
    end

    def move_to_first : Bool
      return false if @curr.prev_sibling.nil?
      node = @curr.prev_sibling
      while node
        @curr = node
        node = @curr.prev_sibling
      end
      true
    end

    def move_to_next : Bool
      if (node = @curr.next_sibling)
        @curr = node
        return true
      end
      false
    end

    def move_to_previous : Bool
      if (node = @curr.prev_sibling)
        @curr = node
        return true
      end
      false
    end

    def move_to(nav : NodeNavigator) : Bool
      if (node = nav.as?(TNodeNavigator)) && (node.root == @root)
        @curr = node.curr
        @attr = node.attr
        true
      else
        false
      end
    end
  end

  def self.example
    html = <<-EOF
        <html lang="en">
          <head>
            <title>Hello</title>
            <meta name="language" content="en"/>
          </head>
          <body>
            <h1>
            This is a H1
            </h1>
            <ul>
              <li><a id="1" href="/">Home</a></li>
              <li><a id="2" href="/about">about</a></li>
              <li><a id="3" href="/account">login</a></li>
              <li></li>
            </ul>
            <p>
              Hello,This is an example for crystal xpath.
            </p>
            <footer>footer script</footer>
          </body>
        </html>
 EOF
    doc = TNode.new
    xhtml = doc.create_child_node("html", NodeType::Element)
    xhtml.add_attribute("lang", "en")

    # HTML head section
    head = xhtml.create_child_node("head", NodeType::Element)
    n = head.create_child_node("title", NodeType::Element)
    n = n.create_child_node("Hello", NodeType::Text)
    n = head.create_child_node("meta", NodeType::Element)
    n.add_attribute("name", "language")
    n.add_attribute("content", "en")

    # HTML body section
    body = xhtml.create_child_node("body", NodeType::Element)
    n = body.create_child_node("h1", NodeType::Element)
    n = n.create_child_node("\nThis is a H1\n", NodeType::Text)
    ul = body.create_child_node("ul", NodeType::Element)
    n = ul.create_child_node("li", NodeType::Element)
    n = n.create_child_node("a", NodeType::Element)
    n.add_attribute("id", "1")
    n.add_attribute("href", "/")
    n = n.create_child_node("Home", NodeType::Text)

    n = ul.create_child_node("li", NodeType::Element)
    n = n.create_child_node("a", NodeType::Element)
    n.add_attribute("id", "2")
    n.add_attribute("href", "/about")
    n = n.create_child_node("about", NodeType::Text)

    n = ul.create_child_node("li", NodeType::Element)
    n = n.create_child_node("a", NodeType::Element)
    n.add_attribute("id", "3")
    n.add_attribute("href", "/account")
    n = n.create_child_node("login", NodeType::Text)
    n = ul.create_child_node("li", NodeType::Element)

    n = body.create_child_node("p", NodeType::Element)
    n = n.create_child_node("Hello,This is an example for crystal xpath.", NodeType::Text)

    n = body.create_child_node("footer", NodeType::Element)
    n = n.create_child_node("footer script", NodeType::Text)

    xhtml
  end

  def self.example2
    html = <<-EOF
    <html lang="en">
    <head>
      <title>Hello</title>
      <meta name="language" content="en"/>
    </head>
    <body>
    <h1> This is a H1 </h1>
    <table>
      <tbody>
        <tr>
          <td>row1-val1</td>
          <td>row1-val2</td>
          <td>row1-val3</td>
        </tr>
        <tr>
          <td><para>row2-val1</para></td>
          <td><para>row2-val2</para></td>
          <td><para>row2-val3</para></td>
        </tr>
        <tr>
          <td>row3-val1</td>
          <td><para>row3-val2</para></td>
          <td>row3-val3</td>
        </tr>
      </tbody>
    </table>
    </body>
  </html>
  EOF

    doc = TNode.new
    xhtml = doc.create_child_node("html", NodeType::Element)
    xhtml.add_attribute("lang", "en")

    # HTML head section
    head = xhtml.create_child_node("head", NodeType::Element)
    n = head.create_child_node("title", NodeType::Element)
    n = n.create_child_node("Hello", NodeType::Text)
    n = head.create_child_node("meta", NodeType::Element)
    n.add_attribute("name", "language")
    n.add_attribute("content", "en")

    # HTML body section
    body = xhtml.create_child_node("body", NodeType::Element)
    n = body.create_child_node("h1", NodeType::Element)
    n = n.create_child_node(" This is a H1 ", NodeType::Text)

    n = body.create_child_node("table", NodeType::Element)
    tbody = n.create_child_node("tbody", NodeType::Element)
    n = tbody.create_child_node("tr", NodeType::Element)
    n.create_child_node("td", NodeType::Element).create_child_node("row1-val1", NodeType::Text)
    n.create_child_node("td", NodeType::Element).create_child_node("row1-val2", NodeType::Text)
    n.create_child_node("td", NodeType::Element).create_child_node("row1-val3", NodeType::Text)
    n = tbody.create_child_node("tr", NodeType::Element)
    n.create_child_node("td", NodeType::Element).create_child_node("para", NodeType::Text).create_child_node("row2-val1", NodeType::Text)
    n.create_child_node("td", NodeType::Element).create_child_node("para", NodeType::Text).create_child_node("row2-val2", NodeType::Text)
    n.create_child_node("td", NodeType::Element).create_child_node("para", NodeType::Text).create_child_node("row2-val3", NodeType::Text)
    n = tbody.create_child_node("tr", NodeType::Element)
    n.create_child_node("td", NodeType::Element).create_child_node("row3-val1", NodeType::Text)
    n.create_child_node("td", NodeType::Element).create_child_node("para", NodeType::Text).create_child_node("row3-val2", NodeType::Text)
    n.create_child_node("td", NodeType::Element).create_child_node("row3-val3", NodeType::Text)

    xhtml
  end
end
