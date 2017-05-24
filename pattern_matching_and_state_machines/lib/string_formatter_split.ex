defmodule StringFormatterSplit do
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
    split_func = opts[:splitter] || &__MODULE__.split_1/1
    string
    |> split_func.()
    |> do_format(normalized_params, split_func, @status_normal, [], [])
    |> flush(opts)
  end

  defp do_format([left, "", _], _, _, @status_normal, formatted, _), do: [formatted, left]
  defp do_format([left, "", _], _, _, @status_reading_placeholder, formatted, placeholder), do: [formatted, "{", placeholder, left]

  defp do_format([left, "{", "{" <> right], params, split_func, @status_reading_placeholder = status, formatted, placeholder) do
    right
    |> split_func.()
    |> do_format(params, split_func, status, formatted, [placeholder, left, "{"])
  end

  defp do_format([left, "{", "{" <> right], params, split_func, status, formatted, placeholder) do
    right
    |> split_func.()
    |> do_format(params, split_func, status, [formatted, left, "{"], placeholder)
  end

  defp do_format([left, "}", "}" <> right], params, split_func, @status_reading_placeholder = status, formatted, placeholder) do
    right
    |> split_func.()
    |> do_format(params, split_func, status, formatted, [placeholder, left, "}"])
  end

  defp do_format([left, "}", "}" <> right], params, split_func, status, formatted, placeholder) do
    right
    |> split_func.()
    |> do_format(params, split_func, status, [formatted, left, "}"], placeholder)
  end

  defp do_format([left, "{", right], params, split_func, @status_normal, formatted, placeholder) do
    right
    |> split_func.()
    |> do_format(params, split_func, @status_reading_placeholder, [formatted, left,], placeholder)
  end

  defp do_format([left, "}", right], params, split_func, @status_reading_placeholder, formatted, placeholder) do
    evaled =
      [placeholder, left]
      |> IO.iodata_to_binary()
      |> eval_holder(params)
    right
    |> split_func.()
    |> do_format(params, split_func, @status_normal, [formatted, evaled], [])
  end

  def split_1(string) do
    do_split_1(string, string, 0)
  end

  defp do_split_1("", string, _), do: [string, "", ""]
  defp do_split_1(<<x::binary-size(1), rest::binary>>, orig, idx) when x == "{" or x == "}" do
    #safe to match ascii chars {,}, see https://en.wikipedia.org/wiki/UTF-8
    #Backward compatibility: One-byte codes are used for the ASCII values 0 through 127,...
    #Bytes in this range are not used anywhere else... as it will not accidentally see those ASCII characters in the middle of a multi-byte character.
    [binary_part(orig, 0, idx), x, rest]
  end

  defp do_split_1(<<_x::binary-size(1), rest::binary>>, orig, idx) do
    do_split_1(rest, orig, idx + 1)
  end

  #https://stackoverflow.com/a/44120981/289992
  def split_2(binary) do
    case :binary.match(binary, ["{", "}"]) do
      {start, length} ->
        before = :binary.part(binary, 0, start)
        match = :binary.part(binary, start, length)
        after_ = :binary.part(binary, start + length, byte_size(binary) - (start + length))
        [before, match, after_]
      :nomatch -> [binary, "", ""]
    end
  end

  def split_3(string) do
    case :binary.match(string, ["{", "}"]) do
      {start, length} ->
        <<a::binary-size(start), b::binary-size(length), c::binary>> = string
        [a, b, c]
      :nomatch -> [string, "", ""]
    end
  end

  defp flush(io_data, opts) do
    case opts[:io_lists] do
      true -> io_data
      _ -> IO.iodata_to_binary(io_data)
    end
  end
end
