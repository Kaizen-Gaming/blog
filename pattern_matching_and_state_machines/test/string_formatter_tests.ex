defmodule StringFormatterTests do

  @moduledoc """
  Contains test cases common to all formatters
  """

  defmacro __using__(formatter: formatter) do
    quote location: :keep do
      use ExUnit.Case, async: true

      alias unquote(formatter), as: Formatter

      test "format empty string" do
        ret = "" |> Formatter.format([])
        assert "" == ret
      end

      test "format with keyword list" do
        ret = "Hello {name}" |> Formatter.format(name: "Alekos")
        assert "Hello Alekos" == ret
      end

      test "format with string tuples" do
        ret = "Hello {name}" |> Formatter.format([{"name", "Alekos"}])
        assert "Hello Alekos" == ret
      end

      test "format with atom keys in map" do
        ret = "Hello {name}" |> Formatter.format(%{name: "Alekos"})
        assert "Hello Alekos" == ret
      end

      test "format with string keys in map" do
        ret = "Hello {name}" |> Formatter.format(%{"name" => "Alekos"})
        assert "Hello Alekos" == ret
      end

      test "format with more than one placeholders" do
        ret = "Hello {address} {name}" |> Formatter.format(name: "Alekos", address: "mr")
        assert "Hello mr Alekos" == ret
      end

      test "format with recurring placeholder" do
        ret = "Hi {name}, my name is {name} as well" |> Formatter.format(name: "Alekos")
        assert "Hi Alekos, my name is Alekos as well" == ret
      end

      test "missing placeholder gets printed back" do
        ret = "Hi {address} {name}" |> Formatter.format(name: "Alekos")
        assert "Hi {address} Alekos" == ret
      end

      test "placeholder escaping works as expected" do
        ret =
          "'Hi {{name}}' is the text to be formatted using {name} inplace of {{name}}"
          |> Formatter.format(name: "Alekos")
        assert "'Hi {name}' is the text to be formatted using Alekos inplace of {name}" == ret
      end
    end
  end

end
