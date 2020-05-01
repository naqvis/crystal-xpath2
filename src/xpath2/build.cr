module XPath2
  private enum Flag
    None   = 0
    Filter
  end

  # Builder provides building an XPath expression.
  private class Builder
    @depth : Int32
    @flag : Flag
    @first_input : Query

    def initialize(@depth = 0, @flag = Flag::None, @first_input = NoopQuery.new)
    end

    # build builds a specified XPath expression expr
    def self.build(expr : String)
      root = Parser.parse(expr)
      b = Builder.new
      b.process_node(root)
    end

    # processes a query for the XPath axis node
    private def process_axis_node(root : AxisNode)
      a_predicate = XPath2.axis_predicate(root)
      if root.input.nil?
        qy_input = ContextQuery.new
      else
        if root.axe_type == "child" && (root.input.try &.type == ParserNodeType::Axis)
          if (input = root.input.as?(AxisNode)) && (input.axe_type == "descendant-or-self")
            qy_grand_input = input.input.nil? ? ContextQuery.new : process_node(input.input)

            filter = Predicate.new { |n|
              v = a_predicate.call(n)
              case root.prop
              when "text"
                v = v && n.try &.node_type == NodeType::Text
              when "comment"
                v = v && n.try &.node_type == NodeType::Comment
              else
                v
              end
            }
            return DescendantQuery.new(input: qy_grand_input, predicate: filter, self_: true)
          end
        end
        qy_input = process_node(root.input)
      end
      case root.axe_type
      when "ancestor"
        AncestorQuery.new(input: qy_input, predicate: a_predicate)
      when "ancestor-or-self"
        AncestorQuery.new(input: qy_input, predicate: a_predicate, self_: true)
      when "attribute"
        AttributeQuery.new(qy_input, a_predicate)
      when "child"
        filter = Predicate.new { |n|
          v = a_predicate.call(n)
          case root.prop
          when "text"
            v = v && n.try &.node_type == NodeType::Text
          when "comment"
            v = v && n.try &.node_type == NodeType::Comment
          else
            v
          end
          v
        }
        ChildQuery.new(qy_input, filter)
      when "descendant"
        DescendantQuery.new(qy_input, a_predicate)
      when "descendant-or-self"
        DescendantQuery.new(qy_input, a_predicate, self_: true)
      when "following"
        FollowingQuery.new(qy_input, a_predicate)
      when "following-sibling"
        FollowingQuery.new(qy_input, a_predicate, sibling: true)
      when "parent"
        ParentQuery.new(qy_input, a_predicate)
      when "preceding"
        PrecedingQuery.new(qy_input, a_predicate)
      when "preceding-sibling"
        PrecedingQuery.new(qy_input, a_predicate, sibling: true)
      when "self"
        SelfQuery.new(qy_input, a_predicate)
      when "namespace"
        raise XPath2Exception.new("namespace Axe type not supported.")
      else
        raise XPath2Exception.new("unknown Axe type: #{root.axe_type}")
      end
    end

    # process_filter_node builds query for the XPath filter predicate
    private def process_filter_node(root : FilterNode)
      @flag |= Flag::Filter

      qy_input = process_node(root.input)
      qy_cond = process_node(root.condition)
      FilterQuery.new(input: qy_input, predicate: qy_cond)
    end

    # process_function_node process query for the XPath function node
    private def process_function_node(root : FunctionNode)
      case root.funcname
      when "starts-with"
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        FunctionQuery.new(input: @first_input, func: start_with(arg1, arg2))
      when "ends-with"
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        FunctionQuery.new(input: @first_input, func: end_with(arg1, arg2))
      when "contains"
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        FunctionQuery.new(input: @first_input, func: contains(arg1, arg2))
      when "substring"
        raise XPath2Exception.new("substring function must have at least two parameters") if root.args.size < 2
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        arg3 = process_node(root.args[2]) if root.args.size == 3
        FunctionQuery.new(input: @first_input, func: substring(arg1, arg2, arg3))
      when "substring-before", "substring-after"
        raise XPath2Exception.new("substring-before/after function must have at two parameters") if root.args.size < 2
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        FunctionQuery.new(input: @first_input, func: substring_ind(arg1, arg2, root.funcname == "substring-after"))
      when "string-length"
        raise XPath2Exception.new("string-length function must have at least one parameter") if root.args.size == 0
        arg1 = process_node(root.args[0])
        FunctionQuery.new(input: @first_input, func: string_length(arg1))
      when "normalize-space"
        raise XPath2Exception.new("normalize-space function must have at least one parameter") if root.args.size == 0
        arg1 = process_node(root.args[0])
        FunctionQuery.new(input: arg1, func: XPathFunc.new { |q, t| normalizespace(q, t) })
      when "replace"
        raise XPath2Exception.new("replace function must have three parameters") unless root.args.size == 3
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        arg3 = process_node(root.args[2])
        FunctionQuery.new(input: @first_input, func: replace(arg1, arg2, arg3))
      when "translate"
        raise XPath2Exception.new("translate function must have three parameters") unless root.args.size == 3
        arg1 = process_node(root.args[0])
        arg2 = process_node(root.args[1])
        arg3 = process_node(root.args[2])
        FunctionQuery.new(input: @first_input, func: translate(arg1, arg2, arg3))
      when "not"
        raise XPath2Exception.new("not function must have at least one parameter") if root.args.size == 0
        arg1 = process_node(root.args[0])
        FunctionQuery.new(input: arg1, func: XPathFunc.new { |q, t| not(q, t) })
      when "name", "local-name", "namespace-uri"
        raise XPath2Exception.new("#{root.funcname} function must have at most one parameter") if root.args.size > 1
        arg1 = root.args.size == 1 ? process_node(root.args[0]) : nil
        funcs = {
          "name"          => ->name(Query?),
          "local-name"    => ->local_name(Query?),
          "namespace-uri" => ->namespace(Query?),
        }
        FunctionQuery.new(input: @first_input, func: funcs[root.funcname].call(arg1))
      when "true", "false"
        val = root.funcname == "true"
        FunctionQuery.new(input: @first_input, func: XPathFunc.new { |_, _| val })
      when "last"
        FunctionQuery.new(input: @first_input, func: XPathFunc.new { |q, t| last(q, t) })
      when "position"
        FunctionQuery.new(input: @first_input, func: XPathFunc.new { |q, t| position(q, t) })
      when "boolean", "number", "string"
        inp = @first_input
        raise XPath2Exception.new("#{root.funcname} function must have at most one parameter") if root.args.size > 1
        inp = process_node(root.args[0]) if root.args.size == 1
        funcs = {
          "boolean" => XPathFunc.new { |q, t| boolean(q, t) },
          "string"  => XPathFunc.new { |q, t| string(q, t) },
          "number"  => XPathFunc.new { |q, t| number(q, t) },
        }
        FunctionQuery.new(input: inp, func: funcs[root.funcname])
      when "count"
        raise XPath2Exception.new("count(node-sets) function must have parameters node-set") if root.args.size == 0
        arg = process_node(root.args[0])
        FunctionQuery.new(input: arg, func: XPathFunc.new { |q, t| count(q, t) })
      when "sum"
        raise XPath2Exception.new("sum(node-sets) function must have parameters node-set") if root.args.size == 0
        arg = process_node(root.args[0])
        FunctionQuery.new(input: arg, func: XPathFunc.new { |q, t| sum(q, t) })
      when "ceiling", "floor", "round"
        raise XPath2Exception.new("#{root.funcname}(node-sets) function must have parameter node-set") if root.args.size == 0
        arg1 = process_node(root.args[0])
        funcs = {
          "ceiling" => XPathFunc.new { |q, t| ceiling(q, t) },
          "floor"   => XPathFunc.new { |q, t| floor(q, t) },
          "round"   => XPathFunc.new { |q, t| round(q, t) },
        }
        FunctionQuery.new(input: arg1, func: funcs[root.funcname])
      when "concat"
        raise XPath2Exception.new("concat() must have at least two arguments") if root.args.size < 2
        args = Array(Query).new
        root.args.each do |v|
          args << process_node(v)
        end
        FunctionQuery.new(input: @first_input, func: concat(args))
      when "reverse"
        raise XPath2Exception.new("#{root.funcname}(node-sets) function must have parameter node-set") if root.args.size == 0
        arg = process_node(root.args[0])
        TransformFunctionQuery.new(input: arg, func: XPathXFunc.new { |q, t| reverse(q, t) })
      else
        raise XPath2Exception.new("#{root.funcname} not supported.")
      end
    end

    private def process_operator_node(root : OperatorNode)
      left = process_node(root.left)
      right = process_node(root.right)
      case root.op
      when "+", "-", "div", "mod" # Numeric operator
        funcs = {
          "+"   => NumericFunc.new { |a, b| plus(a, b) },
          "-"   => NumericFunc.new { |a, b| minus(a, b) },
          "div" => NumericFunc.new { |a, b| div(a, b) },
          "mod" => NumericFunc.new { |a, b| mod(a, b) },
        }
        NumericQuery.new(left: left, right: right, func: funcs[root.op])
      when "=", ">", ">=", "<", "<=", "!=" # equality operators
        funcs = {
          "="  => LogicalFunc.new { |t, a, b| eq(t, a, b) },
          ">"  => LogicalFunc.new { |t, a, b| gt(t, a, b) },
          ">=" => LogicalFunc.new { |t, a, b| ge(t, a, b) },
          "<"  => LogicalFunc.new { |t, a, b| lt(t, a, b) },
          "<=" => LogicalFunc.new { |t, a, b| le(t, a, b) },
          "!=" => LogicalFunc.new { |t, a, b| ne(t, a, b) },
        }
        LogicalQuery.new(left: left, right: right, func: funcs[root.op])
      when "or", "and"
        BooleanQuery.new(left: left, right: right, is_or: root.op == "or")
      when "|"
        UnionQuery.new(left: left, right: right)
      else
        raise XPath2Exception.new("operator #{root.op} not supported")
      end
    end

    protected def process_node(root_node)
      @depth = @depth + 1
      raise XPath2Exception.new("XPath expression too complex") if @depth > 1024
      if (root = root_node)
        case root.type
        when .constant_operand?
          ConstantQuery.new(root.as(OperandNode).val)
        when .root?
          ContextQuery.new(root: true)
        when .axis?
          @first_input = process_axis_node(root.as(AxisNode))
          @first_input
        when .filter?
          process_filter_node(root.as(FilterNode))
        when .function?
          process_function_node(root.as(FunctionNode))
        when .operator?
          process_operator_node(root.as(OperatorNode))
        else
          raise XPath2Exception.new("Unsupported XPath node type : #{root.type}")
        end
      else
        raise XPath2Exception.new("Nil root_node passed to process_node function")
      end
    end
  end

  protected def axis_predicate(root : AxisNode)
    # get current axis node type
    typ = case root.axe_type
          when "attribute"
            NodeType::Attribute
          when "self", "parent"
            NodeType::Any
          else
            case root.prop
            when "comment"
              NodeType::Comment
            when "text"
              NodeType::Text
            when "node"
              NodeType::Any
            else
              NodeType::Element
            end
          end
    nametest = !root.local_name.empty? || !root.prefix.empty?
    Predicate.new { |n|
      if typ == n.try &.node_type || typ == NodeType::Any || typ == NodeType::Text
        if nametest
          return true if root.local_name == n.try &.local_name && root.prefix == n.try &.prefix
        else
          return true
        end
      end
      false
    }
  end
end
