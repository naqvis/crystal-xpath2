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
      # Single-pass: strip leading/trailing whitespace, collapse internal whitespace to single space
      String.build(m.size) do |sb|
        in_space = true # treat start as "in space" to skip leading whitespace
        m.each_char do |c|
          if c == ' ' || c == '\t' || c == '\r' || c == '\n'
            in_space = true
          else
            sb << ' ' if in_space && sb.bytesize > 0
            in_space = false
            sb << c
          end
        end
      end
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

        # For pure-ASCII mappings (common case), use a flat 128-slot array instead of Hash
        all_ascii = src.each_char.all? { |c| c.ord < 128 }
        if all_ascii
          # Slot values: -1 = no mapping, 0 = delete char, >0 = replacement char ord
          table = StaticArray(Int32, 128).new(-1)
          src.each_char_with_index do |s, i|
            if i < dst.size
              table[s.ord] = dst[i].ord
            else
              table[s.ord] = 0 # mark for deletion
            end
          end
          String.build(str.size) do |sb|
            str.each_char do |c|
              if c.ord < 128
                v = table[c.ord]
                if v == -1
                  sb << c
                elsif v > 0
                  sb << v.unsafe_chr
                end
                # v == 0 means delete, skip
              else
                sb << c
              end
            end
          end
        else
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

    # matches is XPath 2.0 function matches(string, pattern [, flags])
    # Returns true if the string matches the regular expression pattern.
    # Optional flags: 's' (dotAll), 'm' (multiline), 'i' (case-insensitive), 'x' (extended)
    private def matches(arg1, arg2, arg3 : Query? = nil)
      XPathFunc.new do |_, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        pattern = as_string(t, function_args(arg2).evaluate(t))
        flags = ""
        unless arg3.nil?
          flags = as_string(t, function_args(arg3.not_nil!).evaluate(t))
        end

        options = Regex::Options::None
        flags.each_char do |f|
          case f
          when 'i' then options |= Regex::Options::IGNORE_CASE
          when 'm' then options |= Regex::Options::MULTILINE
          when 's' then options |= Regex::Options::DOTALL
          when 'x' then options |= Regex::Options::EXTENDED
          else
            raise XPath2Exception.new("matches() invalid flag: '#{f}'")
          end
        end

        begin
          re = Regex.new(pattern, options)
          !re.match(str).nil?
        rescue ex : ArgumentError
          raise XPath2Exception.new("matches() invalid regex pattern: #{ex.message}")
        end
      end
    end

    # lower_case is XPath 2.0 function lower-case(string)
    private def lower_case(arg1)
      XPathFunc.new do |_, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        str.downcase
      end
    end

    # upper_case is XPath 2.0 function upper-case(string)
    private def upper_case(arg1)
      XPathFunc.new do |_, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        str.upcase
      end
    end

    # lang checks whether the language of the context node matches the given language tag.
    # It walks up the ancestor chain looking for xml:lang or lang attributes.
    private def lang_func(arg1)
      XPathFunc.new do |_, t|
        target = as_string(t, function_args(arg1).evaluate(t)).downcase
        node = t.current.copy

        # Walk up the tree looking for a lang/xml:lang attribute
        found_lang = ""
        loop do
          # Check attributes of current node
          attr_nav = node.copy
          while attr_nav.move_to_next_attribute
            aname = attr_nav.local_name
            if aname == "lang" || (attr_nav.prefix == "xml" && aname == "lang")
              found_lang = attr_nav.value.downcase
              break
            end
          end
          break unless found_lang.empty?
          break unless node.move_to_parent
        end

        next false if found_lang.empty?
        # XPath lang() semantics: match if equal or if lang starts with target + "-"
        found_lang == target || found_lang.starts_with?("#{target}-")
      end
    end

    # id selects elements by their ID attribute value.
    # id('foo') selects the element with id="foo"
    # id('foo bar') selects elements with id="foo" or id="bar"
    private def id_func(arg1)
      XPathXFunc.new do |q, t|
        val = as_string(t, function_args(arg1).evaluate(t))
        # Split by whitespace to support id('foo bar') selecting multiple IDs
        ids = val.split(/\s+/).reject(&.empty?)

        # Walk the entire document from root to find matching elements
        list = Array(NodeNavigator).new
        unless ids.empty?
          id_set = ids.to_set
          root_nav = t.current.copy
          root_nav.move_to_root
          collect_by_id(root_nav.copy, id_set, list)
        end

        i = 0
        IteratorFunc.new {
          next nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
    end

    private def collect_by_id(nav : NodeNavigator, ids : Set(String), result : Array(NodeNavigator))
      # Check if current element has a matching id attribute
      if nav.node_type == NodeType::Element
        attr_nav = nav.copy
        while attr_nav.move_to_next_attribute
          if attr_nav.local_name == "id" && ids.includes?(attr_nav.value)
            result << nav.copy
            break
          end
        end
      end
      # Recurse into children
      child = nav.copy
      if child.move_to_child
        collect_by_id(child, ids, result)
        while child.move_to_next
          collect_by_id(child, ids, result)
        end
      end
    end

    # generate_id produces a unique string identifier for a node.
    # Uses the node's hash code to generate a deterministic ID.
    private def generate_id_func(arg : Query? = nil)
      XPathFunc.new do |_, t|
        if arg.nil?
          node = t.current
        else
          node = arg.not_nil!.select(t)
          next "" if node.nil?
        end
        hash = XPath2.get_hash_code(node.copy)
        "id#{hash}"
      end
    end

    # function_available checks if a named function is supported by this XPath implementation.
    private def function_available_func(arg1)
      XPathFunc.new do |_, t|
        name = as_string(t, function_args(arg1).evaluate(t))
        SUPPORTED_FUNCTIONS.includes?(name)
      end
    end

    SUPPORTED_FUNCTIONS = Set{
      "boolean", "ceiling", "compare", "concat", "contains", "count",
      "distinct-values", "empty", "ends-with", "exists", "false",
      "floor", "function-available", "generate-id", "id",
      "index-of", "insert-before",
      "lang", "last", "local-name", "lower-case", "matches",
      "name", "namespace-uri", "normalize-space", "not", "number",
      "position", "remove", "replace", "reverse", "round",
      "starts-with", "string", "string-join", "string-length",
      "subsequence", "substring", "substring-after",
      "substring-before", "sum", "tokenize", "translate",
      "true", "upper-case", "abs",
      "function-available",
    }

    # tokenize splits a string by a regex pattern and returns matching tokens.
    # tokenize("a, b, c", ",\s*") => ("a", "b", "c")
    private def tokenize_func(arg1, arg2)
      XPathXFunc.new do |q, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        pattern = as_string(t, function_args(arg2).evaluate(t))

        begin
          re = Regex.new(pattern)
          parts = str.split(re)
        rescue ex : ArgumentError
          raise XPath2Exception.new("tokenize() invalid regex pattern: #{ex.message}")
        end

        i = 0
        IteratorFunc.new {
          # We need to return NodeNavigator but tokenize returns strings.
          # For XPath 2.0, tokenize returns a sequence of strings.
          # Since our query model is node-based, we return nil here
          # and handle tokenize specially via evaluate.
          nil
        }
      end
    end

    # tokenize for evaluate — returns string results
    private def tokenize_eval(arg1, arg2)
      XPathFunc.new do |_, t|
        str = as_string(t, function_args(arg1).evaluate(t))
        pattern = as_string(t, function_args(arg2).evaluate(t))

        begin
          re = Regex.new(pattern)
          parts = str.split(re).reject(&.empty?)
          # Return as a joined string since ExprResult doesn't support arrays
          # For predicate use like tokenize(@class, '\s+') = 'active',
          # the comparison operator will handle string matching
          parts.join(" ")
        rescue ex : ArgumentError
          raise XPath2Exception.new("tokenize() invalid regex pattern: #{ex.message}")
        end
      end
    end

    # string_join joins a sequence of strings with a separator.
    # string-join(node-set, separator)
    private def string_join_func(arg1, arg2)
      XPathFunc.new do |_, t|
        sep = as_string(t, function_args(arg2).evaluate(t))
        typ = function_args(arg1).evaluate(t)
        case typ
        when String
          typ.as(String)
        when Query
          parts = Array(String).new
          loop do
            if (node = typ.select(t))
              parts << node.value
            else
              break
            end
          end
          parts.join(sep)
        else
          ""
        end
      end
    end

    # abs returns the absolute value of a number.
    private def abs_func(arg1)
      XPathFunc.new do |_, t|
        val = as_number(t, function_args(arg1).evaluate(t))
        val.abs
      end
    end

    # compare returns -1, 0, or 1 based on string comparison.
    private def compare_func(arg1, arg2)
      XPathFunc.new do |_, t|
        a = as_string(t, function_args(arg1).evaluate(t))
        b = as_string(t, function_args(arg2).evaluate(t))
        (a <=> b).to_f64
      end
    end

    # empty returns true if the node-set is empty.
    private def empty_func(arg1)
      XPathFunc.new do |_, t|
        typ = function_args(arg1).evaluate(t)
        case typ
        when Query
          typ.select(t).nil?
        when String
          typ.as(String).empty?
        when Nil
          true
        else
          false
        end
      end
    end

    # exists returns true if the node-set is non-empty.
    private def exists_func(arg1)
      XPathFunc.new do |_, t|
        typ = function_args(arg1).evaluate(t)
        case typ
        when Query
          !typ.select(t).nil?
        when String
          !typ.as(String).empty?
        when Nil
          false
        else
          true
        end
      end
    end

    # distinct-values returns unique string values from a node-set.
    private def distinct_values_func
      XPathXFunc.new do |q, t|
        list = Array(NodeNavigator).new
        seen = Set(String).new

        loop do
          node = q.select(t)
          break if node.nil?
          val = node.value
          unless seen.includes?(val)
            seen << val
            list << node.copy
          end
        end

        i = 0
        IteratorFunc.new {
          next nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
    end

    # subsequence returns a subsequence of nodes.
    # subsequence(node-set, starting-pos [, length])
    private def subsequence_func(arg1, arg2, arg3 : Query? = nil)
      XPathXFunc.new do |q, t|
        start = as_number(t, function_args(arg2).evaluate(t)).to_i
        len = arg3.nil? ? -1 : as_number(t, function_args(arg3.not_nil!).evaluate(t)).to_i

        list = Array(NodeNavigator).new
        pos = 0
        loop do
          node = q.select(t)
          break if node.nil?
          pos += 1
          if pos >= start && (len < 0 || pos < start + len)
            list << node.copy
          end
          break if len >= 0 && pos >= start + len
        end

        i = 0
        IteratorFunc.new {
          next nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
    end

    # remove removes an item at a given position from a sequence.
    # remove(node-set, position)
    private def remove_func(arg1, arg2)
      XPathXFunc.new do |q, t|
        remove_pos = as_number(t, function_args(arg2).evaluate(t)).to_i

        list = Array(NodeNavigator).new
        pos = 0
        loop do
          node = q.select(t)
          break if node.nil?
          pos += 1
          list << node.copy unless pos == remove_pos
        end

        i = 0
        IteratorFunc.new {
          next nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
    end

    # insert-before inserts nodes at a given position.
    # insert-before(node-set, position, inserts)
    private def insert_before_func(arg1, arg2, arg3)
      XPathXFunc.new do |q, t|
        insert_pos = as_number(t, function_args(arg2).evaluate(t)).to_i

        # Collect insert nodes
        insert_q = function_args(arg3)
        insert_typ = insert_q.evaluate(t)
        inserts = Array(NodeNavigator).new
        if insert_typ.is_a?(Query)
          loop do
            node = insert_typ.select(t)
            break if node.nil?
            inserts << node.copy
          end
        end

        list = Array(NodeNavigator).new
        pos = 0
        loop do
          node = q.select(t)
          break if node.nil?
          pos += 1
          if pos == insert_pos
            inserts.each { |n| list << n }
          end
          list << node.copy
        end
        # If insert_pos > sequence length, append at end
        if insert_pos > pos
          inserts.each { |n| list << n }
        end

        i = 0
        IteratorFunc.new {
          next nil if i >= list.size
          node = list[i]
          i += 1
          node
        }
      end
    end

    # index-of returns the position of the first item matching a value.
    private def index_of_func(arg1, arg2)
      XPathFunc.new do |_, t|
        search = as_string(t, function_args(arg2).evaluate(t))

        # Collect all values from the node-set
        arg1_q = function_args(arg1)
        typ = arg1_q.evaluate(t)

        result = 0_f64
        if typ.is_a?(Query)
          pos = 0
          loop do
            if (node = typ.select(t))
              pos += 1
              if node.value == search
                result = pos.to_f64
                break
              end
            else
              break
            end
          end
        end
        result
      end
    end

    # concatenates two or more strings
    private def concat(args)
      XPathFunc.new do |_, t|
        String.build do |sb|
          args.each do |v|
            v = function_args(v).evaluate(t)
            case v
            when String
              sb << v
            when Query
              if (node = v.select(t))
                sb << node.value
              end
            else
              #
            end
          end
        end
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
