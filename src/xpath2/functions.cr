module XPath2
  extend self

  # XPath2 function list
  private class Builder
    # XPath node set functions position().
    private def position(q, t)
      count = 1
      node = t.current
      while node.move_to_previous
        count += 1 if q.test(node)
      end

      count.to_f64
    end

    # last is an XPath Node Set function last()
    private def last(q, t)
      count = 0
      node = t.current
      node.move_to_first
      loop do
        count += 1 if q.test(node)
        break unless node.move_to_next
      end
      count.to_f64
    end

    # count is XPath Node set functions count(node-set)
    private def count(q : Query, t : QueryIterator)
      count = 0
      type = q.evaluate(t)

      if type.is_a?(Query)
        node = type.select(t)
        while node
          count += 1 if q.test(node)
          node = type.select(t)
        end
      end
      count.to_f64
    end

    # sum is XPath node set functions sum(node-set)
    private def sum(q, t)
      sum = 0_f64
      typ = q.evaluate(t)
      case typ
      when Query
        node = typ.select(t)
        while node
          if (v = node.value.to_f?)
            sum += v
          end
          node = typ.select(t)
        end
      when Float64
        sum = typ
      when String
        if (v = typ.to_f?)
          sum = v
        else
          raise XPath2Exception.new("sum() function argument type must be a node-set or number")
        end
      else
        #
      end
      sum
    end

    private def as_number(t, o)
      case o
      when Query
        if (node = o.select(t))
          if (v = node.value.to_f?)
            v
          else
            0_f64
          end
        else
          0_f64
        end
      when Float64
        o.as(Float64)
      when String
        if (v = o.as(String).to_f?)
          v
        else
          raise XPath2Exception.new("sum() function argument type must be a node-set or number")
        end
      else
        0_f64
      end
    end

    private def ceiling(q, t)
      val = as_number(t, q.evaluate(t))
      val.ceil
    end

    private def floor(q, t)
      val = as_number(t, q.evaluate(t))
      val.floor
    end

    private def round(q, t)
      val = as_number(t, q.evaluate(t))
      val.round
    end

    private def name(arg)
      XPathFunc.new do |_, t|
        if arg.nil?
          v = t.current
        else
          v = arg.not_nil!.select(t)
          next "" if v.nil?
        end
        ns = v.prefix
        next v.local_name if ns.empty?
        "#{ns}:#{v.local_name}"
      end
    end

    private def local_name(arg)
      XPathFunc.new do |_, t|
        if arg.nil?
          v = t.current
        else
          v = arg.not_nil!.select(t)
          next "" if v.nil?
        end
        v.local_name
      end
    end

    private def namespace(arg)
      XPathFunc.new do |_, t|
        if arg.nil?
          v = t.current
        else
          # Get the first node in the node-set if specified
          v = arg.not_nil!.select(t)
          next "" if v.nil?
        end
        if v.responds_to?(:namespace_url)
          v.namespace_url
        else
          v.prefix
        end
      end
    end

    private def as_string(t, v)
      case v
      when Nil
        ""
      when Bool
        v.as(Bool) ? "true" : "false"
      when Float64
        "%g" % v.as(Float64)
      when String
        v.as(String)
      when Query
        if (node = v.select(t))
          node.value
        else
          ""
        end
      else
        raise XPath2Exception.new("unexpected type: #{typeof(v)}")
      end
    end

    private def boolean(q, t)
      v = q.evaluate(t)
      XPath2.as_bool(t, v)
    end

    private def number(q, t)
      v = q.evaluate(t)
      as_number(t, v)
    end

    private def string(q, t)
      v = q.evaluate(t)
      as_string(t, v)
    end

    private def start_with(arg1, arg2)
      XPathFunc.new do |_, t|
        m = ""
        typ = function_args(arg1).evaluate(t)
        case typ
        when String
          m = typ.as(String)
        when Query
          if (node = typ.select(t))
            m = node.value
          else
            next false
          end
        else
          raise XPath2Exception.new("starts-with() function argument type must be string")
        end
        n = function_args(arg2).evaluate(t).as?(String)
        if n.nil?
          raise XPath2Exception.new("starts-with() function argument type must be string")
        else
          m.starts_with?(n)
        end
      end
    end

    private def end_with(arg1, arg2)
      XPathFunc.new do |_, t|
        m = ""
        typ = function_args(arg1).evaluate(t)
        case typ
        when String
          m = typ.as(String)
        when Query
          if (node = typ.select(t))
            m = node.value
          else
            next false
          end
        else
          raise XPath2Exception.new("ends-with() function argument type must be string")
        end
        n = function_args(arg2).evaluate(t).as?(String)
        if n.nil?
          raise XPath2Exception.new("ends-with() function argument type must be string")
        else
          m.ends_with?(n)
        end
      end
    end

    private def contains(arg1, arg2)
      XPathFunc.new do |_, t|
        m = ""
        typ = function_args(arg1).evaluate(t)
        case typ
        when String
          m = typ.as(String)
        when Query
          if (node = typ.select(t))
            m = node.value
          else
            next false
          end
        else
          raise XPath2Exception.new("contains() function argument type must be string")
        end
        n = function_args(arg2).evaluate(t).as?(String)
        if n.nil?
          raise XPath2Exception.new("contains() function argument type must be string")
        else
          m.includes?(n)
        end
      end
    end

    private def normalizespace(q, t)
      m = ""
      typ = q.evaluate(t)
      case typ
      when String
        m = typ.as(String)
      when Query
        if (node = typ.select(t))
          m = node.value
        else
          return ""
        end
      else
        #
      end
      m = m.strip
      m = m.gsub(/[\r\n\t]/, " ")
      m = m.gsub(/\s{2,}/, " ")
      m
    end

    private def substring(arg1, arg2, arg3)
      XPathFunc.new do |_, t|
        m = ""
        typ = function_args(arg1).evaluate(t)
        case typ
        when String
          m = typ.as(String)
        when Query
          if (node = typ.select(t))
            m = node.value
          else
            next ""
          end
        else
          #
        end
        if (start = function_args(arg2).evaluate(t).as?(Float64))
          raise XPath2Exception.new("substring() function first argument must be >= 1") if start < 1
          start -= 1
          unless arg3.nil?
            if (len = function_args(arg3).evaluate(t).as?(Float64))
              if m.size - start.to_i < len.to_i
                raise XPath2Exception.new("substring() function start and length argument out of range")
              end
              next m[start.to_i...(len + start).to_i] if len > 0
            else
              raise XPath2Exception.new("substring() function second argument type must be int")
            end
          end
          m[start.to_i..]
        else
          raise XPath2Exception.new("substring() function first argument type must be int")
        end
      end
    end

    # substring_ind is XPath functions substring-before/substring-after function returns a part of a given string.
    private def substring_ind(arg1, arg2, after)
      XPathFunc.new do |_, t|
        str = ""
        v = function_args(arg1).evaluate(t)
        case v
        when String
          str = v
        when Query
          if (node = v.select(t))
            str = node.value
          else
            next ""
          end
        else
          #
        end
        word = ""
        v = function_args(arg2).evaluate(t)
        case v
        when String
          word = v
        when Query
          if (node = v.select(t))
            word = node.value
          else
            next ""
          end
        else
          #
        end
        next "" if word.empty?
        if (i = str.index(word))
          next str[i + word.size..] if after
          str[...i]
        else
          ""
        end
      end
    end

    # string_length is XPATH string-length( [string] ) function that returns a number
    # equal to the number of characters in a given string.
    private def string_length(arg1)
      XPathFunc.new do |_, t|
        v = function_args(arg1).evaluate(t)
        case v
        when String
          v.as(String).size.to_f64
        when Query
          if (node = v.select(t))
            node.value.size.to_f64
          else
            0_f64
          end
        else
          0_f64
        end
      end
    end

    # translate is XPath functions translate() function returns a replaced string.
    private def translate(arg1, arg2, arg3)
      XPathFunc.new do |_, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        src = as_string(t, function_args(arg2).evaluate(t))
        dst = as_string(t, function_args(arg3).evaluate(t))

        replace = Hash(Char, Char).new
        src.each_char_with_index do |s, i|
          d = Char::ZERO
          d = dst[i] if i < dst.size
          replace[s] = d
        end

        String.build do |sb|
          str.each_char do |c|
            if (r = replace[c]?)
              next if r == Char::ZERO
              sb << r
            else
              sb << c
            end
          end
        end
      end
    end

    # replace is XPath functions replace() function returns a replaced string
    private def replace(arg1, arg2, arg3)
      XPathFunc.new do |_, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        src = as_string(t, function_args(arg2).evaluate(t))
        dst = as_string(t, function_args(arg3).evaluate(t))

        str.gsub(src, dst)
      end
    end

    # not is XPATH functions not(expression) function operation.
    private def not(q, t)
      v = q.evaluate(t)
      case v
      when Bool
        !v.as(Bool)
      when Query
        a = v.select(t)
        a.nil?
      else
        false
      end
    end

    # concatenates two or more strings
    private def concat(args)
      XPathFunc.new do |_, t|
        a = Array(String).new
        args.each do |v|
          v = function_args(v).evaluate(t)
          case v
          when String
            a << v
          when Query
            if (node = v.select(t))
              a << node.value
            end
          else
            #
          end
        end
        a.join("")
      end
    end

    private def function_args(q)
      if (v = q.as?(FunctionQuery))
        return v
      end
      q.not_nil!.clone
    end

    private def reverse(q, t)
      list = Array(NodeNavigator).new
      loop do
        if (node = q.select(t))
          list << node.copy
        else
          break
        end
      end
      i = list.size
      IteratorFunc.new {
        next nil if i <= 0
        i -= 1
        node = list[i]
        node
      }
    end
  end

  protected def self.as_bool(t, v)
    case v
    when Nil
      false
    when NodeIterator
      v.move_next
    when Bool
      v.as(Bool)
    when Float64
      v.as(Float64) != 0.0
    when String
      !v.as(String).empty?
    when Query
      !v.select(t).nil?
    else
      raise XPath2Exception.new("unexpected type: #{typeof(v)}")
    end
  end
end
