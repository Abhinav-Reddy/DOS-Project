defmodule Actor do
  use GenServer
    
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def handle_cast({neighbors, algorithm, mainProcess, curPos}, state) do
    receiveGossip(neighbors, algorithm, mainProcess, curPos, 1, 0)
  end

  def setNeighbors(pid, {neighbors, algorithm, mainProcess, curPos}) do
    GenServer.cast(pid, {neighbors, algorithm, mainProcess, curPos})
  end

  def receiveGossip(neighbors, algorithm, mainProcess, sum, weight, count) do
    receive do
      {:push, s,w} ->
        if (count < 3) do
          prevSum = sum
          prevWeight = weight
          sum = sum + s
          weight = weight + w
          if (abs(prevSum/prevWeight - sum/weight) <= 0.0000000001)
            count = count + 1
          else
            count = 0
          pid = getRandom(neighbors, -1, 0)
          send(pid, {:push, sum/2, weight/2})
          
        end
        receiveGossip(neighbors, algorithm, mainProcess, sum/2, weight/2, count)
      {:gossip} ->
        if (count < 10) do
          pid = getRandom(neighbors, -1, 0)
          send(pid, {:gossip})
        end
        receiveGossip(neighbors, algorithm, mainProcess, sum, weight, count+1)
    end
  end

end


defmodule GOSSIP do

  def createAgents(numNodes, pids) when numNodes = 0 do
    pids
  end

  def createAgents(numNodes, pids) do
    {:ok, pid} = Actor.start_link()
    createAgents(numNodes-1, pids ++ [pid])
  end

  
  def createFullTopology(agents, algorithm, remAgents, curPos) when remAgents = [] do

  end

  def createFullTopology(agents, algorithm, remAgents, curPos) do
    [head | tail] = remAgents
    neighbors = agents -- [head]
    Actor.setNeighbors(head, {neighbors, algorithm, self(), curPos})
    createFullTopology(agents, algorithm, tail, curPos+1)
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

    Actor.setNeighbors(curNode, {neighbors, algorithm, self(), cur+1})
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
    Actor.setNeighbors(curNode, {neighbors, algorithm, self(), cur+1})
    create2D(agents, algorithm, cur+1, numNodes)
  end

  def getNearestSquare(cur, numNodes) do
    if (cur*cur >= numNodes) do
      (cur*cur)
    else
      getNearestSquare(cur+1, numNodes)
    end
  end

  def createLine(algorithm, prev, remAgents, curPos) do
    [cur | tail] = remAgents
    if tail == [] do
      
    else
      [next | tmpTail] = tail
      neighbors = prev ++ [next]
      Actor.setNeighbors(cur, {neighbors, algorithm, self(), curPos})
      createLine(algorithm, [cur], tail, curPos+1)
    end
  end


  def getRandom(nodes, cur, len) when nodes = [] do
    cur
  end

  def getRandom(nodes, cur, len) do
    [head | tail] = nodes
    if (:rand.uniform(len) == len) do
      cur = head
    end
    getRandom(tail, cur, len+1)
  end

  def start(numNodes, topology, algorithm) do
    if (topology == "2D" || topology == "imp2D") do
      numNodes = getNearestSquare(cur, numNodes)
    end

    agents = createAgents(numNodes, [])
    case topology do
      "Full" -> createFullTopology(agents, algorithm, agents, 1)
      "2D" -> create2D(agents, algorithm, 0, numNodes)
      "line" -> createLine(agents, algorithm, [], agents, 1)
      "imp2D" -> createImp2D(agents, algorithm, 0, numNodes)
    end
    cur = :os.system_time(:millisecond)
    pid = getRandom(agents, -1, 0)
    if (algorithm == "gossip") do
      send(pid, {:gossip})
    else
      send(pid, {:push, 0,0})  
    end
    IO.puts (:os.system_time(:millisecond) - cur)
  end
end
