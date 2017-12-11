defmodule ClientmoduleTest do
  use ExUnit.Case
  doctest Clientmodule

  test "greets the world" do
    assert Clientmodule.hello() == :world
  end
end
