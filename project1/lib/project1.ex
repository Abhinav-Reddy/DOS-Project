defmodule Project1 do

  # use Mix.Task
  @moduledoc """
  Documentation for Project1.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Project1.hello
      :world

  """
  def get_matching_String(num, s) do

    if(hash_code_match(s,1,num)) do
      IO.puts "HashCode Matched"
      IO.puts s <> <<num::utf8>>

    else
        get_matching_String(num+1, s)

    end

  end

  def hash_code_match(s, zero_count, num) do
    zero_String = String.duplicate("0", zero_count)
    check_str = s <> <<num::utf8>>
    a =  Base.encode16(:crypto.hash(:sha256, check_str))
    val = String.starts_with? a, zero_String
    IO.puts "String is " <> check_str
    IO.puts val
    val
  end

  def run() do

    s = "amineni95:"

    get_matching_String(32, s)
    
  end

end
