
defmodule Actor do
  
  def updateRow(destination, source, res) when destination == [] do
    res
  end

  def updateRow(destination, source, res) do
    tmp = if (hd(destination) != :null) do
            hd(destination)
          else
            hd(source)
          end
    updateRow(tl(destination), tl(source), [tmp | res])
  end

  def updateRouteTable(routeTable, sourceRouteTable, nodeId, sourceKey, idx) 
    when idx >= length(routeTable)-1 do
      routeTable
  end

  def updateRouteTable(routeTable, sourceRouteTable, nodeId, sourceKey, idx) do
    tmpRow = updateRow(Enum.at(routeTable, idx), Enum.at(sourceRouteTable, idx), [])
    routeTable = List.insert_at(routeTable, idx, tmpRow)
    if (String.at(nodeId, idx) != String.at(sourceKey, idx)) do
      routeTable
    else
      updateRouteTable(routeTable, sourceRouteTable, nodeId, sourceKey, idx+1)
    end
  end

  def getDistance(fromNode, toNode) do
    if (toNode < fromNode) do
      round(:math.pow(2,64)-1) - fromNode + toNode
    else
      toNode - fromNode
    end
  end

  def processLeafNodes(left, right, center, nodeId) do
    {_, pivot} = center
    if (getDistance(nodeId, pivot) > getDistance(pivot, nodeId)) do
      {left,right} = if (length(left) < 8) do
                      {left, right}
                     else
                      [head | tail] = left
                      if (length(right) < 8) do
                        {tail, [right | head]}
                      else
                        {tail, right}
                      end
                     end
      {[left | center], right}
    else
      {left, right} = if (length(right) < 8) do
                        {left, right}
                      else
                        [head | tail] = Enum.reverse(right)
                        tail = Enum.reverse(tail)
                        if (length(left) < 8) do
                          {[head | left], tail}
                        else
                          {left, tail}
                        end
                      end
      {left, [center | right]}
    end

  end

  def receiveRouteInfo(routeTable, nodeId, receivedFrom) do
    receive do
      {:leafNodes, left, right, pivot} ->
        {sourcePid, _} = pivot
        receivedFrom = [sourcePid | receivedFrom]
        {leftLeafs, rightLeafs} = processLeafNodes(left, right, pivot, nodeId)
        {routeTable, leftLeafs, rightLeafs, receivedFrom}
      {:routeTable, sourceRouteTable, sourcePid, sourceKey} ->
        routeTable = updateRouteTable(routeTable, sourceRouteTable, to_string(nodeId), to_string(sourceKey), 0)
        receivedFrom = [ sourcePid | receivedFrom]
        receiveRouteInfo(routeTable, nodeId, receivedFrom)
    end
  end
  
  def getNearestFromRemLeafs(leafs, key, diff, nearest) when leafs == [] do
    nearest
  end

  def getNearestFromRemLeafs(leafs, key, diff, nearest) do
    {tmpId, tmpNodeId} = Enum.at(leafs, 0)
    {diff, nearest} = if (diff < abs(key-tmpNodeId)) do
                        {abs(key-tmpNodeId), pid}
                      else
                        {diff, nearest}
                      end
    getNearestFromRemLeafs(tl(leafs), key, diff, nearest)
  end 

  def getNearestFromLeafs(leafs, key) do
    {tmpId, tmpNodeId} = Enum.at(leafs, 0)
    diff = abs(key - tmpNodeId)
    nearest = tmpId
    getNearestFromRemLeafs(tl(leafs), key, diff, nearest)
  end

  def compareIds(one, two, index) do
    if (String.at(one, index) == String.at(two, index)) do
      compareIds(one, two, index+1)
    else
      index+1
    end
  end

  def checkInRange(left, right, key) do
    {minPid, minNodeId} = if (left != []) do
                            Enum.at(left, 0)
                          else
                            {:null, :null}
                          end
    {maxPid, maxNodeId} = if (right != []) do
                            Enum.at(right, -1)
                          else
                            {:null, :null}
                          end
    if (minNodeId == :null || maxNodeId == :null) do
      :null
    end

    if (minNodeId <= key && key <= maxNodeId) do
      getNearestFromLeafs([left | right], key)
    else
      :null
    end
  end

  def addLeaf(nodeList, pid, nodeId, resList) when nodeList == [] do
    [resList | {pid, nodeId}]
  end

  def addLeaf(nodeList, pid, nodeId, resList) do
    [head | tail] = nodeList
    {_, tmpId} = head
    if (getDistance(tmpId, nodeId) > getDistance(nodeId, tmpId)) do
      [resList | [{pid, nodeId}] | nodeList]
    else
      addLeaf(tail, pid, nodeId, [resList | head]) 
    end
  end

  def removeLastElement(nodeList) do
    [head | tail] = Enum.reverse(nodeList)
    {Enum.reverse(tail), head}
  end

  def addLeafNode(left, right, newPid, newNodeId, curNodeId) do
    if (getDistance(curNodeId, newNodeId) > getDistance(newNodeId, curNodeId)) do
      left = addLeaf(left, newPid, newNodeId, [])
      {left, right} = if (length(left) > 8 ) do
                        [head | tail] = left
                        {tmpPid, tmpNodeId} = head
                        tmpRight = addLeaf(right, tmpPid, tmpNodeId, [])
                        {tmpRight, _ } = if (length(tmpRight) > 8) do
                                            removeLastElement(tmpRight)
                                         else
                                            {tmpRight, :null}
                                         end
                        {tail, tmpRight}
                      else
                        {left, right}  
                      end
      {left, right}
    else
      right = addLeaf(right, newPid, newNodeId, [])
      {left, right} = if (length(right) <= 8) do
                        {left, right}
                      else
                        {tmpRight, head} = removeLastElement(right)
                        {tmpPid, tmpNodeId} = head
                        tmpLeft = addLeaf(left, tmpPid, tmpNodeId, [])
                        if (length(tmpLeft) > 8)
                          {tl(tmpLeft), tmpRight}
                        else
                          {tmpLeft, tmpRight}
                        end
                      end
      {left, right}
    end
  end

  def receiveLoop(routeTable, leftLeafs, rightLeafs, curNodeId, master) do
    receive do
      {:newNode, startIndex, key, pid} ->
        startCount = startIndex
        endCount = compareIds(key, curNodeId, startIndex)
        send(pid, {:routeTable, routeTable, self(), curNodeId})
        nextHop = checkInRange(leftLeafs, [{self(), curNodeId} | rightLeafs], key)
        nextHop = if (nextHop == :null) do
                    Enum.at(routeTable, endCount).at(String.to_integer( String.at(key, endCount), 16 ))
                  else
                    nextHop
                  end
        nextHop = if (nextHop == :null) do
                    getNearestFromLeafs(key, [leftLeafs | rightLeafs | {self(), curNodeId}])
                  else
                    nextHop
                  end
        if (nextHop == self()) do
          send(pid, {:leafNodes, leftLeafs, rightLeafs, {self(), curNodeId}})
        else
          send(nextHop, {:newNode, endCount, key, pid})
        end
      {:routeTable, sourceRouteTable, senderPid, senderNodeId} ->
        routeTable = 
          updateRouteTable(routeTable, sourceRouteTable, to_string(curNodeId), to_string(senderNodeId), 0)
        {leftLeafs, rightLeafs} = addLeafNode(leftLeafs, rightLeafs, senderPid, senderNodeId, curNodeId)
    end
  end

  def getNullList(len, list) when len == 0 do
    list
  end

  def getNullList(len, list) do
    getNullList(len-1, [:null | list])
  end

  def initRouteTable(routeTable, len)  when len == 0 do
    routeTable
  end

  def initRouteTable(routeTable, len) do
    routeTable = [ getNullList(17) | routeTable]
    initRouteTable(routeTable, len-1)
  end

  def sendRouteTable(routeTable, sendList, nodeId) when sendList == [] do
    
  end

  def sendRouteTable(routeTable, sendList, nodeId) do
    [head | tail] = sendList
    {pid, _} = head
    send(pid, {:routeTable, routeTable, self(), nodeId})
    sendRouteTable(routeTable, tail, nodeId)
  end

  def start(startNode, nodeNum, master) do
    nodeId = Base.encode16(:crypto.hash(:sha256, to_string(nodeNum)))
    nodeId = String.slice(nodeId, 2..33)
    if (startNode != []) do
      send(hd(startNode), {:newNode, 0, nodeId, self()})
    end
    {routeTable, leftLeafs, rightLeafs, receivedFrom} = receiveRouteInfo(initRouteTable([], 33), [], [], nodeId, [])
    sendRouteTable(routeTable, [ receivedFrom | leafNodes | rightLeafs ], nodeId)
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
    pid = if (nodes == []) do
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
