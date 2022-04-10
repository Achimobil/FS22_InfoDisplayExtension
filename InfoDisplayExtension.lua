--[[
Copyright (C) Achimobil, 2022

Author: Achimobil (Base and pallets) / braeven (bales)
Date: 03.03.2022
Version: 1.0.0.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW

History:
V 1.0.0.0 @ 03.03.2022 - First Release to Modhub

Important:
No copy and use in own mods allowed.

Das verändern und wiederöffentlichen, auch in Teilen, ist untersagt und wird abgemahnt.
]]

InfoDisplayExtension = {}

InfoDisplayExtension.metadata = {
    title = "InfoDisplayExtension",
    notes = "Erweiterung des Infodisplays für Silos und Produktionen",
    author = "Achimobil",
    info = "Das verändern und wiederöffentlichen, auch in Teilen, ist untersagt und wird abgemahnt."
};
InfoDisplayExtension.modDir = g_currentModDirectory;


function InfoDisplayExtension:updateInfo(superFunc, infoTable)

	local spec = self.spec_silo
	local farmId = g_currentMission:getFarmId()

    local totalFillLevel = 0;
	for fillType, fillLevel in pairs(spec.loadingStation:getAllFillLevels(farmId)) do
		totalFillLevel = totalFillLevel + fillLevel
	end
    
    table.insert(infoTable, 
        {
            title = g_i18n:getText("infoDisplayExtension_TOTAL_CAPACITY_TITLE"), 
            accentuate = true 
        }
    )
    
    table.insert(infoTable,
        {
            title = g_i18n:getText("infoDisplayExtension_USED_CAPACITY"), 
            text = g_i18n:formatVolume(totalFillLevel, 0)
        }
    )
    
    local sourceStorages = spec.loadingStation:getSourceStorages();
    local totalCapacity = 0;

	for _, sourceStorage in pairs(sourceStorages) do
		if spec.loadingStation:hasFarmAccessToStorage(farmId, sourceStorage) then
			totalCapacity = totalCapacity + sourceStorage.capacity;
		end
	end
    
    table.insert(infoTable,
        {
            title = g_i18n:getText("infoDisplayExtension_TOTAL_CAPACITY"), 
            text = g_i18n:formatVolume(totalCapacity, 0)
        }
    )
    
    -- print("test")
end

PlaceableSilo.updateInfo = Utils.appendedFunction(PlaceableSilo.updateInfo, InfoDisplayExtension.updateInfo)

--- Original from Source 1.3
function InfoDisplayExtension:updateInfoProductionPoint(_, superFunc, infoTable)

	local owningFarm = g_farmManager:getFarmById(self:getOwnerFarmId())

	table.insert(infoTable, {
		title = g_i18n:getText("fieldInfo_ownedBy"),
		text = owningFarm.name
	})

	if #self.activeProductions > 0 then
		table.insert(infoTable, self.infoTables.activeProds)

		local activeProduction = nil

		for i = 1, #self.activeProductions do
			activeProduction = self.activeProductions[i]
			local productionName = activeProduction.name or g_fillTypeManager:getFillTypeTitleByIndex(activeProduction.primaryProductFillType)

			table.insert(infoTable, {
				title = productionName,
				text = g_i18n:getText(ProductionPoint.PROD_STATUS_TO_L10N[self:getProductionStatus(activeProduction.id)])
			})
		end
	else
		table.insert(infoTable, self.infoTables.noActiveProd)
	end

	local fillType, fillLevel, fillLevelCapacity = nil
	local fillTypesDisplayed = false

	table.insert(infoTable, self.infoTables.storage)

	for i = 1, #self.inputFillTypeIdsArray do
		fillType = self.inputFillTypeIdsArray[i]
		fillLevel = self:getFillLevel(fillType)
		fillLevelCapacity = self:getCapacity(fillType)

		if fillLevel > 1 then
			fillTypesDisplayed = true

			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(fillType),
				text = g_i18n:formatVolume(fillLevel, 0) .. " / " .. g_i18n:formatVolume(fillLevelCapacity, 0)
			})
		end
	end

	for i = 1, #self.outputFillTypeIdsArray do
		fillType = self.outputFillTypeIdsArray[i]
		fillLevel = self:getFillLevel(fillType)
		fillLevelCapacity = self:getCapacity(fillType)

		if fillLevel > 1 then
			fillTypesDisplayed = true

			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(fillType),
				text = g_i18n:formatVolume(fillLevel, 0) .. " / " .. g_i18n:formatVolume(fillLevelCapacity, 0)
			})
		end
	end

	if not fillTypesDisplayed then
		table.insert(infoTable, self.infoTables.storageEmpty)
	end
end

ProductionPoint.updateInfo = Utils.overwrittenFunction(ProductionPoint.updateInfo, InfoDisplayExtension.updateInfoProductionPoint)

