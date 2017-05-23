defmodule StringFormatterUtils do
  @moduledoc """
  Contains various helper methods to avoid duplicating the stuff all over
  """

  @doc """
  Transforms a map or a keyword list into a new map
  where all keys are strings
  """
  def normalize_params(params) do
    params
    |> Enum.map(fn {key, val} -> {to_string(key), val} end)
    |> Enum.into(%{})
  end

  @doc """
  Evaluates the given placeholder by looking up its value
  in the params map. Returns {placeholder} if nothing found
  """
  def eval_holder(placeholder, params) do
    case params[placeholder] do
      nil -> "{#{placeholder}}"
      other -> to_string(other)
    end
  end


  def split_1(string) do
    do_split(string, string, 0)
  end

  defp do_split("", string, _), do: [string, "", ""]
  defp do_split(<<x::binary-size(1), rest::binary>>, orig, idx) when x == "{" or x == "}" do
    #safe to match ascii chars {,}, see https://en.wikipedia.org/wiki/UTF-8
    #Backward compatibility: One-byte codes are used for the ASCII values 0 through 127,...
    #Bytes in this range are not used anywhere else... as it will not accidentally see those ASCII characters in the middle of a multi-byte character.
    [binary_part(orig, 0, idx), x, rest]
  end

  defp do_split(<<_x::binary-size(1), rest::binary>>, orig, idx) do
    do_split(rest, orig, idx + 1)
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
end
