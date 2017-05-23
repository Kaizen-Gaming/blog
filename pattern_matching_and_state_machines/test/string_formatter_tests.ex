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
        ret = "Hello {name}" |> Formatter.format(name: "George")
        assert "Hello George" == ret
      end

      test "format with string tuples" do
        ret = "Hello {name}" |> Formatter.format([{"name", "George"}])
        assert "Hello George" == ret
      end

      test "format with atom keys in map" do
        ret = "Hello {name}" |> Formatter.format(%{name: "George"})
        assert "Hello George" == ret
      end

      test "format with string keys in map" do
        ret = "Hello {name}" |> Formatter.format(%{"name" => "George"})
        assert "Hello George" == ret
      end

      test "format with more than one placeholders" do
        ret = "Hello {address} {name}" |> Formatter.format(name: "George", address: "mr")
        assert "Hello mr George" == ret
      end

      test "format with recurring placeholder" do
        ret = "Hi {name}, my name is {name} as well" |> Formatter.format(name: "George")
        assert "Hi George, my name is George as well" == ret
      end

      test "missing placeholder gets printed back" do
        ret = "Hi {address} {name}" |> Formatter.format(name: "George")
        assert "Hi {address} George" == ret
      end

      test "placeholder escaping works as expected" do
        ret =
          "'Hi {{name}}' is the text to be formatted using {name} inplace of {{name}}"
          |> Formatter.format(name: "George")
        assert "'Hi {name}' is the text to be formatted using George inplace of {name}" == ret
      end

      test "badly formatter placeholder" do
        ret =
          "Hello {name"
          |> Formatter.format(name: "George")
        assert "Hello {name" == ret
      end

      test "no placeholders in string" do
        ret =
          "Hello everyone"
          |> Formatter.format(name: "George")
        assert "Hello everyone" == ret
      end

      test "placeholders with escape sequence" do
        ret =
          "Hello {name}}}, I'm {other{{name}"
          |> Formatter.format(%{"name}" => "George", "other{name" => "Zack"})
        assert "Hello George, I'm Zack" == ret
      end
    end
  end

end
