defmodule StringFormatterV3 do
  @moduledoc """
  A module used to evaluate {placeholders} in strings given a list of params
  """

  import StringFormatterUtils, only: [normalize_params: 1, eval_holder: 2]

  @doc """
  Format a string with placeholders. Missing placeholders will be printed back
  in the formatted text
  """
  def format(string, params) when is_binary(string) do
    normalized_params = normalize_params(params)
    string
    |> split("{")
    |> do_format(normalized_params, [])
  end

  defp do_format([h], _, formatted), do: [formatted, h] |> IO.iodata_to_binary()

  defp do_format([h, "{" <> t], params, formatted) do
    #escape sequence
    t
    |> split("{")
    |> do_format(params, [formatted, h, "{"])
  end

  defp do_format([h, t], params, formatted) do
    #reading placeholder
    {param, rest} = eval_param(t, params)
    rest
    |> split("{")
    |> do_format(params, [formatted, h, param])
  end

  defp eval_param(string, params) do
    string
    |> split("}")
    |> eval_param(params, [])
  end

  defp eval_param([h], _, []) do
    #placeholder end not found
    {["{", h], ""}
  end

  defp eval_param([h], _, param) do
    #placeholder end not found
    {[h, "{", param], ""}
  end

  defp eval_param([h, "}" <> t], params, []) do
    t
    |> split("}")
    |> eval_param(params, [h, "}"])
  end

  defp eval_param([h, t], params, param) do
    val =
      [param, h]
      |> IO.iodata_to_binary()
      |> eval_holder(params)
    {val, t}
  end

  defp split(string, sep), do: String.split(string, sep, parts: 2)
end
