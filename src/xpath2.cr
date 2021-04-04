# XPath2 Shard provide XPath implementation in pure Crystal. Performs the compilation of XPath expression and provides mechanism to select nodes from HTML or other documents using XPath expression
module XPath2
  VERSION = "0.1.3"

  class XPath2Exception < Exception
  end

  # compile compiles an XPath expression string
  def self.compile(expr : String)
    raise XPath2Exception.new("xpath expression is blank") if expr.empty?
    if (qry = Builder.build(expr))
      return Expr.new(expr, qry)
    end
    raise XPath2Exception.new("undeclared variable in XPath expression: #{expr}")
  end

  # NodeType represents XPath node.
  enum NodeType
    Root      = 0 # Root node of the XML document or node tree.
    Element       # Element node such as <element>
    Attribute     # Attribute node, such as id='123'
    Text          # Text Node, text contents of a node
    Comment       # Comment Node, such as <!-- comments -->
    Any           # Any type of node, used by XPath module only to predicate match.
  end

  # NodeNavigator provides cursor model for navigating the XML data.
  # Documents planning to provide XPath support should implement this module
  module NodeNavigator
    # returns the XPath::NodeType of the current node
    abstract def node_type : NodeType
    # gets the name of the current node
    abstract def local_name : String
    # returns namespace prefix associated with the current node
    abstract def prefix : String
    # returns the value of the current node
    abstract def value : String
    # does a deep copy of the NodeNavigator and all of its components
    abstract def copy : NodeNavigator
    # moves the NodeNavigator to the root node of the current node
    abstract def move_to_root
    # moves the NodeNavigator to the parent node of the current node
    abstract def move_to_parent
    # moves the NodeNavigator to the next attribute on current node
    abstract def move_to_next_attribute : Bool
    # moves the NodeNavigator to the first child node of the current node
    abstract def move_to_child : Bool
    # moves the NodeNavigator to the first sibling node of the current node.
    abstract def move_to_first : Bool
    # moves the NodeNavigator to the next sibling of the current node
    abstract def move_to_next : Bool
    # moves the NodeNavigator to the previous sibling of the current node
    abstract def move_to_previous : Bool
    # moves the NodeNavigator to the same position as the specificed NodeNavigator
    abstract def move_to(nav : NodeNavigator) : Bool
  end

  private module QueryIterator
    abstract def current : NodeNavigator
  end

  # Forward declaration
  private module Query; end

  # NodeIterator holds all matched Node object
  class NodeIterator
    include QueryIterator
    @node : NodeNavigator
    @query : Query

    protected def initialize(@query, @node)
    end

    # returns current node which matched
    def current : NodeNavigator
      @node
    end

    # moves Navigator to the next match node
    def move_next
      if (n = @query.select(self))
        @node = n.copy unless @node.move_to(n)
        return true
      end
      false
    end
  end

  private alias IteratorFunc = -> NodeNavigator?
  alias ExprResult = Bool | Float64 | String | Query | NodeIterator | Nil

  # Expr is an XPath expression for Query
  class Expr
    @s : String
    @q : Query

    def initialize(@s, @q)
    end

    # evaluate returns the result of the expression.
    # result type of the expression is one of the following
    # Bool | Float64 | String | NodeIterator
    def evaluate(root : NodeNavigator) : ExprResult
      # val = @q.evaluate(IteratorFunc.new { root })
      val = @q.evaluate(IterFuncImpl.new(IteratorFunc.new { root }))
      return NodeIterator.new(@q.clone, root) if val.is_a?(Query)
      val
    end

    # select selects a node set using the specified XPath expression
    def select(root : NodeNavigator)
      NodeIterator.new(@q.clone, root)
    end

    # returns XPath expression string
    def to_s
      @s
    end

    private class IterFuncImpl
      include QueryIterator

      def initialize(@func : IteratorFunc)
      end

      def current : NodeNavigator
        @func.call.not_nil!
      end
    end
  end
end

require "./xpath2/**"
