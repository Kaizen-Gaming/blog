defmodule StringFormatterV2 do
  @moduledoc """
  A module used to evaluate {placeholders} in strings given a list of params
  """

  import StringFormatterUtils, only: [normalize_params: 1, eval_holder: 2]

  @state_normal :normal
  @state_reading_placeholder :reading_placeholder

  @doc """
  Format a string with placeholders. Missing placeholders will be printed back
  in the formatted text
  """
  def format(string, params) when is_binary(string) do
    normalized_params = normalize_params(params)
    do_format(string, normalized_params, [], @state_normal, nil)
  end

  defp do_format("", _, formatted, _, nil), do: formatted |> IO.iodata_to_binary()
  defp do_format("", _, formatted, _, remaining), do: [formatted, "{", remaining] |> IO.iodata_to_binary()

  defp do_format("{{" <> rest, params, formatted, state, placeholder) do
    do_format(rest, params, [formatted, "{"], state, placeholder)
  end

  defp do_format("}}" <> rest, params, formatted, state, placeholder) do
    do_format(rest, params, [formatted, "}"], state, placeholder)
  end

  defp do_format("{" <> rest, params, formatted, @state_normal, _) do
    do_format(rest, params, formatted, @state_reading_placeholder, [])
  end

  defp do_format("}" <> rest, params, formatted, @state_reading_placeholder, placeholder) do
    evaled =
      placeholder
      |> IO.iodata_to_binary()
      |> eval_holder(params)
    do_format(rest, params, [formatted, evaled], @state_normal, nil)
  end

  defp do_format(<<x :: binary-size(1), rest :: binary>>, params, formatted, @state_reading_placeholder, placeholder) do
    do_format(rest, params, formatted, @state_reading_placeholder, [placeholder, x])
  end

  defp do_format(<<x :: binary-size(1), rest :: binary>>, params, formatted, state, placeholder) do
    do_format(rest, params, [formatted, x], state, placeholder)
  end

end
