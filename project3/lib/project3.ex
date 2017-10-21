
defmodule Actor do
  
  def updateRow(destination, _, res) when destination == [] do
    Enum.reverse(res)
  end

  def updateRow(destination, source, res) do
    tmp = if (hd(destination) != :null) do
            hd(destination)
          else
            hd(source)
          end
    updateRow(tl(destination), tl(source), [tmp | res])
  end

  def updateRouteTable(routeTable, _, _, _, idx) 
    when idx >= length(routeTable)-1 do
      routeTable
  end

  def updateRouteTable(routeTable, sourceRouteTable, nodeId, sourceKey, idx) do
    tmpRow = updateRow(Enum.at(routeTable, idx), Enum.at(sourceRouteTable, idx), [])
    routeTable = List.replace_at(routeTable, idx, tmpRow)
    if (String.at(nodeId, idx) != String.at(sourceKey, idx)) do
      routeTable
    else
      updateRouteTable(routeTable, sourceRouteTable, nodeId, sourceKey, idx+1)
    end
  end

  def processLeafNodes(left, right, center, nodeId) do
    {_, pivot} = center
    if (nodeId > pivot) do
      {left,right} = if (length(left) < 8) do
                      {left, right}
                     else
                      [_ | tail] = left
                      {tail, right}
                     end
      {left ++ [center], right}
    else
      {left, right} = if (length(right) < 8) do
                        {left, right}
                      else
                        [_ | tail] = Enum.reverse(right)
                        tail = Enum.reverse(tail)
                        {left, tail}
                      end
      {left, [center | right]}
    end

  end

  def receiveRouteInfo(routeTable, nodeId, receivedFrom) do
    receive do
      {:leafNodes, left, right, pivot} ->
        {sourcePid, sourceKey} = pivot
        receivedFrom = [sourcePid | receivedFrom]
        {leftLeafs, rightLeafs} = processLeafNodes(left, right, pivot, nodeId)
        #IO.puts "Received leaf nodes from " <> sourceKey
        {routeTable, leftLeafs, rightLeafs, receivedFrom}
        

      {:routeTable, sourceRouteTable, sourcePid, sourceKey} ->
        routeTable = updateRouteTable(routeTable, sourceRouteTable, nodeId, sourceKey, 0)
        receivedFrom = [ sourcePid | receivedFrom]
        #IO.puts "Received route from " <> sourceKey
        receiveRouteInfo(routeTable, nodeId, receivedFrom)
    end
  end
  
  def getNearestFromRemLeafs(leafs, _, _, nearest) when leafs == [] do
    nearest
  end

  def getNearestFromRemLeafs(leafs, key, diff, nearest) do
    {tmpId, tmpNodeId} = Enum.at(leafs, 0)
    tmpNodeId = String.to_integer(tmpNodeId, 16)
    {diff, nearest} = if (diff > abs(key-tmpNodeId)) do
                        {abs(key-tmpNodeId), tmpId}
                      else
                        {diff, nearest}
                      end
    getNearestFromRemLeafs(tl(leafs), key, diff, nearest)
  end 

  def getNearestFromLeafs(leafs, key) do
    {tmpId, tmpNodeId} = Enum.at(leafs, 0)
    tmpNodeId = String.to_integer(tmpNodeId, 16)
    diff = abs(key - tmpNodeId)
    nearest = tmpId
    getNearestFromRemLeafs(tl(leafs), key, diff, nearest)
  end

  def compareIds(one, two, index) do
    if (String.at(one, index) == String.at(two, index)) do
      compareIds(one, two, index+1)
    else
      index
    end
  end

  def checkInRange(left, right, key) do
    {_, minNodeId} = if (left != []) do
                            Enum.at(left, 0)
                          else
                            {:null, :null}
                          end
    {_, maxNodeId} = if (right != []) do
                            Enum.at(right, -1)
                          else
                            {:null, :null}
                          end
    if (minNodeId == :null || maxNodeId == :null) do
      :null
    end

    if (minNodeId <= key && key <= maxNodeId) do
      getNearestFromLeafs(left ++ right, String.to_integer(key, 16))
    else
      :null
    end
  end

  def addLeaf(nodeList, pid, nodeId, resList) when nodeList == [] do
     resList ++ [{pid, nodeId}]
  end

  def addLeaf(nodeList, pid, nodeId, resList) do
    [head | tail] = nodeList
    {_, tmpId} = head
    if (tmpId  > nodeId) do
      resList ++ [{pid, nodeId}] ++ nodeList
    else
      addLeaf(tail, pid, nodeId, resList ++ [head]) 
    end
  end

  def addLeafNode(left, right, newPid, newNodeId, curNodeId) do
    if (curNodeId > newNodeId) do
      left = addLeaf(left, newPid, newNodeId, [])
      {left, right} = if (length(left) > 8 ) do
                        [_ | tail] = left
                        {tail, right}
                      else
                        {left, right}  
                      end
      {Enum.uniq(left), right}
    else
      right = addLeaf(right, newPid, newNodeId, [])
      {left, right} = if (length(right) <= 8) do
                        {left, right}
                      else
                        [_ | tail] = Enum.reverse(right)
                        tail = Enum.reverse(tail)
                        {left, tail}
                      end
      {left, Enum.uniq(right)}
    end
  end

  def receiveLoop(routeTable, leftLeafs, rightLeafs, curNodeId, master) do
    receive do
      {:newNode, startIndex, key, pid} ->
        #IO.puts "new node " <> curNodeId <> " " <> key
        endCount = compareIds(key, curNodeId, startIndex)
        send(pid, {:routeTable, routeTable, self(), curNodeId})
        nextHop = checkInRange(leftLeafs, [{self(), curNodeId} | rightLeafs], key)
        nextHop = if (nextHop == :null && curNodeId == key) do
                    self()
                  else
                    :null
                  end

        nextHop = if (nextHop == :null) do
                    tmpVal = String.to_integer( String.at(key, endCount), 16 )
                    Enum.at(Enum.at(routeTable, endCount), tmpVal)
                  else
                    nextHop
                  end
        nextHop = if (nextHop == :null) do
                    getNearestFromLeafs(leftLeafs ++ rightLeafs ++ [{self(), curNodeId}], 
                      String.to_integer(key, 16))
                  else
                    nextHop
                  end
        if (nextHop == self()) do
          send(pid, {:leafNodes, leftLeafs, rightLeafs, {self(), curNodeId}})
        else
          send(nextHop, {:newNode, endCount, key, pid})
        end
        receiveLoop(routeTable, leftLeafs, rightLeafs, curNodeId, master)
      {:routeTable, sourceRouteTable, senderPid, senderNodeId} ->
        routeTable = 
          updateRouteTable(routeTable, sourceRouteTable, curNodeId, senderNodeId, 0)
        {leftLeafs, rightLeafs} = addLeafNode(leftLeafs, rightLeafs, senderPid, senderNodeId, curNodeId)
        #IO.puts "route " <> curNodeId <> " " <> senderNodeId
        #IO.inspect(leftLeafs)
        #IO.inspect(rightLeafs)
        #IO.inspect(routeTable)
        receiveLoop(routeTable, leftLeafs, rightLeafs, curNodeId, master)
    end
  end

  def getNullList(len, list, _) when len == 0 do
    Enum.reverse(list)
  end

  def getNullList(len, list, tar) do
    #IO.puts tar
    if (17 - len == tar) do
      getNullList(len-1, [self() | list], tar)
    else
      getNullList(len-1, [:null | list], tar)
    end
  end

  def initRouteTable(routeTable, len, nodeId)  when len == 0 do
    routeTable
  end

  def initRouteTable(routeTable, len, nodeId) do
    routeTable = 
      [ getNullList(17, [], String.to_integer( String.at(nodeId, 32-len), 16 )) | routeTable]
    
    initRouteTable(routeTable, len-1, nodeId)
    
  end

  def sendRouteTableToLeafs(sendList, res) when sendList == [] do
    res
  end

  def sendRouteTableToLeafs(sendList, res) do
  #IO.puts length(sendList)
    [head | tail] = sendList
    {pid, _} = head
    sendRouteTableToLeafs(tail, [pid | res])
  end

  def sendRouteTable(_, sendList, _) when sendList == [] do
    
  end

  def sendRouteTable(routeTable, sendList, nodeId) do
    [pid | tail] = sendList
    send(pid, {:routeTable, routeTable, self(), nodeId})
    #:timer.sleep(200)
    sendRouteTable(routeTable, tail, nodeId)
  end

  def start(startNode, nodeNum, master) do
    nodeId = Base.encode16(:crypto.hash(:sha256, to_string(nodeNum)))
    nodeId = String.slice(nodeId, 2..33)
    #IO.puts nodeId
    #IO.inspect (self())
    routeTable = initRouteTable([], 32, nodeId)
    routeTable = [ getNullList(17, [], 18) | routeTable]
    routeTable = Enum.reverse(routeTable)
    #IO.inspect(routeTable)
    {routeTable, leftLeafs, rightLeafs, receivedFrom} = 
      if (startNode != []) do
        send(hd(startNode), {:newNode, 0, nodeId, self()})
        receiveRouteInfo(routeTable, nodeId, [])
      else
        {routeTable, [], [], []}
      end
    #IO.inspect(routeTable)
    #IO.inspect(leftLeafs)
    #IO.inspect(rightLeafs)
    receivedFrom = Enum.uniq(receivedFrom ++ sendRouteTableToLeafs(leftLeafs ++ rightLeafs, []))
    sendRouteTable(routeTable, receivedFrom, nodeId)
    :timer.sleep(20)
    send(master, {:done})
    receiveLoop(routeTable, leftLeafs, rightLeafs, nodeId, master)  
  end

end


defmodule PASTRY do

  def receiveConfirmation() do
    receive do
      {:done} -> :done
    end
  end

  def createNodes(numNodes, nodes) when numNodes == 0 do
    nodes
  end


  def createNodes(numNodes, nodes) do
    pid = if (nodes != []) do
            spawn(Actor, :start, [[hd(nodes)], numNodes, self()])
          else
            spawn(Actor, :start, [[], numNodes, self()])
          end
    nodes = [pid | nodes]
    receiveConfirmation()
    createNodes(numNodes-1, nodes)
  end

  def start(numNodes, numRequests) do
    nodes = createNodes(numNodes, [])
    
  end
  
end
