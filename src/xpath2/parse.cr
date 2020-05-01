module XPath2
  # An XPath expression token type
  enum TokenType
    Comma      = 0 # ','
    Slash          # '/'
    At             # '@'
    Dot            # '.'
    LParens        # '('
    RParens        # ')'
    LBracket       # '['
    RBracket       # ']'
    Star           # '*'
    Plus           # '+'
    Minus          # '-'
    Eq             # '='
    Lt             # '<'
    Gt             # '>'
    Bang           # '!'
    Dollar         # '$'
    Apos           # '\''
    Quote          # '"'
    Union          # '|'
    Ne             # '!='
    Le             # '<='
    Ge             # '>='
    And            # '&&'
    Or             # '||'
    DotDot         # '..'
    SlashSlash     # '//'
    Name           # XML Name
    String         # Quoted string constant
    Number         # Number constant
    Axe            # Axe (like child::)
    Eof            # END
  end

  # A Node is an XPath node in the parser tree
  private module Node
    abstract def type : ParserNodeType
  end

  private abstract class BaseNodeType
    include Node
    @node_type : ParserNodeType

    def initialize(@node_type)
    end

    def type : ParserNodeType
      @node_type
    end
  end

  enum ParserNodeType
    Root            = 0
    Axis
    Filter
    Function
    Operator
    Variable
    ConstantOperand
  end

  # RootNode holds a top-level node of tree
  private class RootNode < BaseNodeType
    @slash : String

    def initialize(@slash)
      super(ParserNodeType::Root)
    end

    def to_s
      @slash
    end
  end

  # OperatorNode holds two Nodes operator
  private class OperatorNode < BaseNodeType
    getter op : String
    getter left : Node?
    getter right : Node?

    def initialize(@op, @left, @right)
      super(ParserNodeType::Operator)
    end

    def to_s(io : IO) : Nil
      io << "#{@left}#{@op}#{@right}"
    end
  end

  # AxixNode holds a location step.
  private class AxisNode < BaseNodeType
    getter input : Node?
    getter prop : String       # node-test name. [comment|text|processing-instruction|node]
    getter axe_type : String   # name of the axes.[attribute|ancestor|child|...]
    getter local_name : String # local part name of the node
    getter prefix : String     # prefix name of node

    def initialize(@axe_type, @local_name, @prefix, @prop, @input)
      super(ParserNodeType::Axis)
    end

    def to_s(io : IO) : Nil
      io << "#{@axe_type}::" unless @axe_type.empty?
      io << "#{@prefix}:" unless @prefix.empty?
      io << "#{local_name}" unless local_name.empty?
      io << "/#{@prop}()" unless @prop.empty?
    end
  end

  # OperandNode holds a constant operand
  private class OperandNode < BaseNodeType
    getter val : ExprResult

    def initialize(@val)
      super(ParserNodeType::ConstantOperand)
    end

    def to_s(io : IO) : Nil
      io << @val.to_s
    end
  end

  # FilterNode holds a condition filter
  private class FilterNode < BaseNodeType
    getter input : Node?
    getter condition : Node?

    def initialize(@input, @condition)
      super(ParserNodeType::Filter)
    end

    def to_s(io : IO) : Nil
      io << "#{@input}[#{@condition}]"
    end
  end

  # VariableNode holds a condition filter
  private class VariableNode < BaseNodeType
    getter name : String
    getter prefix : String

    def initialize(@name, @prefix)
      super(ParserNodeType::Variable)
    end

    def to_s(io : IO) : Nil
      if prefix.empty?
        io << name
        return
      end
      io << "#{@prefix}:#{@name}"
    end
  end

  # FunctionNode holds a function call.
  private class FunctionNode < BaseNodeType
    getter args : Array(Node)
    getter prefix : String
    getter funcname : String

    def initialize(@args, @prefix, @funcname)
      super(ParserNodeType::Function)
    end

    def to_s(io : IO) : Nil
      io << to_s
    end

    def to_s
      String.build do |sb|
        sb << @funcname
        sb << "("
        @args.each_with_index do |a, i|
          sb << "," if i > 0
          sb << a.to_s
        end
        sb << ")"
      end
    end
  end

  private class Parser
    @r : Scanner
    @d : Int32

    def initialize(@r, @d)
    end

    # parse the XPath expression string expr and returns a tree node
    def self.parse(expr : String)
      r = Scanner.new(text: expr)
      r.next_char
      r.next_item
      p = Parser.new(r: r, d: 0)
      p.parse_expression(nil)
    end

    # parse the expression with input node n
    protected def parse_expression(n : Node?)
      @d += 1
      raise XPath2Exception.new("XPath query is too complex (depth > 200)") if @d > 200

      n = parse_or_expr(n)
      @d -= 1
      n
    end

    # scan next item moving forward
    private def next
      @r.next_item
    end

    private def check(typ : TokenType)
      raise XPath2Exception.new("#{@r.text} has an invalid token") unless @r.type == typ
    end

    private def testop(op : String)
      @r.type == TokenType::Name && @r.prefix.empty? && @r.name == op
    end

    private def primary_expr?
      case @r.type
      when .string?, .number?, .dollar?, .l_parens?
        true
      when .name?
        @r.can_be_func && !node_type?
      else
        false
      end
    end

    private def node_type?
      case @r.name
      when "node", "text", "processing-instruction", "comment"
        @r.prefix.empty?
      else
        false
      end
    end

    private def step?(typ : TokenType)
      case typ
      when .dot?, .dot_dot?, .at?, .axe?, .star?, .name?
        true
      else
        false
      end
    end

    private def skip(typ : TokenType)
      check(typ)
      self.next
    end

    # OrExpr ::= AndExpr | OrExpr 'or' AndExpr
    private def parse_or_expr(n : Node?)
      opnd = parse_and_expr(n)
      loop do
        break unless testop("or")
        self.next
        opnd = OperatorNode.new("or", opnd, parse_and_expr(n))
      end
      opnd
    end

    # AndExpr ::= EqualityExpr | AndExpr 'and' EqualityExpr
    private def parse_and_expr(n : Node?)
      opnd = parse_equality_expr(n)
      loop do
        break unless testop("and")
        self.next
        opnd = OperatorNode.new("and", opnd, parse_equality_expr(n))
      end
      opnd
    end

    # EqualityExpr ::= RelationalExpr | EqualityExpr '=' RelationalExpr | EqualityExpr !=' RelationalExpr
    private def parse_equality_expr(n : Node?)
      opnd = parse_relational_expr(n)
      loop do
        case @r.type
        when .eq?
          op = "="
        when .ne?
          op = "!="
        else
          return opnd
        end
        self.next
        opnd = OperatorNode.new(op, opnd, parse_relational_expr(n))
      end
      opnd
    end

    # RelationalExpr ::= AdditiveExpr	| RelationalExpr '<' AdditiveExpr | RelationalExpr '>' AdditiveExpr
    #					| RelationalExpr '<=' AdditiveExpr
    #					| RelationalExpr '>=' AdditiveExpr
    private def parse_relational_expr(n : Node?)
      opnd = parse_additive_expr(n)
      loop do
        case @r.type
        when .lt?
          op = "<"
        when .gt?
          op = ">"
        when .le?
          op = "<="
        when .ge?
          op = ">="
        else
          return opnd
        end
        self.next
        opnd = OperatorNode.new(op, opnd, parse_additive_expr(n))
      end
      opnd
    end

    # AdditiveExpr	::= MultiplicativeExpr	| AdditiveExpr '+' MultiplicativeExpr | AdditiveExpr '-' MultiplicativeExpr
    private def parse_additive_expr(n : Node?)
      opnd = parse_multiplicative_expr(n)
      loop do
        case @r.type
        when .plus?
          op = "+"
        when .minus?
          op = "-"
        else
          return opnd
        end
        self.next
        opnd = OperatorNode.new(op, opnd, parse_multiplicative_expr(n))
      end
      opnd
    end

    # MultiplicativeExpr ::= UnaryExpr	| MultiplicativeExpr MultiplyOperator(*) UnaryExpr
    #						| MultiplicativeExpr 'div' UnaryExpr | MultiplicativeExpr 'mod' UnaryExpr
    private def parse_multiplicative_expr(n : Node?)
      opnd = parse_unary_expr(n)
      loop do
        if @r.type == TokenType::Star
          op = "*"
        elsif testop("div") || testop("mod")
          op = @r.name
        else
          return opnd
        end
        self.next
        opnd = OperatorNode.new(op, opnd, parse_unary_expr(n))
      end
      opnd
    end

    # UnaryExpr ::= UnionExpr | '-' UnaryExpr
    private def parse_unary_expr(n : Node?)
      minus = false
      # ignore '-' sequence
      while @r.type == TokenType::Minus
        self.next
        minus = !minus
      end
      opnd = parse_union_expr(n)
      opnd = OperatorNode.new("*", opnd, OperandNode.new(-1_f64)) if minus
      opnd
    end

    # UnionExpr ::= PathExpr | UnionExpr '|' PathExpr
    private def parse_union_expr(n : Node?)
      opnd = parse_path_expr(n)
      loop do
        break unless @r.type == TokenType::Union
        self.next
        opnd2 = parse_path_expr(n)
        # Checking the node type that must be is node set type?
        opnd = OperatorNode.new("|", opnd, opnd2)
      end
      opnd
    end

    # PathExpr ::= LocationPath | FilterExpr | FilterExpr '/' RelativeLocationPath	| FilterExpr '//' RelativeLocationPath
    private def parse_path_expr(n : Node?)
      if primary_expr?
        opnd = parse_filter_expr(n)
        case @r.type
        when .slash?
          self.next
          opnd = parse_relative_location_path(opnd)
        when .slash_slash?
          self.next
          opnd = parse_relative_location_path(AxisNode.new("descendant-or-self", "", "", "", opnd))
        else
          #
        end
      else
        opnd = parse_location_path(nil)
      end
      opnd
    end

    # FilterExpr ::= PrimaryExpr | FilterExpr Predicate
    private def parse_filter_expr(n : Node?)
      opnd = parse_primary_expr(n)
      return FilterNode.new(opnd, parse_predicate(opnd)) if @r.type == TokenType::LBracket
      opnd
    end

    # Predicate ::=  '[' PredicateExpr ']'
    private def parse_predicate(n : Node)
      skip(TokenType::LBracket)
      opnd = parse_expression(n)
      skip(TokenType::RBracket)
      opnd
    end

    # LocationPath ::= RelativeLocationPath | AbsoluteLocationPath
    private def parse_location_path(n : Node?)
      case @r.type
      when .slash?
        self.next
        opnd = RootNode.new("/")
        opnd = parse_relative_location_path(opnd) if step?(@r.type)
      when .slash_slash?
        self.next
        opnd = RootNode.new("//")
        opnd = parse_relative_location_path(AxisNode.new("descendant-or-self", "", "", "", opnd))
      else
        opnd = parse_relative_location_path(n)
      end
      opnd
    end

    # RelativeLocationPath	 ::= Step | RelativeLocationPath '/' Step | AbbreviatedRelativeLocationPath
    private def parse_relative_location_path(n : Node?)
      opnd = n
      loop do
        opnd = parse_step(opnd)
        case @r.type
        when .slash_slash?
          self.next
          opnd = AxisNode.new("descendant-or-self", "", "", "", opnd)
        when .slash?
          self.next
        else
          break
        end
      end
      opnd
    end

    # Step	::= AxisSpecifier NodeTest Predicate* | AbbreviatedStep
    private def parse_step(n : Node?)
      axe_type = "child" # default axes value
      if @r.type == TokenType::Dot || @r.type == TokenType::DotDot
        axe_type = @r.type == TokenType::Dot ? "self" : "parent"
        self.next
        opnd = AxisNode.new(axe_type: axe_type, local_name: "", prefix: "", prop: "", input: n)
        return opnd unless @r.type == TokenType::LBracket
      else
        case @r.type
        when .at?
          self.next
          axe_type = "attribute"
        when .axe?
          axe_type = @r.name
          self.next
        when .l_parens?
          return parse_sequence(n)
        else
          #
        end
        opnd = parse_node_test(n, axe_type)
      end
      while @r.type == TokenType::LBracket
        exc : Exception? = nil
        begin
          pnode = parse_predicate(opnd)
        rescue ex
          exc = ex
        end
        raise exc unless exc.nil?
        opnd = FilterNode.new(opnd, pnode)
      end
      opnd
    end

    # Expr ::= '(' Step ("," Step)* ')'
    private def parse_sequence(n : Node?)
      skip(TokenType::LParens)
      opnd = parse_step(n)
      loop do
        break unless @r.type == TokenType::Comma
        self.next
        opnd2 = parse_step(n)
        opnd = OperatorNode.new("|", opnd, opnd2)
      end
      skip(TokenType::RParens)
      opnd
    end

    # NodeTest ::= NameTest | nodeType '(' ')' | 'processing-instruction' '(' Literal ')'
    private def parse_node_test(n, axe_type)
      case @r.type
      when .name?
        if @r.can_be_func && node_type?
          prop = ""
          prop = @r.name if ["comment", "text", "processing-instruction", "node"].includes?(@r.name)
          name = ""
          self.next
          skip(TokenType::LParens)
          if prop == "processing-instruction" && @r.type != TokenType::RParens
            check(TokenType::String)
            name = @r.strval
            self.next
          end
          skip(TokenType::RParens)
          opnd = AxisNode.new(axe_type, name, "", prop, n)
        else
          prefix = @r.prefix
          name = @r.name
          self.next
          name = "" if @r.name == "*"
          opnd = AxisNode.new(axe_type, name, prefix, "", n)
        end
      when .star?
        opnd = AxisNode.new(axe_type, "", "", "", n)
        self.next
      else
        raise XPath2Exception.new("express must evaluate to a node-set")
      end
      opnd
    end

    # PrimaryExpr ::= VariableReference | '(' Expr ')'	| Literal | Number | FunctionCall
    private def parse_primary_expr(n : Node?)
      case @r.type
      when .string?
        opnd = OperandNode.new(@r.strval)
        self.next
      when .number?
        opnd = OperandNode.new(@r.numval)
        self.next
      when .dollar?
        self.next
        check(TokenType::Name)
        opnd = VariableNode.new(@r.prefix, @r.name)
        self.next
      when .l_parens?
        self.next
        opnd = parse_expression(n)
        skip(TokenType::RParens)
      when .name?
        opnd = parse_method(nil) if @r.can_be_func && !node_type?
      else
        raise XPath2Exception.new("Uknown Token type : #{@r.type}")
      end
      opnd.not_nil!
    end

    # FunctionCall	 ::=  FunctionName '(' ( Argument ( ',' Argument )* )? ')'
    private def parse_method(n : Node?)
      args = Array(Node).new
      name = @r.name
      prefix = @r.prefix
      skip(TokenType::Name)
      skip(TokenType::LParens)
      unless @r.type == TokenType::RParens
        loop do
          if (e = parse_expression(n))
            args << e
          end
          break if @r.type == TokenType::RParens
          skip(TokenType::Comma)
        end
      end
      skip(TokenType::RParens)
      FunctionNode.new(args, prefix, name)
    end
  end

  private class Scanner
    getter type : TokenType
    getter strval : String  # text value at current pos
    getter numval : Float64 # number value at current pos
    getter can_be_func : Bool
    getter name : String
    getter prefix : String
    getter text : String

    def initialize(@text : String, @name = "", @prefix = "")
      @pos = 0
      @curr = Char::ZERO
      @type = TokenType::Eof
      @strval = ""
      @numval = 0_f64
      @can_be_func = false
    end

    def next_char
      if @pos >= @text.size
        @curr = Char::ZERO
        return false
      end
      @curr = @text[@pos]
      @pos += 1
      true
    end

    def next_item
      skip_space
      case @curr
      when Char::ZERO
        @type = TokenType::Eof
        return false
      when ',', '@', '(', ')', '|', '*', '[', ']', '+', '-', '=', '#', '$'
        @type = as_item_type
        next_char
      when '<'
        @type = TokenType::Lt
        next_char
        if @curr == '='
          @type = TokenType::Le
          next_char
        end
      when '>'
        @type = TokenType::Gt
        next_char
        if @curr == '='
          @type = TokenType::Ge
          next_char
        end
      when '!'
        @type = TokenType::Bang
        next_char
        if @curr == '='
          @type = TokenType::Ne
          next_char
        end
      when '.'
        @type = TokenType::Dot
        next_char
        if @curr == '.'
          @type = TokenType::DotDot
          next_char
        elsif @curr.number?
          @type = TokenType::Number
          @numval = scan_fraction
        end
      when '/'
        @type = TokenType::Slash
        next_char
        if @curr == '/'
          @type = TokenType::SlashSlash
          next_char
        end
      when '"', '\''
        @type = TokenType::String
        @strval = scan_string
      else
        if @curr.number?
          @type = TokenType::Number
          @numval = scan_number
        elsif is_name(@curr)
          @type = TokenType::Name
          @name = scan_name
          @prefix = ""
          # "foo:bar" is one item not three because it doesn't allow spaces in between
          # we should distinct it from "foo::" and need process "foo ::" as well
          if @curr == ':'
            next_char
            # can be "foo:bar" or "foo::"
            if @curr == ':'
              # "foo::"
              next_char
              @type = TokenType::Axe
            else # "foo:*", "foo:bar" or "foo: "
              @prefix = @name
              if @curr == '*'
                next_char
                @name = "*"
              elsif is_name(@curr)
                @name = scan_name
              else
                raise XPath2Exception.new("#{@text} has an invalid qualified name.")
              end
            end
          else
            skip_space
            if @curr == ':'
              next_char
              # it can be "foo ::" or just "foo :"
              if @curr == ':'
                next_char
                @type = TokenType::Axe
              else
                raise XPath2Exception.new("#{@text} has an invalid qualified name.")
              end
            end
          end
          skip_space
          @can_be_func = @curr == '('
        else
          raise XPath2Exception.new("#{@text} has an invalid token.")
        end
      end
      true
    end

    private def skip_space
      loop do
        break if !@curr.whitespace? || !next_char
      end
    end

    private def scan_fraction
      i = @pos - 2
      c = 1 # '.'

      while @curr.number?
        next_char
        c += 1
      end
      if (v = @text[i...i + c].to_f?)
        v
      else
        raise XPath2Exception.new("Invalid float value #{@text[i...i + c]}")
      end
    end

    private def scan_number
      i = @pos - 1
      c = 0

      while @curr.number?
        next_char
        c += 1
      end
      if @curr == '.'
        next_char
        c += 1
        while @curr.number?
          next_char
          c += 1
        end
      end
      if (v = @text[i...i + c].to_f?)
        v
      else
        raise XPath2Exception.new("Invalid float value #{@text[i...i + c]}")
      end
    end

    private def scan_string
      c = 0
      e = @curr
      next_char
      i = @pos - 1
      while @curr != e
        raise XPath2Exception.new("unclosed string") unless next_char
        c += 1
      end
      next_char
      @text[i...i + c]
    end

    private def scan_name
      c = 0
      i = @pos - 1
      while is_name(@curr)
        c += 1
        break unless next_char
      end
      @text[i...i + c]
    end

    private def is_name(c : Char)
      c != ':' && c != '/' && (allowed_char(c) || c == '*')
    end

    private def as_item_type
      case @curr
      when ',' then TokenType::Comma
      when '@' then TokenType::At
      when '(' then TokenType::LParens
      when ')' then TokenType::RParens
      when '|' then TokenType::Union
      when '*' then TokenType::Star
      when '[' then TokenType::LBracket
      when ']' then TokenType::RBracket
      when '+' then TokenType::Plus
      when '-' then TokenType::Minus
      when '=' then TokenType::Eq
      when '$' then TokenType::Dollar
      else
        raise XPath2Exception.new("Uknown Token type: #{@curr}")
      end
    end

    private def allowed_char(ch : Char) : Bool
      UNICODE_RANGE.each do |t|
        if (t[0].unsafe_chr..t[1].unsafe_chr).includes?(ch)
          return true
        end
      end
      false
    end

    private UNICODE_RANGE = [
      {0x003A, 0x003A, 1},
      {0x0041, 0x005A, 1},
      {0x005F, 0x005F, 1},
      {0x0061, 0x007A, 1},
      {0x00C0, 0x00D6, 1},
      {0x00D8, 0x00F6, 1},
      {0x00F8, 0x00FF, 1},
      {0x0100, 0x0131, 1},
      {0x0134, 0x013E, 1},
      {0x0141, 0x0148, 1},
      {0x014A, 0x017E, 1},
      {0x0180, 0x01C3, 1},
      {0x01CD, 0x01F0, 1},
      {0x01F4, 0x01F5, 1},
      {0x01FA, 0x0217, 1},
      {0x0250, 0x02A8, 1},
      {0x02BB, 0x02C1, 1},
      {0x0386, 0x0386, 1},
      {0x0388, 0x038A, 1},
      {0x038C, 0x038C, 1},
      {0x038E, 0x03A1, 1},
      {0x03A3, 0x03CE, 1},
      {0x03D0, 0x03D6, 1},
      {0x03DA, 0x03E0, 2},
      {0x03E2, 0x03F3, 1},
      {0x0401, 0x040C, 1},
      {0x040E, 0x044F, 1},
      {0x0451, 0x045C, 1},
      {0x045E, 0x0481, 1},
      {0x0490, 0x04C4, 1},
      {0x04C7, 0x04C8, 1},
      {0x04CB, 0x04CC, 1},
      {0x04D0, 0x04EB, 1},
      {0x04EE, 0x04F5, 1},
      {0x04F8, 0x04F9, 1},
      {0x0531, 0x0556, 1},
      {0x0559, 0x0559, 1},
      {0x0561, 0x0586, 1},
      {0x05D0, 0x05EA, 1},
      {0x05F0, 0x05F2, 1},
      {0x0621, 0x063A, 1},
      {0x0641, 0x064A, 1},
      {0x0671, 0x06B7, 1},
      {0x06BA, 0x06BE, 1},
      {0x06C0, 0x06CE, 1},
      {0x06D0, 0x06D3, 1},
      {0x06D5, 0x06D5, 1},
      {0x06E5, 0x06E6, 1},
      {0x0905, 0x0939, 1},
      {0x093D, 0x093D, 1},
      {0x0958, 0x0961, 1},
      {0x0985, 0x098C, 1},
      {0x098F, 0x0990, 1},
      {0x0993, 0x09A8, 1},
      {0x09AA, 0x09B0, 1},
      {0x09B2, 0x09B2, 1},
      {0x09B6, 0x09B9, 1},
      {0x09DC, 0x09DD, 1},
      {0x09DF, 0x09E1, 1},
      {0x09F0, 0x09F1, 1},
      {0x0A05, 0x0A0A, 1},
      {0x0A0F, 0x0A10, 1},
      {0x0A13, 0x0A28, 1},
      {0x0A2A, 0x0A30, 1},
      {0x0A32, 0x0A33, 1},
      {0x0A35, 0x0A36, 1},
      {0x0A38, 0x0A39, 1},
      {0x0A59, 0x0A5C, 1},
      {0x0A5E, 0x0A5E, 1},
      {0x0A72, 0x0A74, 1},
      {0x0A85, 0x0A8B, 1},
      {0x0A8D, 0x0A8D, 1},
      {0x0A8F, 0x0A91, 1},
      {0x0A93, 0x0AA8, 1},
      {0x0AAA, 0x0AB0, 1},
      {0x0AB2, 0x0AB3, 1},
      {0x0AB5, 0x0AB9, 1},
      {0x0ABD, 0x0AE0, 0x23},
      {0x0B05, 0x0B0C, 1},
      {0x0B0F, 0x0B10, 1},
      {0x0B13, 0x0B28, 1},
      {0x0B2A, 0x0B30, 1},
      {0x0B32, 0x0B33, 1},
      {0x0B36, 0x0B39, 1},
      {0x0B3D, 0x0B3D, 1},
      {0x0B5C, 0x0B5D, 1},
      {0x0B5F, 0x0B61, 1},
      {0x0B85, 0x0B8A, 1},
      {0x0B8E, 0x0B90, 1},
      {0x0B92, 0x0B95, 1},
      {0x0B99, 0x0B9A, 1},
      {0x0B9C, 0x0B9C, 1},
      {0x0B9E, 0x0B9F, 1},
      {0x0BA3, 0x0BA4, 1},
      {0x0BA8, 0x0BAA, 1},
      {0x0BAE, 0x0BB5, 1},
      {0x0BB7, 0x0BB9, 1},
      {0x0C05, 0x0C0C, 1},
      {0x0C0E, 0x0C10, 1},
      {0x0C12, 0x0C28, 1},
      {0x0C2A, 0x0C33, 1},
      {0x0C35, 0x0C39, 1},
      {0x0C60, 0x0C61, 1},
      {0x0C85, 0x0C8C, 1},
      {0x0C8E, 0x0C90, 1},
      {0x0C92, 0x0CA8, 1},
      {0x0CAA, 0x0CB3, 1},
      {0x0CB5, 0x0CB9, 1},
      {0x0CDE, 0x0CDE, 1},
      {0x0CE0, 0x0CE1, 1},
      {0x0D05, 0x0D0C, 1},
      {0x0D0E, 0x0D10, 1},
      {0x0D12, 0x0D28, 1},
      {0x0D2A, 0x0D39, 1},
      {0x0D60, 0x0D61, 1},
      {0x0E01, 0x0E2E, 1},
      {0x0E30, 0x0E30, 1},
      {0x0E32, 0x0E33, 1},
      {0x0E40, 0x0E45, 1},
      {0x0E81, 0x0E82, 1},
      {0x0E84, 0x0E84, 1},
      {0x0E87, 0x0E88, 1},
      {0x0E8A, 0x0E8D, 3},
      {0x0E94, 0x0E97, 1},
      {0x0E99, 0x0E9F, 1},
      {0x0EA1, 0x0EA3, 1},
      {0x0EA5, 0x0EA7, 2},
      {0x0EAA, 0x0EAB, 1},
      {0x0EAD, 0x0EAE, 1},
      {0x0EB0, 0x0EB0, 1},
      {0x0EB2, 0x0EB3, 1},
      {0x0EBD, 0x0EBD, 1},
      {0x0EC0, 0x0EC4, 1},
      {0x0F40, 0x0F47, 1},
      {0x0F49, 0x0F69, 1},
      {0x10A0, 0x10C5, 1},
      {0x10D0, 0x10F6, 1},
      {0x1100, 0x1100, 1},
      {0x1102, 0x1103, 1},
      {0x1105, 0x1107, 1},
      {0x1109, 0x1109, 1},
      {0x110B, 0x110C, 1},
      {0x110E, 0x1112, 1},
      {0x113C, 0x1140, 2},
      {0x114C, 0x1150, 2},
      {0x1154, 0x1155, 1},
      {0x1159, 0x1159, 1},
      {0x115F, 0x1161, 1},
      {0x1163, 0x1169, 2},
      {0x116D, 0x116E, 1},
      {0x1172, 0x1173, 1},
      {0x1175, 0x119E, 0x119E - 0x1175},
      {0x11A8, 0x11AB, 0x11AB - 0x11A8},
      {0x11AE, 0x11AF, 1},
      {0x11B7, 0x11B8, 1},
      {0x11BA, 0x11BA, 1},
      {0x11BC, 0x11C2, 1},
      {0x11EB, 0x11F0, 0x11F0 - 0x11EB},
      {0x11F9, 0x11F9, 1},
      {0x1E00, 0x1E9B, 1},
      {0x1EA0, 0x1EF9, 1},
      {0x1F00, 0x1F15, 1},
      {0x1F18, 0x1F1D, 1},
      {0x1F20, 0x1F45, 1},
      {0x1F48, 0x1F4D, 1},
      {0x1F50, 0x1F57, 1},
      {0x1F59, 0x1F5B, 0x1F5B - 0x1F59},
      {0x1F5D, 0x1F5D, 1},
      {0x1F5F, 0x1F7D, 1},
      {0x1F80, 0x1FB4, 1},
      {0x1FB6, 0x1FBC, 1},
      {0x1FBE, 0x1FBE, 1},
      {0x1FC2, 0x1FC4, 1},
      {0x1FC6, 0x1FCC, 1},
      {0x1FD0, 0x1FD3, 1},
      {0x1FD6, 0x1FDB, 1},
      {0x1FE0, 0x1FEC, 1},
      {0x1FF2, 0x1FF4, 1},
      {0x1FF6, 0x1FFC, 1},
      {0x2126, 0x2126, 1},
      {0x212A, 0x212B, 1},
      {0x212E, 0x212E, 1},
      {0x2180, 0x2182, 1},
      {0x3007, 0x3007, 1},
      {0x3021, 0x3029, 1},
      {0x3041, 0x3094, 1},
      {0x30A1, 0x30FA, 1},
      {0x3105, 0x312C, 1},
      {0x4E00, 0x9FA5, 1},
      {0xAC00, 0xD7A3, 1},
      {0x002D, 0x002E, 1},
      {0x0030, 0x0039, 1},
      {0x00B7, 0x00B7, 1},
      {0x02D0, 0x02D1, 1},
      {0x0300, 0x0345, 1},
      {0x0360, 0x0361, 1},
      {0x0387, 0x0387, 1},
      {0x0483, 0x0486, 1},
      {0x0591, 0x05A1, 1},
      {0x05A3, 0x05B9, 1},
      {0x05BB, 0x05BD, 1},
      {0x05BF, 0x05BF, 1},
      {0x05C1, 0x05C2, 1},
      {0x05C4, 0x0640, 0x0640 - 0x05C4},
      {0x064B, 0x0652, 1},
      {0x0660, 0x0669, 1},
      {0x0670, 0x0670, 1},
      {0x06D6, 0x06DC, 1},
      {0x06DD, 0x06DF, 1},
      {0x06E0, 0x06E4, 1},
      {0x06E7, 0x06E8, 1},
      {0x06EA, 0x06ED, 1},
      {0x06F0, 0x06F9, 1},
      {0x0901, 0x0903, 1},
      {0x093C, 0x093C, 1},
      {0x093E, 0x094C, 1},
      {0x094D, 0x094D, 1},
      {0x0951, 0x0954, 1},
      {0x0962, 0x0963, 1},
      {0x0966, 0x096F, 1},
      {0x0981, 0x0983, 1},
      {0x09BC, 0x09BC, 1},
      {0x09BE, 0x09BF, 1},
      {0x09C0, 0x09C4, 1},
      {0x09C7, 0x09C8, 1},
      {0x09CB, 0x09CD, 1},
      {0x09D7, 0x09D7, 1},
      {0x09E2, 0x09E3, 1},
      {0x09E6, 0x09EF, 1},
      {0x0A02, 0x0A3C, 0x3A},
      {0x0A3E, 0x0A3F, 1},
      {0x0A40, 0x0A42, 1},
      {0x0A47, 0x0A48, 1},
      {0x0A4B, 0x0A4D, 1},
      {0x0A66, 0x0A6F, 1},
      {0x0A70, 0x0A71, 1},
      {0x0A81, 0x0A83, 1},
      {0x0ABC, 0x0ABC, 1},
      {0x0ABE, 0x0AC5, 1},
      {0x0AC7, 0x0AC9, 1},
      {0x0ACB, 0x0ACD, 1},
      {0x0AE6, 0x0AEF, 1},
      {0x0B01, 0x0B03, 1},
      {0x0B3C, 0x0B3C, 1},
      {0x0B3E, 0x0B43, 1},
      {0x0B47, 0x0B48, 1},
      {0x0B4B, 0x0B4D, 1},
      {0x0B56, 0x0B57, 1},
      {0x0B66, 0x0B6F, 1},
      {0x0B82, 0x0B83, 1},
      {0x0BBE, 0x0BC2, 1},
      {0x0BC6, 0x0BC8, 1},
      {0x0BCA, 0x0BCD, 1},
      {0x0BD7, 0x0BD7, 1},
      {0x0BE7, 0x0BEF, 1},
      {0x0C01, 0x0C03, 1},
      {0x0C3E, 0x0C44, 1},
      {0x0C46, 0x0C48, 1},
      {0x0C4A, 0x0C4D, 1},
      {0x0C55, 0x0C56, 1},
      {0x0C66, 0x0C6F, 1},
      {0x0C82, 0x0C83, 1},
      {0x0CBE, 0x0CC4, 1},
      {0x0CC6, 0x0CC8, 1},
      {0x0CCA, 0x0CCD, 1},
      {0x0CD5, 0x0CD6, 1},
      {0x0CE6, 0x0CEF, 1},
      {0x0D02, 0x0D03, 1},
      {0x0D3E, 0x0D43, 1},
      {0x0D46, 0x0D48, 1},
      {0x0D4A, 0x0D4D, 1},
      {0x0D57, 0x0D57, 1},
      {0x0D66, 0x0D6F, 1},
      {0x0E31, 0x0E31, 1},
      {0x0E34, 0x0E3A, 1},
      {0x0E46, 0x0E46, 1},
      {0x0E47, 0x0E4E, 1},
      {0x0E50, 0x0E59, 1},
      {0x0EB1, 0x0EB1, 1},
      {0x0EB4, 0x0EB9, 1},
      {0x0EBB, 0x0EBC, 1},
      {0x0EC6, 0x0EC6, 1},
      {0x0EC8, 0x0ECD, 1},
      {0x0ED0, 0x0ED9, 1},
      {0x0F18, 0x0F19, 1},
      {0x0F20, 0x0F29, 1},
      {0x0F35, 0x0F39, 2},
      {0x0F3E, 0x0F3F, 1},
      {0x0F71, 0x0F84, 1},
      {0x0F86, 0x0F8B, 1},
      {0x0F90, 0x0F95, 1},
      {0x0F97, 0x0F97, 1},
      {0x0F99, 0x0FAD, 1},
      {0x0FB1, 0x0FB7, 1},
      {0x0FB9, 0x0FB9, 1},
      {0x20D0, 0x20DC, 1},
      {0x20E1, 0x3005, 0x3005 - 0x20E1},
      {0x302A, 0x302F, 1},
      {0x3031, 0x3035, 1},
      {0x3099, 0x309A, 1},
      {0x309D, 0x309E, 1},
      {0x30FC, 0x30FE, 1},
    ]
  end
end
