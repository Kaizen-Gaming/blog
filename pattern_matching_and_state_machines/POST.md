## TL;DR
How to build a template engine (using simple string interpolation), leveraging pattern matching and state machinery. Also benchmarking 'cause we want to be fast besides right.

### Why build my own templating engine? What's wrong with [EEx](https://hexdocs.pm/eex/EEx.html)?
Absolutely nothing! In fact it's probably better than the one I'm going to show here. And the same thing could also be done using [`Code.eval_string/2`](https://hexdocs.pm/elixir/Code.html#eval_string/3). The only problem is that the templates in our existing CMS contain `{placeholders}` waiting to be replaced, and changing the habits of internal users (ie forcing them to use `<%= %>`) is more trouble than it's worth for something like this.

### Right. Show me what the [porcelain](https://stackoverflow.com/questions/6976473/what-does-the-term-porcelain-mean-in-git) looks like.
```elixir
#usage example
iex> Formatter.format("Hello {name}, wanna play?", name: "George")
"Hello George, wanna play?"
```
#### Ruleset
- The idea is to replace `{placeholder}`s like `{name}` above with a matching parameter name.
- `{{` and `}}` are escape sequences and will result in a `{` or `}` character in the output.
- escaped braces after an opening brace are part of the placeholder. For example to replace the following sequence `{nam}}e}` the program will look for a parameter named `nam}e`
- If no replacement parameter is found for a placeholder the placeholder is printed back in the output verbatim
- no regexes! They tend to be slow and we should reserve them for quick and dirty scripts; i.e. not in library code
- the code should never throw! It is a best effort approach, since the text is written by humans

### How do I start?
By looking at what other people have done before of course! I find state machines pretty easy to wrap my head around and there is such an implementation [here](http://haacked.com/archive/2009/01/14/named-formats-redux.aspx/) already (HenriFormatter). It is of course in `C#`, but the general idea is the same. And since we're doing elixir we can avoid the `switch/case` statement completely ;)

#### Modeling
Our state machine will effectively have 2 states:

- we're either reading text outside a `{placeholder}` which will be printing back the characters it just read, or
- we've read an opening brace (`{`) and we're now reading the name of the placeholder until a closing brace (`}`) is found. Once `}` is found we will evaluate the holder and print the result in the output.

```elixir
#using the word 'status' instead of state because state tends to have a different meaning in elixir-speak
@status_normal :normal
@status_reading_placeholder :reading_placeholder
```

#### Show me the codes
```elixir
#entry point
def format(string, params) when is_binary(string) do
  #convert atom params into strings upfront to speed up lookups later
  normalized_params = normalize_params(params)
  do_format(string, normalized_params, "", @status_normal, nil)
end

#signature: do_format(input_string, params, output, status, placeholder)

#if at the end of the string just return the formatted text (output)
defp do_format("", _, formatted, _, nil), do: formatted
#if at the input's end but the last placeholder isn't
#closed return the formatted output and that part of the placeholder
defp do_format("", _, formatted, _, remaining),
  do: formatted <> "{" <> remaining
#if an escaped brace is encountered while reading the placeholder
#add the brace to the placeholder's name
defp do_format("{{" <> rest, params, formatted, @status_reading_placeholder = status, placeholder) do
  do_format(rest, params, formatted, status, placeholder <> "{")
end
#if an escaped brace is encountered while reading regular text
#just add the brace to the output
defp do_format("{{" <> rest, params, formatted, status, placeholder) do
  do_format(rest, params, formatted <> "{", status, placeholder)
end
#if an escaped brace is encountered while reading the placeholder
#add the brace to the placeholder's name
defp do_format("}}" <> rest, params, formatted, @status_reading_placeholder = status, placeholder) do
  do_format(rest, params, formatted, status, placeholder <> "}")
end
#if an escaped brace is encountered while reading regular text
#just add the brace to the output
defp do_format("}}" <> rest, params, formatted, status, placeholder) do
  do_format(rest, params, formatted <> "}", status, placeholder)
end
#if a single opening brace is encountered while reading regular
#text transition to 'reading_placeholder' status
defp do_format("{" <> rest, params, formatted, @status_normal, _) do
  do_format(rest, params, formatted, @status_reading_placeholder, "")
end
#if a single closing brace is encountered while reading the
#placeholder name, evaluate the placeholder, add the result
#to output and transtion to 'normal' status
defp do_format("}" <> rest, params, formatted, @status_reading_placeholder, placeholder) do
  evaled = eval_holder(placeholder, params)
  do_format(rest, params, formatted <> evaled, @status_normal, nil)
end
#any byte read after an opening brace is a part of the placeholders name
defp do_format(<<x :: binary-size(1), rest :: binary>>, params, formatted, @status_reading_placeholder, placeholder) do
  do_format(rest, params, formatted, @status_reading_placeholder, placeholder <> x)
end
#any byte read before opening a brace is added back to the output
defp do_format(<<x :: binary-size(1), rest :: binary>>, params, formatted, status, placeholder) do
  do_format(rest, params, formatted <> x, status, placeholder)
end
```
... And that's it! A fun little exercise to flex the muscles.

### Execution speed
-Is it fast?<br>
-Who knows? You'd need to benchmark!<br>
-Benchmark against what?<br>
-Oh. Right.<br>

We've got ourselves a problem: we don't know if our solution is any fast. By looking at the code above 2 things jump straight out:

- **too many strings** We are creating and modifying strings with every byte we parse: When pattern matching the input and when appending to the output. And if there's something I've learned these years is that too many strings spoil the broth
- **appending to binaries instead of nesting in iolists** The [general advice](https://www.bignerdranch.com/blog/elixir-and-io-lists-part-1-building-output-efficiently/) is to [avoid binary concatenation](https://fau.re/blog/20120710_erlang_string_concat.html) and [stick with iolists](https://stackoverflow.com/questions/42834714/efficiency-of-io-lists-in-elixir-erlang). **But** there is also [strong evidence](http://erlang.org/doc/efficiency_guide/binaryhandling.html) that string concatenation might not be as bad as everyone makes it out to be.

#### Switching to iolists
To test out our second hypothesis we'll create an implementation that nests iolists instead of appending. And we will add an option to leave the output as is (iolist) or convert to a binary. The [changes](https://github.com/StoiximanServices/blog/blob/master/pattern_matching_and_state_machines/lib/string_formatter_iolist.ex) are nothing special: whenever we see `a <> b` in the code we replace it with `[a, b]`.

#### Avoiding string allocations
To see if string allocations are an actual problem we switch to a different strategy:
We will attempt to split on the braces with a left and a right part (which should lead to larger string blocks and thus fewer allocations). The [`String.split/3`](https://hexdocs.pm/elixir/String.html#split/3) function looks like it's exactly what we need... except it only returns the parts left and right of the brace, without the actual brace that was matched (we need to know whether it's an opening or a closing brace for state transitions)

Since `{` and `}` are ASCII characters and their bit sequence will not show up in any other byte (utf8 backwards compatibility assures us of that), we can try to split the incoming utf8 at the byte level (which should be fast- but we will benchmark just to be on the safe side). And [binary_part/3](https://hexdocs.pm/elixir/Kernel.html#binary_part/3) looks exactly what the doctor ordered. We go ahead then and create a `split/1` function. This is what the first attempt looks like
```elixir
def split(string), do: do_split(string, string, 0)

defp do_split("", string, _), do: [string, "", ""]
defp do_split(<<x::binary-size(1), rest::binary>>, orig, idx)
when x == "{" or x == "}"
do
  [binary_part(orig, 0, idx), x, rest]
end
defp do_split(<<_x::binary-size(1), rest::binary>>, orig, idx), do: do_split(rest, orig, idx + 1)
```

The formatting code is the modified accordingly to expect `[left, brace, right]` results, like this:
```elixir
defp do_format([left, "{", right], params, @status_normal, formatted, placeholder) do
  right
  |> split()
  |> do_format(params, @status_reading_placeholder, [formatted, left], placeholder)
end
```

Unfortunately the `split/1` function above misses the mark: we are still pattern matching on each character which allocates single byte strings, even if at the end we return 2 big chunks. We need to do better. Like [asking for help on stackoverflow](https://stackoverflow.com/questions/44112857). Thanks to [@Dogbert](https://stackoverflow.com/users/320615/dogbert) we have a much better split function we can try that will avoid intermediate allocations
```elixir
def split(string) do
  case :binary.match(string, ["{", "}"]) do
    {start, length} ->
      <<a::binary-size(start), b::binary-size(length), c::binary>> = string
      [a, b, c]
    :nomatch -> [string, "", ""]
  end
end
```

### Benchmark time
Everything is now in place and it's time we saw what's fast and what's not.
#### Benchmark setup
We load a
[large text file](https://github.com/StoiximanServices/blog/blob/master/pattern_matching_and_state_machines/benchmark/text.txt) (300KB) from disk into memory, which contains lot's of *lorem ipsum* wisdom. There are also ~2900 placeholders between words that need to be replaced (p1-p3). Then we define the [benchmarking code](https://github.com/StoiximanServices/blog/blob/master/pattern_matching_and_state_machines/benchmark/run.exs) using [benchee](https://github.com/PragTob/benchee).

#### What are we measuring?
We are measuring the entire workflow: given a binary and some parameters, normalize the parameters and scan the text for placeholders to replace. This means that we do not test the parsing code in isolation (because we need to see how the code performs end to end).
On the other hand normalization and key lookup in the placeholders map for to get the replacements should be much cheaper than the text processing and will only contribute by a negligible percentage to overall execution time. We also test each formatter that uses iolists twice: once where the final output is returned as iolist (raw) and once when converted to binary using [`IO.iodata_to_binary/1`](https://hexdocs.pm/elixir/IO.html#iodata_to_binary/1)

#### Show us the results already!
The following were obtained on a windows 10 machine using an i7-7700 and 32GB RAM
```
formatter            iterations/second
------------------------------------------
dogbert2             163.08
dogbert1             161.99 - 1.01x slower
dogbert2->bin        155.01 - 1.05x slower
dogbert1->bin        153.05 - 1.07x slower
split1->bin           68.98 - 2.36x slower
split1                68.58 - 2.38x slower
io_list naive         61.20 - 2.66x slower
bin_concat naive      52.84 - 3.09x slower
io_list naive->bin    23.93 - 6.82x slower
```
#### Analyzing the results
- iolists are indeed faster than binary concatenation. But if we need to convert the final output to binary, then the naive case becomes 2x slower than appending to binaries in the first place.
- the first version of the `split/1` is underperforming as expected, being only marginally better than the naive iolist approach.
- Using any of the splitting functions and then converting the output to a binary (instead of leaving it as iolist) is not affecting the performance of the formatter, presumably because the iolists built are not as deep as in the naive iolist solution.
- finally the splitting function that @dogbert proposed is much faster than everything else, and the [second variation](https://github.com/StoiximanServices/blog/blob/master/pattern_matching_and_state_machines/lib/string_formatter_split.ex#L94) slightly outperforms the first.

### Wrapping up
We built a nice little parser for ourselves and have relearned an important lesson:
allocating and manipulating strings in elixir harms the performance just like in every other language/vm out there. Even though elixir makes working with strings much more fun, string manipulation basics are still in effect.

All code is on [github](https://github.com/StoiximanServices/blog/tree/master/pattern_matching_and_state_machines).
Happy coding!
