defmodule SERVER do
  use GenServer
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, {%{}, %{}}}
  end

  def register(server, {userName, pid}) do
    GenServer.cast(server, {:register, userName, pid})
  end

  def login(server {userName, pid, updatesPid}) do
    GenServer.cast(server, {:login, userName, pid, updatesPid})
  end

  def logout(server, {userName, pid}) do
    GenServer.cast(server, {:logout, userName, pid})
  end

  def update(server, {users, tweetid, action, tweet}) do
    GenServer.cast(server, {:updateUsers, users, tweetid, action, tweet})
  end

  def myMention(server, {userName, pid}) do
    GenServer.cast(server, {:myMention, userName, pid})
  end

  def getTweetsWithTag(server, {tag, pid}) do
    GenServer.cast(server, {:tweetsWithTag, tag, pid})
  end

  def getSubscribedTweets(server, {userName, pid}) do
    GenServer.cast(server, {:subscribedTweets, userName, pid})
  end

  def ping(sever) do
    GenServer.call(server, {:ping})
  end

  def getTweetsFromIds(tweets, tweetids, res) when tweetids == [] do
    res
  end

  def getTweetsFromIds(tweets, tweetids, res) do
    {{action, tweetid} | tl} = tweetids
    getTweetsFromIds(tweets, tl, [{action, Map.get(tweets, tweetid)} | res])
  end

  def getTweetsWithAction(tweets, tweetids, cmp, res) when tweetids == [] do
    res
  end

  def getTweetsWithAction(tweets, tweetids, cmp, res) do
    {{action, tweetid} | tl} = tweetids
    if (String.contains?(action, cmp) == true) do
      getTweetsWithAction(tweets, tl, cmp, [{action, Map.get(tweets, tweetid)} | res])
    else
      getTweetsWithAction(tweets, tl, cmp, res)
    end
  end


  def updateTimeLines(users, tweetid, action, timeLines, registeredUsers, tweets) when users == [] do
    timeLines
  end

  def updateTimeLines(users, tweetid, action, timeLines, registeredUsers, tweets) do
    [hd | tl] = users
    tmpList = if (Map.has_key?(timeLines, hd)) do
                Map.get(timeLines, hd)
              else
                []
    pid = Map.get(registeredUsers, hd)
    if (pid != NULL) do
      send(pid, Map.get(tweets, tweetid))
    end
    updateTimeLines(tl, tweetid, action, Map.put(timeLines, hd, [{tweetid, action} | tmpList]), 
      registeredUsers, tweets)
  end

  def handle_cast({:register, userName, pid}, 
                    {timeLines, tweets, registeredUsers}) do
    if Map.has_key?(registeredUsers, userName) == false do
      send(pid, {:failed, "User name already exists"})
      {:noreply, {timeLines, tweets, registeredUsers}}
    else
      send(pid, {:success, "Registered successfully"})
      { :noreply, {timeLines, tweets, Map.put(registeredUsers, userName, NULL)} }
    end
  end

  def handle_cast({:login, userName, pid, updatesPid}, 
                    {timeLines, tweets, registeredUsers}) do
    if Map.has_key?(registeredUsers, userName) == false do
      send(pid, {:failed, "User name doesnt exist"})
      {:noreply, {timeLines, tweets, registeredUsers}}
    else
      send(pid, {:success, "Login successfull"})
      { :noreply, {timeLines, tweets, Map.put(registeredUsers, userName, updatesPid)} }
    end
  end

  def handle_cast({:logout, userName, pid}, 
                    {timeLines, tweets, registeredUsers}) do
    if Map.has_key?(registeredUsers, userName) == false do
      send(pid, {:failed, "User name doesnt exist"})
      {:noreply, {timeLines, tweets, registeredUsers}}
    else
      send(pid, {:success, "Logout successfull"})
      { :noreply, {timeLines, tweets, Map.put(registeredUsers, userName, NULL)} }
    end
  end

  def handle_cast({:updateUsers, users, tweetid, action, tweet}, 
                    {timeLines, tweets, registeredUsers}) do
    tweets = Map.put(tweets, tweetid, tweet)
    {:noreply, {updateTimeLines(users, tweetid, action, timeLines, registeredUsers, tweets),
       tweets, registeredUsers}}
  end

  def handle_cast({:myMention, userName, pid}, 
                    {timeLines, tweets, registeredUsers}) do
    tweets = getTweetsWithAction(tweets, Map.get(timeLines, userName), "mention", [])
    send(pid, tweets)
    {:noreply, {timeLines, tweets, registeredUsers}}
  end

  def handle_cast({:tweetsWithTag, tag, pid}, 
                    {timeLines, tweets, registeredUsers}) do
    tweetids = Map.get(timeLines, tag)
    tweets = getTweetsFromIds(tweets, tweetids, [])
    send(pid, tweets)
    {:noreply, {timeLines, tweets, registeredUsers}}
  end

  def handle_cast({:subscribedTweets, userName, pid}, 
                    {timeLines, tweets, registeredUsers}) do
    tweets = getTweetsWithAction(tweets, Map.get(timeLines, userName), "tweet", [])
    send(pid, tweets)
    {:noreply, {timeLines, tweets, registeredUsers}}
  end
  
  def handle_call({:ping}, __from, {timeLines,tweets}) do
    {:reply, :ok, {timeLines, tweets}}
  end

end