defmodule Project4clientTest do
  use ExUnit.Case
  doctest Project4client

  test "greets the world" do
    assert Project4client.hello() == :world
  end
end
