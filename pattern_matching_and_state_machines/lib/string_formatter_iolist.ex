defmodule StringFormatterIolist do
  @moduledoc """
  A module used to evaluate {placeholders} in strings given a list of params
  """

  import StringFormatterUtils, only: [normalize_params: 1, eval_holder: 2]

  @status_normal :normal
  @status_reading_placeholder :reading_placeholder

  @doc """
  Format a string with placeholders. Missing placeholders will be printed back
  in the formatted text
  """
  def format(string, params, opts \\ []) when is_binary(string) do
    normalized_params = normalize_params(params)
    do_format(string, normalized_params, [], @status_normal, nil)
    |> flush(opts)
  end

  defp do_format("", _, formatted, _, nil), do: formatted
  defp do_format("", _, formatted, _, remaining), do: [formatted, "{", remaining]

  defp do_format("{{" <> rest, params, formatted, @status_reading_placeholder = status, placeholder) do
    do_format(rest, params, formatted, status, [placeholder, "{"])
  end

  defp do_format("{{" <> rest, params, formatted, status, placeholder) do
    do_format(rest, params, [formatted, "{"], status, placeholder)
  end

  defp do_format("}}" <> rest, params, formatted, @status_reading_placeholder = status, placeholder) do
    do_format(rest, params, formatted, status, [placeholder, "}"])
  end

  defp do_format("}}" <> rest, params, formatted, status, placeholder) do
    do_format(rest, params, [formatted, "}"], status, placeholder)
  end

  defp do_format("{" <> rest, params, formatted, @status_normal, _) do
    do_format(rest, params, formatted, @status_reading_placeholder, [])
  end

  defp do_format("}" <> rest, params, formatted, @status_reading_placeholder, placeholder) do
    evaled =
      placeholder
      |> IO.iodata_to_binary()
      |> eval_holder(params)
    do_format(rest, params, [formatted, evaled], @status_normal, nil)
  end

  defp do_format(<<x :: binary-size(1), rest :: binary>>, params, formatted, @status_reading_placeholder, placeholder) do
    do_format(rest, params, formatted, @status_reading_placeholder, [placeholder, x])
  end

  defp do_format(<<x :: binary-size(1), rest :: binary>>, params, formatted, status, placeholder) do
    do_format(rest, params, [formatted, x], status, placeholder)
  end

  defp flush(io_data, opts) do
    case opts[:io_lists] do
      true -> io_data
      _ -> IO.iodata_to_binary(io_data)
    end
  end

end
