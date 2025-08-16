-- By VLANDRO for HD
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Useful for some pcall situtations
local pcalls = {}
do
	pcalls.DEFAULT_RETRY_WAIT_TIME = 0.1

	export type functionToCall<T..., P...> = (T...) -> (P...)
	-- Will call function until it succeeds with give period, will return result of function
	function pcalls.untilSucceed<T..., P...>(
		retryWaitTime: number?,
		warning: boolean?, 
		functionToCall: functionToCall<T..., P...>, 
		...: T...
	): P...
		-- getting result
		local result = table.pack(pcall(functionToCall, ...)) :: any
		local isSuccess = result[1]
		-- while function errors try again and again
		while not isSuccess do
			if warning then
				warn(result[2], "\n", debug.traceback())
			end
			task.wait(retryWaitTime or pcalls.DEFAULT_RETRY_WAIT_TIME)
			result = table.pack(pcall(functionToCall, ...))
			isSuccess = result[1]
		end
		-- returning all values except boolean completion status
		return select(2, table.unpack(result))
	end
	-- Will call function n-times 
	-- if it succeeds, will return result of function instantly
	function pcalls.withRetry<T..., P...>(
		retriesCount: number,
		retryWaitTime: number?, 
		warning: boolean?, 
		functionToCall: functionToCall<T..., P...>, 
		...: T...
	): P...
		local result = table.pack(pcall(functionToCall, ...)) :: any
		local isSuccess = result[1]
		local retriesPassed = 0

		while not isSuccess do
			if warning then
				warn(result[2], "\n", debug.traceback())
			end
			task.wait(retryWaitTime or pcalls.DEFAULT_RETRY_WAIT_TIME)
			result = table.pack(pcall(functionToCall, ...))
			isSuccess = result[1]

			retriesPassed += 1
			-- check for number of retries
			if retriesPassed >= retriesCount then
				break
			end
		end

		return select(2, table.unpack(result))
	end
