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
              next node if @predicate.call(node)
            end
            val = nil
            while node.move_to_parent
              next unless @predicate.call(node)
              val = node
              break
            end
            val
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
              break nil unless on_attr
              break node if @predicate.call(node)
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

    def select(iter : QueryIterator) : NodeNavigator?
      loop do
        if @iterator.nil?
          @posit = 0
          xnode = @input.select(iter)
          return nil if xnode.nil?
          node = xnode.not_nil!.copy
          first = true
          @iterator = IteratorFunc.new {
            loop do
              break nil if (first && !node.move_to_child) || (!first && !node.move_to_next)
              first = false
              break node if @predicate.call(node)
            end
          }
        end
        if (t = @iterator) && (n = t.call)
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
          positstack = Array(Int32).new(8, 0) # pre-allocate small stack
          first = true
          @iterator = IteratorFunc.new {
            if first && @self_
              first = false
              if @predicate.call(node)
                @posit = 1
                positstack[0] = 1 if positstack.size > 0
                next node
              end
            end

            loop do
              if node.move_to_child
                level += 1
                if level >= positstack.size
                  positstack << 0
                else
                  positstack[level] = 0
                end
              else
                moveout = false
                loop do
                  if level == 0
                    moveout = true
                    break
                  end
                  break if node.move_to_next
                  node.move_to_parent
                  level -= 1
                end
                break nil if moveout
              end
              if @predicate.call(node)
                positstack[level] = positstack[level] + 1
                @posit = positstack[level]
                break node
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
                break nil unless node.move_to_next
                if @predicate.call(node)
                  @posit += 1
                  break node
                end
              end
            }
          else
            # Reuse a single DescendantQuery + ContextQuery, resetting via evaluate
            desc = DescendantQuery.new(
              self_: true,
              input: ContextQuery.new,
              predicate: @predicate
            )
            desc_active = false
            @iterator = IteratorFunc.new {
              loop do
                if desc_active
                  if (cnode = desc.select(iter))
                    @posit = desc.position
                    break cnode
                  end
                end
                # Move to next sibling (or parent's sibling)
                moved = false
                while !node.move_to_next
                  unless node.move_to_parent
                    moved = true
                    break
                  end
                end
                break nil if moved
                # Reset the descendant query for the new subtree
                desc.evaluate(iter)
                desc_active = true
                iter.current.move_to(node)
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
                moved = false
                while !node.move_to_previous
                  moved = true
                  break
                end
                break nil if moved
                if @predicate.call(node)
                  @posit += 1
                  break node
                end
              end
            }
          else
            # Reuse a single DescendantQuery + ContextQuery, resetting via evaluate
            desc = DescendantQuery.new(
              self_: true,
              input: ContextQuery.new,
              predicate: @predicate
            )
            desc_active = false
            @iterator = IteratorFunc.new {
              loop do
                if desc_active
                  if (cnode = desc.select(iter))
                    @posit += 1
                    break cnode
                  end
                end
                # Move to previous sibling (or parent's previous)
                moved = false
                while !node.move_to_previous
                  unless node.move_to_parent
                    moved = true
                    break
                  end
                  @posit = 0
                end
                break nil if moved
                # Reset the descendant query for the new subtree
                desc.evaluate(iter)
                desc_active = true
                iter.current.move_to(node)
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

  # VariableQuery resolves a variable reference ($name) at evaluation time
  # by looking up the variable name in the bound variables hash.
  private class VariableQuery
    include Query

    def initialize(@name : String, @bindings : Hash(String, ExprResult))
    end

    def select(iter : QueryIterator) : NodeNavigator?
      nil
    end

    def evaluate(iter : QueryIterator) : ExprResult
      if @bindings.has_key?(@name)
        @bindings[@name]
      else
        raise XPath2Exception.new("undeclared variable $#{@name}")
      end
    end

    def clone : Query
      VariableQuery.new(@name, @bindings)
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
              list << xnode.copy
            else
              break
            end
          end
          iter.current.move_to(root)
          loop do
            if (xnode = @right.select(iter))
              list << xnode.copy
            else
              break
            end
          end
        else
          # Use hash-based intersection: O(n+m) instead of O(n×m)
          left_nodes = Array(NodeNavigator).new
          left_hashes = Set(UInt64).new

          loop do
            if (xnode = @left.select(iter))
              node = xnode.copy
              left_nodes << node
              left_hashes << XPath2.get_hash_code(node.copy)
            else
              break
            end
          end
          iter.current.move_to(root)
          loop do
            if (xnode = @right.select(iter))
              node = xnode.copy
              code = XPath2.get_hash_code(node.copy)
              if left_hashes.includes?(code)
                list << node
              end
            else
              break
            end
          end
        end
        @iterator = IteratorFunc.new {
          next nil if i >= list.size
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

  # UnionQuery is an XPath Union operator expression.
  # Streams results lazily: yields from left first, then right, deduplicating on the fly.
  private class UnionQuery
    include Query

    def initialize(@left : Query, @right : Query)
      @seen = Set(UInt64).new
      @left_done = false
    end

    def select(iter : QueryIterator) : NodeNavigator?
      # Stream from left side first
      unless @left_done
        loop do
          if (node = @left.select(iter))
            code = XPath2.get_hash_code(node.copy)
            unless @seen.includes?(code)
              @seen << code
              return node.copy
            end
          else
            @left_done = true
            break
          end
        end
      end
      # Then stream from right side
      loop do
        if (node = @right.select(iter))
          code = XPath2.get_hash_code(node.copy)
          unless @seen.includes?(code)
            @seen << code
            return node.copy
          end
        else
          return nil
        end
      end
    end

    def evaluate(iter : QueryIterator) : ExprResult
      @seen = Set(UInt64).new
      @left_done = false
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
    # Incremental FNV-1a hash — avoids building an intermediate string
    hash = 14695981039346656037_u64 # FNV offset basis
    case n.node_type
    when .attribute?, .text?, .comment?
      hash = fnv_hash_str(hash, n.local_name)
      hash = fnv_hash_byte(hash, '='.ord.to_u8)
      hash = fnv_hash_str(hash, n.value)
      if n.move_to_parent
        hash = fnv_hash_str(hash, n.local_name)
      end
    when .element?
      hash = fnv_hash_str(hash, n.prefix)
      hash = fnv_hash_str(hash, n.local_name)
      d = 1
      while n.move_to_previous
        d += 1
      end
      hash = fnv_hash_byte(hash, '-'.ord.to_u8)
      hash = fnv_hash_int(hash, d)
      while n.move_to_parent
        d = 1
        while n.move_to_previous
          d += 1
        end
        hash = fnv_hash_byte(hash, '-'.ord.to_u8)
        hash = fnv_hash_int(hash, d)
      end
    else
      #
    end
    hash
  end

  private def self.fnv_hash_byte(hash : UInt64, byte : UInt8) : UInt64
    (hash ^ byte.to_u64) &* 1099511628211_u64
  end

  private def self.fnv_hash_str(hash : UInt64, s : String) : UInt64
    s.each_byte { |b| hash = fnv_hash_byte(hash, b) }
    hash
  end

  private def self.fnv_hash_int(hash : UInt64, v : Int32) : UInt64
    hash = fnv_hash_byte(hash, (v & 0xFF).to_u8)
    hash = fnv_hash_byte(hash, ((v >> 8) & 0xFF).to_u8)
    hash = fnv_hash_byte(hash, ((v >> 16) & 0xFF).to_u8)
    fnv_hash_byte(hash, ((v >> 24) & 0xFF).to_u8)
  end

  protected def self.get_node_position(q : Query) : Int32
    if q.responds_to?(:position)
      return q.position
    end
    1
  end
end
