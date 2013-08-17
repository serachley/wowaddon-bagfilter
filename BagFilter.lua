local filterTextures = {
	[1] = "Interface\\Icons\\INV_WEAPON_HALBERD_22", -- Weapons
	[2] = "Interface\\Icons\\INV_Chest_Plate_25", -- Armor
	[3] = "Interface\\Icons\\Achievement_Quests_Completed_07", -- Quest Items
	[4] = "Interface\\Icons\\INV_Alchemy_EndlessFlask_06", -- Consumables
	[5] = "Interface\\Icons\\INV_Jewelcrafting_Gem_32",  -- Gems
	[6] = "Interface\\Icons\\INV_Misc_QuestionMark", -- Misc items and Trade items
	}

local filterNames = {
	[1] = "All Item Types",
	[2] = "Weapons",
	[3] = "Armor",
	[4] = "Quest Items",
	[5] = "Consumables",
	[6] = "Gems",
	[7] = "Misc/Trade Items",
	}

local filterQuality = {
	[1] = "All Items",
	[2] = "Poor (Grey)",
	[3] = "Common (White)",
	[4] = "Uncommon (Green)",
	[5] = "Rare (Blue)",
	[6] = "Epic (Purple)",
	[7] = "Legendary (Orange)",
	}

local lootedItems = {}

local maxRecentlyLootedItems = 5

function BagFilter_OnLoad(self)
	UIPanelWindows["BagFilter"] = {
		area = "centre",
		pushable = 1,
		whileDead = 1,
	}


	SetPortraitToTexture(self.portrait, "Interface\\Icons\\INV_Misc_Bag_27")
	self.info:SetText("Recently Looted Items:")

	-- Create the item slots
	self.items = {}
	for idx = 1, 24 do
		local item = CreateFrame("Button", "BagFilter_Item" .. idx, self, "BagFilterItemTemplate")
		item:RegisterForClicks("RightButtonUp")
		self.items[idx] = item
		if idx == 1 then
			item:SetPoint("TOPLEFT", 40, -73)
		elseif idx == 7 or idx == 13 or idx == 19 then
			item:SetPoint("TOPLEFT", self.items[idx-6], "BOTTOMLEFT", 0, -7)
		else
			item:SetPoint("TOPLEFT", self.items[idx-1], "TOPRIGHT", 12, 0)
		end
	end

	-- Create the filter buttons
	self.filters = {}


	--for idx = 0, 5 do
	--	local button = CreateFrame("CheckButton", filterNames[idx+2], self, "BagFilter_FilterTemplate")
	--	SetItemButtonTexture(button, filterTextures[idx+1])
	--	self.filters[idx] = button
	--	if idx == 0 then
	--		button:SetPoint("BOTTOMLEFT", 40, 200)
	--	else
	--		button:SetPoint("TOPLEFT",self.filters[idx-1], "TOPRIGHT", 12, 0)
	--	end

	--	button:SetChecked(false)
	--	button.glow:Hide()

	--end


	self.filters[-1] = self.filters[0]
	self.selectedFilter = -1
	self.page = 1
	self.filterQuality = false
	self.qualityFilter = -1
	self.bagCounts = {}

	BagFilter_Update(self)
	self:RegisterEvent("ADDON_LOADED")
end

local function itemNameSort(a, b)
	return a.name < b.name
end

function BagFilter_ScanBag(bag, initial)
	if not BagFilter.bagCounts[bag] then
		BagFilter.bagCounts[bag] = {}
	end

	local itemCounts = {}
	for slot = 0, GetContainerNumSlots(bag) do
		local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)

		if texture then
			local itemId = tonumber(link:match("|Hitem:(%d+):"))
			if not itemCounts[itemId] then

				itemCounts[itemId] = count
			else
				itemCounts[itemId] = itemCounts[itemId] + count
			end
		end
	end

	if initial then
		for itemId, count in pairs(itemCounts) do
			BagFilter_ItemTimes[itemId] = BagFilter_ItemTimes[itemId] or time()
		end
	else
		for itemId, count in pairs(itemCounts) do
			local oldCount = BagFilter.bagCounts[bag][itemId] or 0
			if count == 0 then
				BagFilter_Updatelooted(itemId)
			end
			if count > oldCount then
				BagFilter_ItemTimes[itemId] = time()
			end
		end
	end
	BagFilter.bagCounts[bag] = itemCounts
end