--- Original from Source 1.3
function InfoDisplayExtension:populateCellForItemInSection(_, list, section, index, cell)
	if list == self.productionList then
		local productionPoint = self:getProductionPoints()[section]
		local production = productionPoint.productions[index]
		local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(production.primaryProductFillType)

		if fillTypeDesc ~= nil then
			cell:getAttribute("icon"):setImageFilename(fillTypeDesc.hudOverlayFilename)
		end

		cell:getAttribute("icon"):setVisible(fillTypeDesc ~= nil)
		cell:getAttribute("name"):setText(production.name or fillTypeDesc.title)

		local status = production.status
		local activityElement = cell:getAttribute("activity")

		if status == ProductionPoint.PROD_STATUS.RUNNING then
			activityElement:applyProfile("ingameMenuProductionProductionActivityActive")
		elseif status == ProductionPoint.PROD_STATUS.MISSING_INPUTS or status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
			activityElement:applyProfile("ingameMenuProductionProductionActivityIssue")
		else
			activityElement:applyProfile("ingameMenuProductionProductionActivity")
		end
	else
		local _, productionPoint = self:getSelectedProduction()
		local fillType, isInput = nil

		if section == 1 then
			fillType = self.selectedProductionPoint.inputFillTypeIdsArray[index]
			isInput = true
		else
			fillType = self.selectedProductionPoint.outputFillTypeIdsArray[index]
			isInput = false
		end

		if fillType ~= FillType.UNKNOWN then
			local fillLevel = self.selectedProductionPoint:getFillLevel(fillType)
			local capacity = self.selectedProductionPoint:getCapacity(fillType)
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillType)

			cell:getAttribute("icon"):setImageFilename(fillTypeDesc.hudOverlayFilename)
			cell:getAttribute("fillType"):setText(fillTypeDesc.title)
			cell:getAttribute("fillLevel"):setText(self.i18n:formatVolume(fillLevel, 0) .. " / " .. self.i18n:formatVolume(capacity, 0))

			if not isInput then
				local outputMode = productionPoint:getOutputDistributionMode(fillType)
				local outputModeText = g_i18n:getText("Revamp_Spawn")

				if outputMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
					outputModeText = self.i18n:getText("ui_production_output_selling")
				elseif outputMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
					outputModeText = self.i18n:getText("ui_production_output_distributing")
                --Production Revamp: Hinzugefügt um die "Einlagern" Option anzeigen zu können
                elseif outputMode == ProductionPoint.OUTPUT_MODE.STORE then
                    outputModeText = g_i18n:getText("Revamp_Store");
				end

				cell:getAttribute("outputMode"):setText(outputModeText)
			end

			self:setStatusBarValue(cell:getAttribute("bar"), fillLevel / capacity, isInput)
		end
	end
end

InGameMenuProductionFrame.populateCellForItemInSection = Utils.overwrittenFunction(InGameMenuProductionFrame.populateCellForItemInSection, InfoDisplayExtension.populateCellForItemInSection)

--- Original from Source 1.3
function InfoDisplayExtension:updateInfoPlaceableHusbandryAnimals(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryAnimals
	local health = 0
	local numAnimals = 0
	local maxNumAnimals = spec:getMaxNumOfAnimals()
	local clusters = spec.clusterSystem:getClusters()
	local numClusters = #clusters

	if numClusters > 0 then
		for _, cluster in ipairs(clusters) do
			health = health + cluster.health
			numAnimals = numAnimals + cluster.numAnimals
		end

		health = health / numClusters
	end

	spec.infoNumAnimals.text = string.format("%d", numAnimals) .. " / " .. string.format("%d", maxNumAnimals)
	spec.infoHealth.text = string.format("%d %%", health)

	table.insert(infoTable, spec.infoNumAnimals)
	table.insert(infoTable, spec.infoHealth)
end

PlaceableHusbandryAnimals.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryAnimals.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryAnimals)

function InfoDisplayExtension:updateInfoPlaceableHusbandryFood(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryFood
	local fillLevel = self:getTotalFood()
	local capacity = self:getFoodCapacity()
	spec.info.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryFood.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryFood.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryFood)

function InfoDisplayExtension:updateInfoPlaceableHusbandryMilk(_, superFunc, infoTable)
	local spec = self.spec_husbandryMilk

	superFunc(self, infoTable)

	local fillLevel = self:getHusbandryFillLevel(spec.fillType)
	local capacity = self:getHusbandryCapacity(spec.fillType)
	spec.info.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryMilk.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryMilk.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryMilk)

function InfoDisplayExtension:updateInfoPlaceableHusbandryLiquidManure(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryLiquidManure
	local fillLevel = self:getHusbandryFillLevel(spec.fillType)
	local capacity = self:getHusbandryCapacity(spec.fillType)
	spec.info.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryLiquidManure.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryLiquidManure.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryLiquidManure)

