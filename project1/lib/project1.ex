
defmodule Actor do
  use GenServer
    
  def hash_code_match(check_str, zero_count) do
    zero_String = String.duplicate("0", zero_count)
    a =  Base.encode16(:crypto.hash(:sha256, check_str))
    val = String.starts_with? a, zero_String
    #IO.puts a
    #IO.puts "String is " <> check_str
    #IO.puts val
    {val, check_str, a}
  end

  def gen_strings(str, k, cur, zero_count) when k == 0 do
    hash_code_match(str, zero_count)
  end

  def gen_strings(str, k, cur, zero_count) when (cur > 125) do
      {:false, str, ""}
  end

  def gen_strings(str, k, cur, zero_count) do
      {found, res, hash} = gen_strings(str <> <<cur::utf8>>, k-1, 33, zero_count)
      if (found == :false) do
        gen_strings(str, k, cur+1, zero_count)
      else
        {found, res, hash}
      end
  end
  
  def handle_cast({:process, client, str, k, zero_count}, state) do
    {found, res, hash} = gen_strings(str, k, 33, zero_count)
    if (found == :true) do
      IO.puts found
      IO.puts res
      IO.puts hash
      send(client, {found, res})
      {:noreply, []}
    else
      handle_cast({:process, client, str, k-1, zero_count}, state)
    end
  end

  def process(pid, {:process, client, str, k, zero_count}) do
      GenServer.cast(pid, {:process, client, str, k, zero_count})
  end
  
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

end