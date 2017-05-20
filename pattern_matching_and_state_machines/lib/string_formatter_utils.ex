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

end
