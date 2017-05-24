text = File.read!("benchmark/text.txt")

params = %{
  "p1" => "felis, volutpat ac est eu, congue commodo",
  "p2" => "Ut diam lectus, maximus sit amet lacus",
  "p3" => "Donec vestibulum efficitur odio"
}


Benchee.run(%{
  "bin_concat naive"   => fn -> StringFormatterConcat.format(text, params) end, #binary concatenation

  "io_list naive"  => fn -> StringFormatterIolist.format(text, params, io_lists: true) end, #returns raw io lists
  "io_list naive->bin" => fn -> StringFormatterIolist.format(text, params) end, #converts io_lists to a final binary

  #first attempt at splitting
  "split1"   => fn -> StringFormatterSplit.format(text, params, splitter: &StringFormatterSplit.split_1/1, io_lists: true) end,
  "split1->bin"  => fn -> StringFormatterSplit.format(text, params, splitter: &StringFormatterSplit.split_1/1) end,

  #dogbert splitting
  "dogbert1"   => fn -> StringFormatterSplit.format(text, params, splitter: &StringFormatterSplit.split_2/1, io_lists: true) end,
  "dogbert1->bin"  => fn -> StringFormatterSplit.format(text, params, splitter: &StringFormatterSplit.split_2/1) end,

  #dogbert splitting (2nd variation)
  "dogbert2"   => fn -> StringFormatterSplit.format(text, params, splitter: &StringFormatterSplit.split_3/1, io_lists: true) end,
  "dogbert2->bin"  => fn -> StringFormatterSplit.format(text, params, splitter: &StringFormatterSplit.split_3/1) end,
})
