defmodule Actor do
  use GenServer
    
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end


end





defmodule GOSSIP do

  @moduledoc """
  Documentation for GOSSIP.
  """

  @doc """
  Hello world.

  ## Examples

      iex> GOSSIP.hello
      :world

  """
  def createAgents(numNodes, pids) when numNodes = 0 do
    pids
  end

  def createAgents(numNodes, pids) do
    {:ok, pid} = Actor.start_link()
    createAgents(numNodes-1, pids | pid)
  end

  
  def createFullTopology(agents, algorithm, remAgents) when remAgents = [] do

  end

  def createFullTopology(agents, algorithm, remAgents) do
    [head | tail] = remAgents
    neighbors = agents -- [head]
    Actor.setNeighbors(head, {neighbors, algorithm})
    createFullTopology(agents, algorithm, tail)
  end
  
  def getNthNode(agentsList, cur) when cur = 0 do
    [head | tail] = agentsList
    head
  end

  def getNthNode(agentsList, cur) do
    [head | tail] = agentsList
    getNthNode(tail, cur-1)
  end

  def create2D(agents, algorithm, cur, numNodes) when cur = numNodes do
    
  end

  def create2D(agents, algorithm, cur, numNodes) do
    curNode = getNthNode(agents, cur)
    neighbors = []
    sq = :math.sqrt(numNodes)
    x = cur/sq
    y = cur%sq
    
    if (x+1 <  sq) do
      neighbors = neighbors ++ [getNthNode(agents, (x+1)*sq+y)]
    end

    if (y+1 <  sq) do
      neighbors = neighbors ++ [getNthNode(agents, x*sq+(y+1))]
    end

    if (x-1 >= 0) do
      neighbors = neighbors ++ [getNthNode(agents, (x-1)*sq+y)]
    end

    if (y-1 >=  0) do
      neighbors = neighbors ++ [getNthNode(agents, x*sq+(y-1))]
    end

    Actor.setNeighbors(curNode, {neighbors, algorithm})
    create2D(agents, algorithm, cur+1, numNodes)
  end

  def getRandomForNode(x, y, sq) do
    a = :rand.uniform(sq)
    b = :rand.uniform(sq)
    case {a,b} do
      {x, y} -> getRandomForNode(x, y, sq)
      {x-1, y} -> getRandomForNode(x, y, sq)
      {x, y-1} -> getRandomForNode(x, y, sq)
      {x+1, y} -> getRandomForNode(x, y, sq)
      {x, y+1} -> getRandomForNode(x, y, sq)
      _ -> x*sq+y
    end
  end

  def createImp2D(agents, algorithm, cur, numNodes) when cur = numNodes do
    
  end

  def createImp2D(agents, algorithm, cur, numNodes) do
    curNode = getNthNode(agents, cur)
    neighbors = []
    sq = :math.sqrt(numNodes)
    x = cur/sq
    y = cur%sq
    
    if (x+1 <  sq) do
      neighbors = neighbors ++ [getNthNode(agents, (x+1)*sq+y)]
    end

    if (y+1 <  sq) do
      neighbors = neighbors ++ [getNthNode(agents, x*sq+(y+1))]
    end

    if (x-1 >= 0) do
      neighbors = neighbors ++ [getNthNode(agents, (x-1)*sq+y)]
    end

    if (y-1 >=  0) do
      neighbors = neighbors ++ [getNthNode(agents, x*sq+(y-1))]
    end

    neighbors = neighbors ++ [getNthNode(agents, getRandomForNode(x,y,sq)]
    Actor.setNeighbors(curNode, {neighbors, algorithm})
    create2D(agents, algorithm, cur+1, numNodes)
  end

  def getNearestSquare(cur, numNodes) do
    if (cur*cur >= numNodes) do
      (cur*cur)
    else
      getNearestSquare(cur+1, numNodes)
    end
  end

  def createLine(algorithm, prev, remAgents) do
    [cur | tail] = remAgents
    if tail == [] do
      
    else
      [next | tmpTail] = tail
      neighbors = prev ++ [next]
      Actor.setNeighbors(cur, {neighbors, algorithm})
      createLine(algorithm, [cur], tail)
    end
  end


  def start(numNodes, topology, algorithm) do
    if (topology == "2D" || topology == "imp2D") do
      numNodes = getNearestSquare(cur, numNodes)
    end

    agents = createAgents(numNodes, [])
    case topology do
      "Full" -> createFullTopology(agents, algorithm, agents)
      "2D" -> create2D(agents, algorithm, 0, numNodes)
      "line" -> createLine(agents, algorithm, [], agents)
      "imp2D" -> createImp2D(agents, algorithm, 0, numNodes)
    end

    pid = getRandom(agents)
    Actor.sendGossip(pid, {0,0})
  end
end