end
-- When testing in Studio we don't want touch real game data
local IS_STUDIO = RunService:IsStudio()
-- contains info about all available leaderboards in game
local leaderboards = {}
do
	local leaderboardOrderedStore = DataStoreService:GetOrderedDataStore("WinsLeaderboard")
	local STAT_NAME = "Wins"
	-- contains all leaderboards GUI containers
	local leaderboardsContainers = {
		Workspace.GlobalLeaderboard,
	}
	-- creates UI frame to display player in leaderboard
	local function createPlayerCell(userName: string, place: number, count: number)
		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frame.BackgroundTransparency = 1
		frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 0.01)
		frame.LayoutOrder = place
		frame.Visible = true
		frame.AutoLocalize = false

		local rank = Instance.new("TextLabel")
		rank.Name = "rank"
		rank.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		rank.BackgroundTransparency = 1
		rank.BorderColor3 = Color3.fromRGB(0, 0, 0)
		rank.BorderSizePixel = 0
		rank.FontFace = Font.new(
			"rbxasset://fonts/families/RobotoCondensed.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
		rank.Size = UDim2.new(0, 125, 1, 0)
		rank.Text = `#{place}`
		rank.TextColor3 = Color3.fromRGB(255, 255, 255)
		rank.TextScaled = true
		rank.TextWrapped = true
		rank.Parent = frame

		local uIListLayout = Instance.new("UIListLayout")
		uIListLayout.Name = "UIListLayout"
		uIListLayout.FillDirection = Enum.FillDirection.Horizontal
		uIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		uIListLayout.HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly
		uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		uIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		uIListLayout.Parent = frame

		local name = Instance.new("TextLabel")
		name.Name = "name"
		name.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		name.BackgroundTransparency = 1
		name.BorderColor3 = Color3.fromRGB(0, 0, 0)
		name.BorderSizePixel = 0
		name.FontFace = Font.new(
			"rbxasset://fonts/families/RobotoCondensed.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
		name.Size = UDim2.new(0, 500, 1, 0)
		name.Text = userName
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextScaled = true
		name.TextWrapped = true
		name.Parent = frame

		local value = Instance.new("TextLabel")
		value.Name = "value"
		value.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		value.BackgroundTransparency = 1
		value.BorderColor3 = Color3.fromRGB(0, 0, 0)
		value.BorderSizePixel = 0
		value.FontFace = Font.new(
			"rbxasset://fonts/families/RobotoCondensed.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
		value.Size = UDim2.new(0, 145, 1, 0)
		value.Text = tostring(count)
		value.TextColor3 = Color3.fromRGB(255, 255, 255)
		value.TextScaled = true
		value.TextWrapped = true
		value.Parent = frame
		return frame
	end
	-- Cleaning all previous players frames
	local function clearAllPlayers(leaderboard: Model)
		local surfaceGui = leaderboard.Board.SurfaceGui
		local playersList = surfaceGui:FindFirstChild("ScrollingFrame")

		for _, child in ipairs(playersList:GetChildren() :: {Instance}) do
			if not child:IsA("Frame") then
				continue
			end
			child:Destroy()
		end
	end
	-- Updates the leaderboard GUI with the new retrieved info
	local function updateGui(leaderboard: Model, top: {{userName: string, userId: number, value: number}})
		local surfaceGui = leaderboard.Board.SurfaceGui
		local playersList = surfaceGui:FindFirstChild("ScrollingFrame")

		for place, info in ipairs(top) do
			local newFrame = createPlayerCell(
				info.userName, place, info.value
			)
			newFrame.Parent = playersList
		end
	end

	local function updateLeaderboards()
		local pages: DataStorePages = pcalls.untilSucceed(
			1,
			true,
			leaderboardOrderedStore.GetSortedAsync,
			leaderboardOrderedStore,
			false,
			35
		)

		local currentPage = pages:GetCurrentPage()

		local top = {}

		for place, info: {key: string, value: number} in ipairs(currentPage) do
			local userId = tonumber(info.key)
			-- When playing in studio with TEST tab, the userId is negative
			-- So it's good to delete them
			if userId < 0 then
				leaderboardOrderedStore:RemoveAsync(info.key)
				continue
			end
			local userName = pcalls.untilSucceed(
				0.5,
				true,
				Players.GetNameFromUserIdAsync,
				Players,
				userId
			)

			table.insert(top, {
				userName = userName,
				userId = userId,
				value = info.value
			})

		end
		for _, leaderboardModel in ipairs(leaderboardsContainers) do
			clearAllPlayers(leaderboardModel)
		end
		for _, leaderboardModel in ipairs(leaderboardsContainers) do
			updateGui(leaderboardModel, top)
		end
	end
	-- Whenever player is removing, we update theis data to be up to date
	Players.PlayerRemoving:Connect(function(player: Player)
		if RunService:IsStudio() then
			return
		end
		local wins = player:GetAttribute(STAT_NAME) or 0

		pcalls.withRetry(
			3,
			1,
			true,
			leaderboardOrderedStore.SetAsync,
			leaderboardOrderedStore,
			tostring(player.UserId),
			wins
		)
	end)
	
	table.insert(leaderboards, {
		update = updateLeaderboards,
		orderedDataStore = leaderboardOrderedStore,
		stat = STAT_NAME,
	})
end

local function updatePlayersDataFor(leaderboard)
	if IS_STUDIO then
		return
	end
	-- Iterating thgrough all players and updating their data while they in game
	-- So they can view changes without reconnecting
	for _, player in ipairs(Players:GetPlayers() :: {Player}) do
		local value = player:GetAttribute(leaderboard.stat)

		pcalls.untilSucceed(
			0.5,
			true,
			leaderboard.orderedDataStore.SetAsync,
			leaderboard.orderedDataStore,
			tostring(player.UserId),
			value
		)
	end
	task.wait(20)
end

local function updateLeaderboards()
	for _, leaderboard in ipairs(leaderboards) do
		task.wait(90)
		updatePlayersDataFor(leaderboard)
		leaderboard.update()
		task.wait(90)
	end
end

for _, leaderboard in ipairs(leaderboards) do
	leaderboard.update()
end

task.spawn(function()
	while true do
		updateLeaderboards()
	end
end)



