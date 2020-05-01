module XPath2
  private class Builder
    enum OpValueType
      Boolean = 0
      Number
      String
      NodeSet
    end

    OP_MAP = {
      "eq" => "=",
      "gt" => ">",
      "ge" => ">=",
      "lt" => "<",
      "le" => "<=",
      "ne" => "!=",
    }

    {% for m in %w(eq gt ge lt le ne) %}
    def {{m.id}}(t,m,n)
      op = OP_MAP[{{m.id.stringify}}]
      compare(t,op,m,n)
    end
    {% end %}

    def compare(t : QueryIterator, op : String, m : Float64, n : Float64) : Bool
      compare(op, m, n)
    end

    def compare(t : QueryIterator, op : String, m : Float64, n : String) : Bool
      b = n.to_f?
      raise XPath2Exception.new("Unable to parse string '#{n}' to number") unless b
      compare(op, m, b.not_nil!)
    end

    def compare(t : QueryIterator, op : String, m : Float64, n : Query) : Bool
      loop do
        if (node = n.select(t))
          b = node.value.to_f?
          raise XPath2Exception.new("Unable to parse string '#{node.value}' to number") unless b
          return true if compare(op, m, b.not_nil!)
        else
          break
        end
      end
      false
    end

    def compare(t : QueryIterator, op : String, m : Query, n : Float64) : Bool
      loop do
        if (node = m.select(t))
          b = node.value.to_f?
          raise XPath2Exception.new("Unable to parse string '#{node.value}' to number") unless b
          return true if compare(op, b.not_nil!, n)
        else
          break
        end
      end
      false
    end

    def compare(t : QueryIterator, op : String, m : Query, n : String) : Bool
      loop do
        if (node = m.select(t))
          return true if compare(op, n, node.value)
        else
          break
        end
      end
      false
    end

    def compare(t : QueryIterator, op : String, m : Query, n : Query) : Bool
      if (a = m.select(t)) && (b = n.select(t))
        compare(op, a.value, b.value)
      else
        false
      end
    end

    def compare(t : QueryIterator, op : String, m : String, n : Float64) : Bool
      b = m.to_f?
      raise XPath2Exception.new("Unable to parse string '#{m}' to number") unless b
      compare(op, b.not_nil!, n)
    end

    def compare(t : QueryIterator, op : String, m : String, n : String) : Bool
      compare(op, m, n)
    end

    def compare(t : QueryIterator, op : String, m : String, n : Query) : Bool
      loop do
        if (node = n.select(t))
          return true if compare(op, m, node.value)
        else
          break
        end
      end
      false
    end

    def compare(t : QueryIterator, op : String, m : Bool, n : Bool) : Bool
      compare(op, m, n)
    end

    def compare(t : QueryIterator, op : String, m : ExprResult, n : ExprResult) : Bool
      case m
      when Float64
        case n
        when Float64
          compare(t, op, m.as(Float64), n.as(Float64))
        when String
          compare(t, op, m.as(Float64), n.as(String))
        when Query
          compare(t, op, m.as(Float64), n.as(Query))
        else
          raise XPath2Exception.new("Invalid argument n: #{n} passed")
        end
      when String
        case n
        when Float64
          compare(t, op, m.as(String), n.as(Float64))
        when String
          compare(t, op, m.as(String), n.as(String))
        when Query
          compare(t, op, m.as(String), n.as(Query))
        else
          raise XPath2Exception.new("Invalid argument n: #{n} passed")
        end
      when Query
        case n
        when Float64
          compare(t, op, m.as(Query), n.as(Float64))
        when String
          compare(t, op, m.as(Query), n.as(String))
        when Query
          compare(t, op, m.as(Query), n.as(Query))
        else
          raise XPath2Exception.new("Invalid argument n: #{n} passed")
        end
      when Bool
        compare(t, op, m.as(Bool), n.as(Bool))
      else
        raise XPath2Exception.new("Invalid argument m: #{m} passed")
      end
    end

    def compare(op : String, a : Bool, b : Bool) : Bool
      case op
      when "or"  then a || b
      when "and" then a && b
      else
        false
      end
    end

    def compare(op : String, a, b) : Bool
      case op
      when "="  then a == b
      when ">"  then a > b
      when "<"  then a < b
      when ">=" then a >= b
      when "<=" then a <= b
      when "!=" then a != b
      else
        false
      end
    end

    def to_float(m)
      case m
      when Float64
        m.as(Float64)
      when String
        m.as(String).to_f
      else
        raise XPath2Exception.new("Expecting Number but got #{m}")
      end
    end

    def numeric_expr(m, n, cb)
      a = to_float(m)
      b = to_float(n)
      cb.call(a, b)
    end

    def plus(m, n)
      numeric_expr(m, n, ->(a : Float64, b : Float64) { a + b })
    end

    def minus(m, n)
      numeric_expr(m, n, ->(a : Float64, b : Float64) { a - b })
    end

    def mul(m, n)
      numeric_expr(m, n, ->(a : Float64, b : Float64) { a * b })
    end

    def div(m, n)
      numeric_expr(m, n, ->(a : Float64, b : Float64) { a / b })
    end

    def mod(m, n)
      numeric_expr(m, n, ->(a : Float64, b : Float64) { (a.to_i % b.to_i).to_f64 })
    end
  end
end