function InfoDisplayExtension:updateInfoPlaceableHusbandryStraw(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryStraw
	local fillLevel = self:getHusbandryFillLevel(spec.inputFillType)
	local capacity = self:getHusbandryCapacity(spec.inputFillType)
	spec.info.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryStraw.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryStraw.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryStraw)

function InfoDisplayExtension:updateInfoPlaceableHusbandryWater(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryWater

	if not spec.automaticWaterSupply then
		local fillLevel = self:getHusbandryFillLevel(spec.fillType)
        local capacity = self:getHusbandryCapacity(spec.fillType)
		spec.info.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

		table.insert(infoTable, spec.info)
	end
end
PlaceableHusbandryWater.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryWater.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryWater)

function PlaceableManureHeap:updateInfoPlaceableManureHeap(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_manureHeap

	if spec.manureHeap == nil then
		return
	end

	local fillLevel = spec.manureHeap:getFillLevel(spec.manureHeap.fillTypeIndex)
	local capacity = spec.manureHeap:getCapacity(spec.manureHeap.fillTypeIndex)
	spec.infoFillLevel.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

	table.insert(infoTable, spec.infoFillLevel)
end
PlaceableManureHeap.updateInfo = Utils.overwrittenFunction(PlaceableManureHeap.updateInfo, InfoDisplayExtension.updateInfoPlaceableManureHeap)

function InfoDisplayExtension:getProductionPoints()
	local productionPoints = self.chainManager:getProductionPointsForFarmId(self.playerFarm.farmId)
    table.sort(productionPoints,compProductionPoints)
    return productionPoints;
end
function compProductionPoints(w1,w2)
    return compare_utf8_strings(w1:getName(), w2:getName());
end
InGameMenuProductionFrame.getProductionPoints = Utils.overwrittenFunction(InGameMenuProductionFrame.getProductionPoints, InfoDisplayExtension.getProductionPoints)



-- sorting helper for special characters
alphabet =
{
    -- The space is here because of other requirements of my project
    { ' ' },
    { 'a', 'á', 'à', 'ä' },
    { 'b' },
    { 'c' },
    { 'd' },
    { 'e', 'é', 'è', 'ë' },
    { 'f' },
    { 'g' },
    { 'h' },
    { 'i', 'í', 'ì', 'ï' },
    { 'j' },
    { 'k' },
    { 'l' },
    { 'm' },
    { 'n' },
    { 'ñ' },
    { 'o', 'ó', 'ò', 'ö' },
    { 'p' },
    { 'q' },
    { 'r' },
    { 's' },
    { 't' },
    { 'u', 'ú', 'ù', 'ü' },
    { 'v' },
    { 'w' },
    { 'x' },
    { 'y' },
    { 'z' }
}


-- Looks up the character `character´ in the alphabet and returns its 'priority'
function get_pos_in_alphabet( character )
    for i, alphabet_entry in ipairs(alphabet) do
        for _, alphabet_char in ipairs(alphabet_entry) do
            if character == alphabet_char then
                return i
            end
        end
    end

    --[[
        If it isn't in the alphabet, abort: it's better than silently outputting some
        random garbage, and, thanks to the message, allows to add the character to
        the table.
    ]]
    print("'" .. character .. "' was not in alphabet. Please report to Achimobil")
    return -1;
end

-- Returns the characters in the UTF-8-encoded string `s´ in an array-like table
function get_utf8_string_characters( s )
    --[[
        I saw this variable being used in several code snippets around the Web, but
        it isn't provided in my LuaTeX environment; I use this form of initialization
        to be safe if it's defined in the future.
    ]]
    local charpattern = "([%z\1-\127\194-\244][\128-\191]*)"

    local characters = {}

    for character in s:gmatch(charpattern) do
        table.insert( characters , character )
    end

    return characters
end

function compare_utf8_strings( _o1 , _o2 )
    --[[
        `o1_chars´ and `o2_chars´ are array-like tables containing all of the
        characters of each string, which are all made lower-case using the
        slnunicode facilities that come built-in with LuaTeX.
    ]]
    local o1_chars = get_utf8_string_characters( utf8ToLower(_o1) )
    local o2_chars = get_utf8_string_characters( utf8ToLower(_o2) )

    local o1_len = utf8Strlen(_o1)
    local o2_len = utf8Strlen(_o2)

    for i = 1, math.min( o1_len , o2_len ) do
        o1_pos = get_pos_in_alphabet( o1_chars[i] )
        o2_pos = get_pos_in_alphabet( o2_chars[i] )

        if o1_pos > o2_pos then
            return false
        elseif o1_pos < o2_pos then
            return true
        end
    end

    return o1_len < o2_len
end