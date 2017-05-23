text = File.read!("benchmark/text.txt")

params = %{
  "p1" => "felis, volutpat ac est eu, congue commodo",
  "p2" => "Ut diam lectus, maximus sit amet lacus",
  "p3" => "Donec vestibulum efficitur odio"
}


Benchee.run(%{
  "bin_concat" => fn -> StringFormatterConcat.format(text, params) end,
  "io_list"    => fn -> StringFormatterIolist.format(text, params) end,
  "split1"     => fn -> StringFormatterSplit.format(text, params, [splitter: &StringFormatterSplit.split_1/1]) end,
  "split2"     => fn -> StringFormatterSplit.format(text, params, [splitter: &StringFormatterSplit.split_2/1]) end,
  "split3"     => fn -> StringFormatterSplit.format(text, params, [splitter: &StringFormatterSplit.split_3/1]) end,
})