function BagFilter_UpdateLooted(itemId)
	-- put newly looted/updated item in slot 0


	local count = #lootedItems or 0

	--print("lootedItems: ", #lootedItems)

	if count > 0 then
		for idx = 4, 1, -1 do
			local buttonToShift = lootedItems[idx]
			local replacedButton = lootedItems[idx+1]
			--print("shifting item id: ", button:GetName())
			buttonToShift:SetPoint(replacedButton:GetPoint())
			lootedItems[idx+1] = buttonToShift
		end
	end

	local itemName, _, _, _, _, _, _, _,_, itemTexture, _ = GetItemInfo(itemId)
	local button = CreateFrame("CheckButton", itemName, BagFilter, "BagFilter_FilterTemplate")

	--print("setting button to index 0")
	SetItemButtonTexture(button, itemTexture)
	button:SetPoint("BOTTOMLEFT", 40, 200)
	--print("setting index 0 to: ", itemId)
	lootedItems[0] = button
	--print("lootedItems: ", #lootedItems)
end

local function itemTimeNameSort(a, b)
	local aTime = BagFilter_ItemTimes[a.num]
	local bTime = BagFilter_ItemTimes[b.num]
	if aTime == bTime then
		return a.name < b.name
	else
		return aTime >= bTime
	end
end

function BagFilter_Update()
	local items = {}

	local nameFilter = BagFilter.input:GetText():lower()

	--Scan through the bag slots, looking for items
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 0, GetContainerNumSlots(bag) do
			local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)

			if texture then

				local shown = true
				local filterClicked = false
				local itemCategoryFound = false


				local itemNum = tonumber(link:match("|Hitem:(%d+):"))
				local itemName, _, itemRarity, _, _, itemType, itemSubType = GetItemInfo(itemNum)

				if BagFilter.filterTypeClicked == -1 then
					filterClicked = true
				elseif BagFilter.filterTypeClicked == 0 and itemType == "Weapon" then
					filterClicked = true
				elseif BagFilter.filterTypeClicked == 1 and itemType == "Armor" then
					filterClicked = true
				elseif BagFilter.filterTypeClicked == 2 and itemType == "Quest" then
					filterClicked = true
				elseif BagFilter.filterTypeClicked == 3 and (itemType == "Consumable" or (itemType == "Trade Goods" and itemSubType == "Meat") or (itemType == "Trade Goods" and itemSubType =="Other" and quality == -1)) then
					filterClicked = true
				elseif BagFilter.filterTypeClicked == 4 and itemType == "Gem" then
					filterClicked = true
				elseif BagFilter.filterTypeClicked == 5 then
					if itemType ~= "Weapon" and itemType ~= "Armor" and itemType ~= "Quest" and itemType ~= "Gem" and itemType ~= "Consumable"  then
						if itemType == "Trade Goods" and itemSubType == "Other" then
							if quality >= 0 then
								filterClicked = true
							end
						elseif (itemType == "Trade Goods" and itemSubType ~= "Meat") or itemType == "Miscellaneous" then
							filterClicked = true
						end
					end
				end

				if BagFilter.itemTypeFilter then
					shown = shown and filterClicked
				end


				if BagFilter.filterQuality and (BagFilter.qualityFilter-2 ~= -1) then
					shown = shown and (itemRarity == BagFilter.qualityFilter-2)
				elseif BagFilter.filterQuality and (BagFilter.qualityFilter-2 == -1) then
					shown = true
				end


				if #nameFilter > 0 then
					local lowerName = GetItemInfo(link):lower()
					shown = shown and string.find(lowerName, nameFilter, 1, true)
				end


				if shown then
					-- If found, grab the item number and store other data
					if not items[itemNum] then
						items[itemNum] = {
							texture = texture,
							count = count,
							quality = quality,
							name = itemName,
							link = link,
							num = itemNum,
							itemType = itemType,
						}
					else
						-- the item already exists in our table, just update the count
						items[itemNum].count = items[itemNum].count + count
					end
				end
			end
		end
	end

	-- Sort the items
	local sortTbl = {}
	for link, entry in pairs(items) do
		table.insert(sortTbl, entry)
	end
	table.sort(sortTbl, itemNameSort)

	-- Display the sorted items in the BagFilter frame
	local max = BagFilter.page * 24
	local min = max - 23
	for idx = min, max do
		local button = BagFilter.items[idx - min + 1]
		local entry = sortTbl[idx]

		if entry then
			-- There is an item in this slot
			button:SetAttribute("item2", entry.name)
			button.link = entry.link
			button.icon:SetTexture(entry.texture)
			if entry.count > 1 then
				button.count:SetText(entry.count)
				button.count:Show()
			else
				button.count:Hide()
			end

			if entry.quality > 1 then
				button.glow:SetVertexColor(GetItemQualityColor(entry.quality))
				button.glow:Show()
			else
				button.glow:Hide()
			end

			button:Show()
		else
			button.link = nil
			button:Hide()
		end
	end

	if min > 1 then
		BagFilter.prev:Enable()
	else
		BagFilter.prev:Disable()
	end
	if max < #sortTbl then
		BagFilter.next:Enable()
	else
		BagFilter.next:Disable()
	end

	-- update status text
	if #sortTbl > 24 then
		local max = math.min(max, #sortTbl)
		local msg = string.format("Showing items %d - %d of %d", min, max, #sortTbl)
		BagFilter.status:SetText(msg)
	else
		BagFilter.status:SetText("Found " ..  #sortTbl .. " items")
	end

end


function BagFilter_Button_OnEnter(self, motion)
	if self.link then
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end
end

function BagFilter_Button_OnLeave(self, motion)
	GameTooltip:Hide()
end

function BagFilter_Filter_OnEnter(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
	GameTooltip:SetText(self:GetName())
	GameTooltip:Show()
end

function BagFilter_Filter_OnLeave(self, motion)
	GameTooltip:Hide()
end

function BagFilter_Filter_OnClick(self, button)
	BagFilter.itemTypeFilter = false
	BagFilter.filterTypeClicked = -1 -- nothing selected


	for idx = 0, 5 do
		local button = BagFilter.filters[idx]

		if BagFilter.selectedFilter == idx then
			button:SetChecked(false)
		end

		if button:GetChecked() then
			BagFilter.itemTypeFilter = true
			BagFilter.filterTypeClicked = idx

		end
	end
	BagFilter.selectedFilter = BagFilter.filterTypeClicked
	BagFilter.page = 1
	BagFilter_Update()
end

function BagFilter_NextPage(self)
	BagFilter.page = BagFilter.page + 1
	BagFilter_Update(BagFilter)
end

function BagFilter_PrevPage(self)
	BagFilter.page = BagFilter.page - 1
	BagFilter_Update(BagFilter)
end

function BagFilter_InitializeDropDown(self, event)
	for idx = 1, #filterNames+1 do

		local info = UIDropDownMenu_CreateInfo{}
		info.text = filterNames[idx]
		info.func = BagFilterInvSlotDropDown_OnSelect
		UIDropDownMenu_AddButton(info)
	end
end

function BagFilter_InitializeSubDropDown(self, event)
	for idx = 1, #filterQuality do

		local info = UIDropDownMenu_CreateInfo{}
		info.text = filterQuality[idx]
		info.func = BagFilterSubClassDropDown_OnSelect
		UIDropDownMenu_AddButton(info)
	end
end


function BagFilterInvSlotDropDown_OnSelect(self)
	UIDropDownMenu_SetText(BagFilterInvSlotDropDown, self:GetText());
	UIDropDownMenu_SetSelectedID(BagFilterInvSlotDropDown, self:GetID());

	print(self:GetID())

	BagFilter.itemTypeFilter = true
	BagFilter.filterTypeClicked = self:GetID() -2


	BagFilter.selectedFilter = BagFilter.filterTypeClicked
	BagFilter.page = 1
	BagFilter_Update()
end

function BagFilterSubClassDropDown_OnSelect(self)
	UIDropDownMenu_SetText(BagFilterSubClassDropDown, self:GetText());
	UIDropDownMenu_SetSelectedID(BagFilterSubClassDropDown, self:GetID());

	BagFilter.filterQuality = true
	BagFilter.qualityFilter = self:GetID()

	BagFilter.page = 1
	BagFilter_Update()
end


function BagFilterInvSlotDropDown_OnLoad(self)
	UIDropDownMenu_Initialize(self, BagFilter_InitializeDropDown)
	UIDropDownMenu_SetSelectedID(self, 1);
end

function BagFilterSubClassDropDown_OnLoad(self)
	UIDropDownMenu_Initialize(self, BagFilter_InitializeSubDropDown)
	UIDropDownMenu_SetSelectedID(self, 1);
end

function BagFilter_OnEvent(self, event, ...)
	if event == "ADDON_LOADED" and ... == "BagFilter" then
		if not BagFilter_ItemTimes then
			BagFilter_ItemTimes = {}
		end

		if not BagFilter_RecentlyLootedItems then
			BagFilter_RecentlyLootedItems = {}
		end

		for bag = 0, NUM_BAG_SLOTS do
			BagFilter_ScanBag(bag, true)
		end
		self:UnregisterEvent("ADDON_LOADED")
		self:RegisterEvent("BAG_UPDATE")
		self:RegisterEvent("ITEM_PUSH")
		self:RegisterEvent("CHAT_MSG_LOOT")
	elseif event == "BAG_UPDATE" then
		local bag, slot = ...
		if bag >= 0 then
			BagFilter_ScanBag(bag)
			if BagFilter:IsVisible() then
				BagFilter_Update()
			end
		end
	elseif event == "CHAT_MSG_LOOT" then
		local msg, target = ...
		local _,_,itemID = strfind(msg, "(%d+):")
		if ( UnitName(target) == player ) then
			BagFilter_UpdateLooted(itemID)
		end
	end
end


SLASH_BAGFilter1 = "/bf"
SLASH_BAGFilter2 = "/bagFilter"
SlashCmdList["BagFilter"] = function()
	ShowUIPanel(BagFilter)
end
