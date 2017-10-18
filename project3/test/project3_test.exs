defmodule PASTRYTest do
  use ExUnit.Case
  doctest PASTRY

  test "greets the world" do
    assert PASTRY.hello() == :world
  end
end
