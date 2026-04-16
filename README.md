# Crystal XPath2

![CI](https://github.com/naqvis/crystal-xpath2/workflows/CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/naqvis/crystal-xpath2.svg)](https://github.com/naqvis/crystal-xpath2/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://naqvis.github.io/crystal-xpath2/)

**Crystal XPath2** Shard provide XPath implementation in **Pure Crystal**. Performs the compilation of XPath expression and provides mechanism to select/evaluate nodes from HTML or other documents using XPath expression

# Supported Features

#### The basic XPath patterns.

> The basic XPath patterns cover 90% of the cases that most stylesheets will need.

- `node` : Selects all child elements with node Name of node.

- `*` : Selects all child elements.

- `@attr` : Selects the attribute attr.

- `@*` : Selects all attributes.

- `node()` : Matches an org.w3c.dom.Node.

- `text()` : Matches a org.w3c.dom.Text node.

- `comment()` : Matches a comment.

- `.` : Selects the current node.

- `..` : Selects the parent of current node.

- `/` : Selects the document node.

- `a[expr]` : Select only those nodes matching a which also satisfy the expression expr.

- `a[n]` : Selects the nth matching node matching a When a filter's expression is a number, XPath selects based on position.

- `a/b` : For each node matching a, add the nodes matching b to the result.

- `a//b` : For each node matching a, add the descendant nodes matching b to the result.

- `//b` : Returns elements in the entire document matching b.

- `a|b` : All nodes matching a or b, union operation(not boolean or).

- `(a, b, c)` : Evaluates each of its operands and concatenates the resulting sequences, in order, into a single result sequence

#### Node Axes

- `child::*` : The child axis selects children of the current node.

- `descendant::*` : The descendant axis selects descendants of the current node. It is equivalent to `"//"`.

- `descendant-or-self::*` : Selects descendants including the current node.

- `attribute::*` : Selects attributes of the current element. It is equivalent to `@*`

- `following-sibling::*` : Selects nodes after the current node.

- `preceding-sibling::*` : Selects nodes before the current node.

- `following::*` : Selects the first matching node following in document order, excluding descendants.

- `preceding::*` : Selects the first matching node preceding in document order, excluding ancestors.

- `parent::*` : Selects the parent if it matches. The `".."` pattern from the core is equivalent to 'parent::node()'.

- `ancestor::*` : Selects matching ancestors.

- `ancestor-or-self::*` : Selects ancestors including the current node.

- `self::*` : Selects the current node. `'.'` is equivalent to `"self::node()"`.

#### Expressions

Shard supports three types: number, boolean, string.

- `path` : Selects nodes based on the path.

- `a = b` : Standard comparisons.
  - a `=` b `true` if a equals b.
  - a `!=` b `true` if a is not equal to b.
  - a `<` b `true` if a is less than b.
  - a `<=` b `true` if a is less than or equal to b.
  - a `>` b `true` if a is greater than b.
  - a `>=` b `true` if a is greater than or equal to b.

- `a + b` : Arithmetic expressions.
  - `- a` Unary minus
  - a `+` b Add
  - a `-` b Substract
  - a `*` b Multiply
  - a `div` b Divide
  - a `mod` b Floating point mod, like Java.

- `a or b` : Boolean `or` operation.

- `a and b` : Boolean `and` operation.

- `(expr)` : Parenthesized expressions.

- `fun(arg1, ..., argn)` : Function calls:

- `$variable` : Variable references. Variables are bound at compile time via `XPath2.compile(expr, variables)`.

| Function               | Supported |
| ---------------------- | --------- |
| `abs()`                | ✓         |
| `boolean()`            | ✓         |
| `ceiling()`            | ✓         |
| `compare()`            | ✓         |
| `concat()`             | ✓         |
| `contains()`           | ✓         |
| `count()`              | ✓         |
| `distinct-values()`    | ✓         |
| `empty()`              | ✓         |
| `ends-with()`          | ✓         |
| `exists()`             | ✓         |
| `false()`              | ✓         |
| `floor()`              | ✓         |
| `function-available()` | ✓         |
| `generate-id()`        | ✓         |
| `id()`                 | ✓         |
| `index-of()`           | ✓         |
| `insert-before()`      | ✓         |
| `lang()`               | ✓         |
| `last()`               | ✓         |
| `local-name()`         | ✓         |
| `lower-case()`         | ✓         |
| `matches()`            | ✓         |
| `name()`               | ✓         |
| `namespace-uri()`      | ✓         |
| `normalize-space()`    | ✓         |
| `not()`                | ✓         |
| `number()`             | ✓         |
| `position()`           | ✓         |
| `remove()`             | ✓         |
| `replace()`            | ✓         |
| `reverse()`            | ✓         |
| `round()`              | ✓         |
| `starts-with()`        | ✓         |
| `string()`             | ✓         |
| `string-join()`        | ✓         |
| `string-length()`      | ✓         |
| `subsequence()`        | ✓         |
| `substring()`          | ✓         |
| `substring-after()`    | ✓         |
| `substring-before()`   | ✓         |
| `sum()`                | ✓         |
| `tokenize()`           | ✓         |
| `translate()`          | ✓         |
| `true()`               | ✓         |
| `upper-case()`         | ✓         |

> **Note:** XSLT-specific functions (`choose`, `current`, `document`, `element-available`, `format-number`, `key`, `system-property`, `unparsed-entity-url`) are not supported as they require an XSLT processing context.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     xpath2:
       github: naqvis/crystal-xpath2
   ```

2. Run `shards install`

## Usage

refer to `spec` for usage examples refer to `spec` or refer to [Crystal HTML5](https://github.com/naqvis/crystal-html5) and [JSON XPath](https://github.com/naqvis/json-xpath) for implementation details.

## Development

To run all tests:

```
crystal spec
```

## Contributing

1. Fork it (<https://github.com/naqvis/crystal-xpath2/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ali Naqvi](https://github.com/naqvis) - creator and maintainer
