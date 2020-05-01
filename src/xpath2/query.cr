require "fnv"

module XPath2
  # An XPath query interface
  private module Query
    # select traverse QueryIterator and return a query matched node
    abstract def select(iter : QueryIterator) : NodeNavigator?

    # evaluate evaluates query and return values of the current query
    abstract def evaluate(iter : QueryIterator) : ExprResult

    abstract def clone : Query

    abstract def test(n : NodeNavigator?) : Bool
  end

  # NoopQuery is an empty query that always return nil for any query
  private class NoopQuery
    include Query

    def select(iter : QueryIterator) : NodeNavigator?
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      nil
    end

    def clone : Query
      NoopQuery.new
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # ContextQuery returns current node on the QueryIterator object
  private class ContextQuery
    include Query

    def initialize(@count = 0, @root = false)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      if @count == 0
        @count += 1
        n = iter.current.copy
        n.move_to_root if @root
        return n
      end
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @count = 0
      self
    end

    def clone : Query
      ContextQuery.new(0, @root)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  alias Predicate = NodeNavigator? -> Bool

  # AncestorQuery is an XPath ancestor node query. (ancestor::*|ancestor-self::*)
  private class AncestorQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate, @self_ : Bool = false)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          xnode = @input.select(iter)
          return nil if xnode.nil?
          node = xnode.not_nil!
          first = true
          @iterator = IteratorFunc.new {
            if first && @self_
              first = false
              return node if @predicate.call(node)
            end
            while node.move_to_parent
              next unless @predicate.call(node)
              return node
            end
            nil
          }
        end

        if (ite = @iterator) && (cnode = ite.call)
          return cnode
        end
        @iterator = nil
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      @iterator = nil
      self
    end

    def clone : Query
      AncestorQuery.new(self_: @self_, input: @input.clone, predicate: @predicate)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # AttributeQuery is an XPath attribute node query. (@*)
  private class AttributeQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          xnode = @input.select(iter)
          return nil if xnode.nil?
          node = xnode.not_nil!.copy
          @iterator = IteratorFunc.new {
            loop do
              on_attr = node.move_to_next_attribute
              return nil unless on_attr
              return node if @predicate.call(node)
            end
          }
        end

        if (ite = @iterator) && (cnode = ite.call)
          return cnode
        end
        @iterator = nil
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      @iterator = nil
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      AttributeQuery.new(input: @input.clone, predicate: @predicate)
    end
  end

  # ChildQuery is an XPath child node query. (child::*)
  private class ChildQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate, @posit = 0)
      @iterator = nil
    end

    def select(t : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          @posit = 0
          xnode = @input.select(t)
          return nil if xnode.nil?
          node = xnode.not_nil!.copy
          first = true
          @iterator = IteratorFunc.new {
            loop do
              return nil if (first && !node.move_to_child) || (!first && !node.move_to_next)
              first = false
              return node if @predicate.call(node)
            end
          }
        end
        if (iter = @iterator) && (n = iter.call)
          @posit += 1
          return n
        end
        @iterator = nil
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      @iterator = nil
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      ChildQuery.new(input: @input.clone, predicate: @predicate)
    end

    # returns a position of current NodeNavigator
    def position
      @posit
    end
  end

  # DescendantQuery is an XPath descendant node query. (descendant::* | descendant-or-self::*)
  private class DescendantQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate, @posit = 0, @self_ = false)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          @posit = 0
          xnode = @input.select(iter)
          return nil if xnode.nil?
          node = xnode.not_nil!.copy
          level = 0
          positmap = Hash(Int32, Int32).new
          first = true
          @iterator = IteratorFunc.new {
            if first && @self_
              first = false
              if @predicate.call(node)
                @posit = 1
                positmap[level] = 1
                return node
              end
            end

            loop do
              if node.move_to_child
                level += 1
                positmap[level] = 0
              else
                loop do
                  return nil if level == 0
                  break if node.move_to_next
                  node.move_to_parent
                  level -= 1
                end
              end
              if @predicate.call(node)
                positmap[level] = positmap[level] + 1
                @posit = positmap[level]
                return node
              end
            end
          }
        end

        if (ite = @iterator) && (n = ite.call)
          return n
        end
        @iterator = nil
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      @iterator = nil
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      DescendantQuery.new(self_: @self_, input: @input.clone, predicate: @predicate)
    end

    # returns a position of current NodeNavigator
    def position
      @posit
    end
  end

  # FollowingQuery is an XPath following node query. (following::*|following-sibling::*)
  private class FollowingQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate, @posit = 0, @sibling = false)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          @posit = 0
          xnode = @input.select(iter)
          return nil if xnode.nil?
          node = xnode.not_nil!.copy
          if @sibling
            @iterator = IteratorFunc.new {
              loop do
                return nil unless node.move_to_next
                if @predicate.call(node)
                  @posit += 1
                  return node
                end
              end
            }
          else
            q : DescendantQuery? = nil
            @iterator = IteratorFunc.new {
              loop do
                if q.nil?
                  while !node.move_to_next
                    return nil unless node.move_to_parent
                  end
                  q = DescendantQuery.new(
                    self_: true,
                    input: ContextQuery.new,
                    predicate: @predicate
                  )
                  iter.current.move_to(node)
                end
                if (cnode = q.not_nil!.select(iter))
                  @posit = q.not_nil!.position
                  return cnode
                end
                q = nil
              end
            }
          end
        end

        if (ite = @iterator) && (anode = ite.call)
          return anode
        end
        @iterator = nil
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      FollowingQuery.new(input: @input.clone, sibling: @sibling, predicate: @predicate)
    end

    # returns a position of current NodeNavigator
    def position
      @posit
    end
  end

  # PrecedingQuery is an XPath preceding node query. (preceding::*)
  private class PrecedingQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate, @posit = 0, @sibling = false)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          @posit = 0
          xnode = @input.select(iter)
          return nil if xnode.nil?
          node = xnode.not_nil!.copy
          if @sibling
            @iterator = IteratorFunc.new {
              loop do
                while !node.move_to_previous
                  return nil
                end

                if @predicate.call(node)
                  @posit += 1
                  return node
                end
              end
            }
          else
            q : Query? = nil
            @iterator = IteratorFunc.new {
              loop do
                if q.nil?
                  while !node.move_to_previous
                    return nil unless node.move_to_parent
                    @posit = 0
                  end
                  q = DescendantQuery.new(
                    self_: true,
                    input: ContextQuery.new,
                    predicate: @predicate
                  )
                  iter.current.move_to(node)
                end
                if (cnode = q.try &.select(iter))
                  @posit += 1
                  return cnode
                end
                q = nil
              end
            }
          end
        end

        if (itr = @iterator) && (anode = itr.call)
          return anode
        end
        @iterator = nil
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      PrecedingQuery.new(input: @input.clone, sibling: @sibling, predicate: @predicate)
    end

    # returns a position of current NodeNavigator
    def position
      @posit
    end
  end

  # ParentQuery is an XPath parent node query.(parent::*)
  private class ParentQuery
    include Query

    def initialize(@input : Query, @predicate : Predicate)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if (xnode = @input.select(iter))
          node = xnode.copy
          return node if node.move_to_parent && @predicate.call(node)
        else
          return nil
        end
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      ParentQuery.new(input: @input.clone, predicate: @predicate)
    end
  end

  # SelfQuery is a Self node query. (self::*)
  private class SelfQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Predicate)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if (node = @input.select(iter))
          return node if @predicate.call(node)
        else
          return nil
        end
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      self
    end

    def test(n : NodeNavigator?) : Bool
      @predicate.call(n)
    end

    def clone : Query
      SelfQuery.new(input: @input.clone, predicate: @predicate)
    end
  end

  # FilterQuery is an XPath query for predicate filter.
  private class FilterQuery
    include Query

    @iterator : IteratorFunc?

    def initialize(@input : Query, @predicate : Query, @posit = 0)
      @iterator = nil
    end

    def do(t : QueryIterator)
      val = @predicate.evaluate(t)
      case val
      when Bool
        return val.as(Bool)
      when String
        return val.as(String).size > 0
      when Float64
        pt = XPath2.get_node_position(@input)
        return (val.as(Float64)).to_i == pt
      else
        if (q = @predicate.as?(Query))
          return !q.select(t).nil?
        end
      end
      false
    end

    def position
      @posit
    end

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if (xnode = @input.select(iter))
          node = xnode.copy
          iter.current.move_to(node)
          if self.do(iter)
            @posit += 1
            return node
          end
          @posit = 0
        else
          return nil
        end
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      self
    end

    def clone : Query
      FilterQuery.new(input: @input.clone, predicate: @predicate.clone)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  private alias XPathXFunc = (Query, QueryIterator) -> IteratorFunc
  private alias XPathFunc = (Query, QueryIterator) -> ExprResult

  # FunctionQuery is an XPath function that returns a computed value for
  # the evaluate call of the current NodeNavigator node. Select call isn't
  # applicable for FunctionQuery
  private class FunctionQuery
    include Query

    def initialize(@input : Query, @func : XPathFunc)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @func.call(@input, iter)
    end

    def clone : Query
      FunctionQuery.new(input: @input.clone, func: @func)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # TransformFunctionQuery diffs from FunctionQuery where the latter computes a scalar
  # value (number,string,boolean) for the current NodeNavigator node while the former
  # (TransformFunctionQuery) performs a mapping or transform of the current NodeNavigator
  # and returns a new NodeNavigator. It is used for non-scalar XPath functions such as
  # reverse(), remove(), subsequence(), unordered(), etc.
  private class TransformFunctionQuery
    include Query
    @iterator : IteratorFunc?

    def initialize(@input : Query, @func : XPathXFunc)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      @iterator = @func.call(@input, iter) if @iterator.nil?
      @iterator.not_nil!.call
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @input.evaluate(iter)
      @iterator = nil
      self
    end

    def clone : Query
      TransformFunctionQuery.new(input: @input.clone, func: @func)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # ConstantQuery is an XPath constant operand
  private class ConstantQuery
    include Query

    def initialize(@val : ExprResult)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @val
    end

    def clone : Query
      self
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  alias LogicalFunc = (QueryIterator, ExprResult, ExprResult) -> ExprResult
  alias NumericFunc = (ExprResult, ExprResult) -> ExprResult

  # LogicalQuery is an XPath logical expression
  private class LogicalQuery
    include Query

    def initialize(@left : Query, @right : Query, @func : LogicalFunc)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      # When an XPath expr is logical expression
      node = iter.current.copy
      val = evaluate(iter)
      if val.is_a?(Bool)
        if val.as(Bool) == true
          return node
        end
      end
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      m = @left.evaluate(iter)
      n = @right.evaluate(iter)
      @func.call(iter, m, n)
    end

    def clone : Query
      LogicalQuery.new(left: @left.clone, right: @right.clone, func: @func)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # NumericQuery is an XPath numeric operator expression
  private class NumericQuery
    include Query

    def initialize(@left : Query, @right : Query, @func : NumericFunc)
    end

    def select(iter : QueryIterator) : NodeNavigator?
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      m = @left.evaluate(iter)
      n = @right.evaluate(iter)
      @func.call(m, n)
    end

    def clone : Query
      NumericQuery.new(left: @left.clone, right: @right.clone, func: @func)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # BooleanQuery is an XPath boolean operator expression
  private class BooleanQuery
    include Query
    @iterator : IteratorFunc?

    def initialize(@left : Query, @right : Query, @is_or = false)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      if @iterator.nil?
        list = Array(NodeNavigator).new
        i = 0
        root = iter.current.copy
        if @is_or
          loop do
            if (xnode = @left.select(iter))
              node = xnode.copy
              list << node
            else
              break
            end
          end
          iter.current.move_to(root)
          loop do
            if (xnode = @right.select(iter))
              node = xnode.copy
              list << node
            else
              break
            end
          end
        else
          m = Array(NodeNavigator).new
          n = Array(NodeNavigator).new

          loop do
            if (xnode = @left.select(iter))
              node = xnode.copy
              m << node
              list = m
            else
              break
            end
          end
          iter.current.move_to(root)
          loop do
            if (xnode = @right.select(iter))
              node = xnode.copy
              n << node
              list = n
            else
              break
            end
          end
          m.each do |k|
            n.each do |j|
              list << k if k == j
            end
          end
        end
        @iterator = IteratorFunc.new {
          return nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
      @iterator.not_nil!.call
    end

    def evaluate(iter : QueryIterator) : ExprResult
      m = @left.evaluate(iter)
      left = XPath2.as_bool(iter, m)
      if @is_or && left
        return true
      elsif !@is_or && !left
        return false
      end
      m = @right.evaluate(iter)
      XPath2.as_bool(iter, m)
    end

    def clone : Query
      BooleanQuery.new(is_or: @is_or, left: @left.clone, right: @right.clone)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  # UnionQuery is an XPath Union operator expression
  private class UnionQuery
    include Query
    @iterator : IteratorFunc?

    def initialize(@left : Query, @right : Query)
      @iterator = nil
    end

    def select(iter : QueryIterator) : NodeNavigator?
      if @iterator.nil?
        list = Array(NodeNavigator).new
        m = Hash(UInt64, Bool).new
        root = iter.current.copy

        loop do
          if (node = @left.select(iter))
            code = XPath2.get_hash_code(node.copy)
            unless m.has_key?(code)
              m[code] = true
              list << node.copy
            end
          else
            break
          end
        end
        iter.current.move_to(root)
        loop do
          if (node = @right.select(iter))
            code = XPath2.get_hash_code(node.copy)
            unless m.has_key?(code)
              m[code] = true
              list << node.copy
            end
          else
            break
          end
        end
        i = 0
        @iterator = IteratorFunc.new {
          return nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
      @iterator.not_nil!.call
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @iterator = nil
      @left.evaluate(iter)
      @right.evaluate(iter)
      self
    end

    def clone : Query
      UnionQuery.new(left: @left.clone, right: @right.clone)
    end

    def test(n : NodeNavigator?) : Bool
      true
    end
  end

  protected def self.get_hash_code(n : NodeNavigator)
    sb = IO::Memory.new
    case n.node_type
    when .attribute?, .text?, .comment?
      sb << "#{n.local_name}=#{n.value}"
      if n.move_to_parent
        sb << n.local_name
      end
    when .element?
      sb << "#{n.prefix}#{n.local_name}"
      d = 1
      while n.move_to_previous
        d += 1
      end
      sb << "-%d" % d
      while n.move_to_parent
        d = 1
        while n.move_to_previous
          d += 1
        end
        sb << "-%d" % d
      end
    else
      #
    end
    h = Digest::FNV64A.digest(sb.to_s)
    IO::ByteFormat::BigEndian.decode(UInt64, h)
  end

  protected def self.get_node_position(q : Query) : Int32
    if q.responds_to?(:position)
      return q.position
    end
    1
  end
end
