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
V 1.1.2.0 @ 20.04.2022 - Changes to game patch 1.4

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


function InfoDisplayExtension:updateInfo(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_silo
	local farmId = g_currentMission:getFarmId()
    local totalFillLevel = 0;

    -- collect capacities
    local sourceStorages = spec.loadingStation:getSourceStorages();
    local totalCapacity = 0;
    local fillTypesCapacities = {}

	for _, sourceStorage in pairs(sourceStorages) do
		if spec.loadingStation:hasFarmAccessToStorage(farmId, sourceStorage) then
			totalCapacity = totalCapacity + sourceStorage.capacity;
            
            -- todo
            if(sourceStorage.capacities ~= nil) then
                for fillType, fillLevel in pairs(sourceStorage.fillLevels) do
                    if(sourceStorage.capacities[fillType] ~= nil) then
                        fillTypesCapacities[fillType] = Utils.getNoNil(fillTypesCapacities[fillType], 0) + sourceStorage.capacities[fillType]
                    end
                end
            end
		end
	end

	for fillType, fillLevel in pairs(spec.loadingStation:getAllFillLevels(farmId)) do
		spec.fillTypesAndLevelsAuxiliary[fillType] = (spec.fillTypesAndLevelsAuxiliary[fillType] or 0) + fillLevel
		totalFillLevel = totalFillLevel + fillLevel
	end

	table.clear(spec.infoTriggerFillTypesAndLevels)

	for fillType, fillLevel in pairs(spec.fillTypesAndLevelsAuxiliary) do
		if fillLevel > 0.1 then
			spec.fillTypeToFillTypeStorageTable[fillType] = spec.fillTypeToFillTypeStorageTable[fillType] or {
				fillType = fillType,
				fillLevel = fillLevel,
				capacity = fillTypesCapacities[fillType],
                title = g_fillTypeManager:getFillTypeTitleByIndex(fillType)
			}
			spec.fillTypeToFillTypeStorageTable[fillType].fillLevel = fillLevel

			table.insert(spec.infoTriggerFillTypesAndLevels, spec.fillTypeToFillTypeStorageTable[fillType])
		end
	end

    -- print("infoTriggerFillTypesAndLevels");
    -- DebugUtil.printTableRecursively(spec.infoTriggerFillTypesAndLevels,"_",0,2);

	table.clear(spec.fillTypesAndLevelsAuxiliary)
	table.sort(spec.infoTriggerFillTypesAndLevels, function (a, b)
		return b.title > a.title
	end)

	local numEntries = math.min(#spec.infoTriggerFillTypesAndLevels, 25)

	if numEntries > 0 then
		for i = 1, numEntries do
			local fillTypeAndLevel = spec.infoTriggerFillTypesAndLevels[i]

            if fillTypeAndLevel.capacity == nil then
                table.insert(infoTable, {
                    title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeAndLevel.fillType),
                    text = g_i18n:formatVolume(fillTypeAndLevel.fillLevel, 0)
                })
            else
                table.insert(infoTable, {
                    title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeAndLevel.fillType),
                    text = g_i18n:formatVolume(fillTypeAndLevel.fillLevel, 0) .. " / " .. g_i18n:formatVolume(fillTypeAndLevel.capacity, 0)
                })
            end
		end
        if #spec.infoTriggerFillTypesAndLevels > 25 then
            table.insert(infoTable, {
                title = g_i18n:getText("infoDisplayExtension_MORE_ITEMS"),
                text = string.format("%d", #spec.infoTriggerFillTypesAndLevels - 25)
            })
        end
	else
		table.insert(infoTable, {
			text = "",
			title = g_i18n:getText("infohud_siloEmpty")
		})
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
    
    if totalCapacity ~= 0 then
        table.insert(infoTable,
            {
                title = g_i18n:getText("infoDisplayExtension_TOTAL_CAPACITY"), 
                text = g_i18n:formatVolume(totalCapacity, 0)
            }
        )
    end
    
    -- print("test")
end
PlaceableSilo.updateInfo = Utils.overwrittenFunction(PlaceableSilo.updateInfo, InfoDisplayExtension.updateInfo)

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

	if self.palletLimitReached then
		table.insert(infoTable, self.infoTables.palletLimitReached)
	end
end
ProductionPoint.updateInfo = Utils.overwrittenFunction(ProductionPoint.updateInfo, InfoDisplayExtension.updateInfoProductionPoint)

function InfoDisplayExtension:populateCellForItemInSection(superFunc, list, section, index, cell)
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

function InfoDisplayExtension:getProductionPoints(superFunc)
	local productionPoints = self.chainManager:getProductionPointsForFarmId(self.playerFarm.farmId)
    table.sort(productionPoints,compProductionPoints)
    return productionPoints;
end
function compProductionPoints(w1,w2)
    return w1:getName() .. w1.id < w2:getName() .. w2.id;
end

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

function InfoDisplayExtension:updateInfoPlaceableManureHeap(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_manureHeap

	if spec.manureHeap == nil then
		return
	end

	local fillLevel = spec.manureHeap:getFillLevel(spec.manureHeap.fillTypeIndex)
	local capacity = spec.manureHeap:getCapacity(spec.manureHeap.fillTypeIndex)
	spec.infoFillLevel.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

	table.insert(infoTable, spec.infoFillLevel)
    
    table.insert(infoTable, 
        {
            title = g_i18n:getText("infoDisplayExtension_MANURE_HEAP_CONNECTED"), 
            accentuate = true 
        }
    )
    
    for j, unloadingStation in pairs (spec.manureHeap.unloadingStations) do
        table.insert(infoTable, {
            title = "",
            text = unloadingStation:getName()
        })
    end    
    
-- print("self.spec_manureHeap.manureHeap.unloadingStations")
-- DebugUtil.printTableRecursively(self.spec_manureHeap.manureHeap.unloadingStations,"_",0,2)
end
PlaceableManureHeap.updateInfo = Utils.overwrittenFunction(PlaceableManureHeap.updateInfo, InfoDisplayExtension.updateInfoPlaceableManureHeap)

function InfoDisplayExtension:updateInfoFeedingRobot(_, infoTable)
	if self.infos ~= nil then
		for _, info in ipairs(self.infos) do
			local fillLevel = 0
			local capacity = 0

			for _, fillType in ipairs(info.fillTypes) do
				fillLevel = fillLevel + self:getFillLevel(fillType)
                local spot = self.fillTypeToUnloadingSpot[fillType]
                if spot ~= nil then
                    capacity = capacity + spot.capacity
                end
			end

			info.text = string.format("%d l", fillLevel) .. " / " .. string.format("%d l", capacity)

			table.insert(infoTable, info)
		end
	end
end
FeedingRobot.updateInfo = Utils.overwrittenFunction(FeedingRobot.updateInfo, InfoDisplayExtension.updateInfoFeedingRobot)

function InfoDisplayExtension:updateUI(_)
--[[ original aus Patch 1.5 überschrieben
Grund:
Die Anzeige der einzelnen Balken gerücksichtig als einziges nicht ob es ein feld auf dem Farmland gibt.]]
	if self.mapFrame ~= nil then
		local farmId = g_currentMission:getFarmId()
		local totalScore = self:getTotalScore(farmId)
		local percentage = self:getTotalScore(farmId) / 100
        
		self.mapFrame.envScoreBarNumber:setText(string.format("%d", MathUtil.round(totalScore,1)))
		self.mapFrame.envScoreBarDynamic:setSize(self.mapFrame.envScoreBarStatic.size[1] * percentage)

		local uvs = GuiOverlay.getOverlayUVs(self.mapFrame.envScoreBarStatic.overlay, true)

		self.mapFrame.envScoreBarDynamic:setImageUVs(true, uvs[1], uvs[2], uvs[3], uvs[4], (uvs[5] - uvs[1]) * percentage + uvs[1], uvs[6], (uvs[7] - uvs[3]) * percentage + uvs[3], uvs[8])

		local indicatorX = self.mapFrame.envScoreBarStatic.position[1] + self.mapFrame.envScoreBarStatic.size[1] * percentage

		self.mapFrame.envScoreBarIndicator:setPosition(indicatorX - self.mapFrame.envScoreBarIndicator.size[1] * 0.5)
		self.mapFrame.envScoreBarNumber:setPosition(indicatorX - self.mapFrame.envScoreBarNumber.size[1] * 0.5)

        local sumFarmlandSize = 0
        for farmlandId, _farmId in pairs(g_farmlandManager.farmlandMapping) do
            if _farmId == farmId then
                local farmland = g_farmlandManager:getFarmlandById(farmlandId)

                if farmland ~= nil and farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
                    sumFarmlandSize = sumFarmlandSize + farmland.totalFieldArea
                end
            end
        end    
    
		for i = 1, #self.scoreValues do
			local scoreValue = self.scoreValues[i]

			if self.mapFrame.envScoreDistributionText[i] ~= nil then
				local score = 0

				if scoreValue.object ~= nil then
					local numFarmlands = 0

					for farmlandId, _farmId in pairs(g_farmlandManager.farmlandMapping) do
						if _farmId == farmId then
                            local farmland = g_farmlandManager:getFarmlandById(farmlandId)
                            
                            if farmland ~= nil and farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
                                score = score + scoreValue.object:getScore(farmlandId) * farmland.totalFieldArea / sumFarmlandSize
                                numFarmlands = numFarmlands + 1
                            end
						end
					end
				end

				self.mapFrame.envScoreDistributionText[i]:setText(scoreValue.name)
				self.mapFrame.envScoreDistributionValue[i]:setText(string.format("%.1f", MathUtil.round(score * scoreValue.maxScore, 1)))
				self.mapFrame.envScoreDistributionBar[i]:setSize(self.mapFrame.envScoreDistributionBarBackground[i].size[1] * score)
			end
		end

		local factor = MathUtil.round(self:getSellPriceFactor(farmId) * 100)
		local text = factor >= 1 and self.infoTextPos or factor <= -1 and self.infoTextNeg or self.infoTextNone

		self.mapFrame.envScoreInfoText:setText(string.format(text, math.abs(factor)))
	end
end


function InfoDisplayExtension:loadMap(name)
    -- hier alles rein, was erst nach dem laden aller mods und der map geladen ausgetauscht werden kann
    if g_modIsLoaded["FS22_precisionFarming"] then
        FS22_precisionFarming.EnvironmentalScore.updateUI = Utils.overwrittenFunction(FS22_precisionFarming.EnvironmentalScore.updateUI, InfoDisplayExtension.updateUI);
    end
    
    local mods = g_modManager:getActiveMods(FS22_A_ProductionRevamp);
    local revampversion = ""

    for index, activemod in pairs(mods) do
        if activemod.title == "Production Revamp" then
          revampversion = activemod.version
        end
    end
    
    if revampversion == "" or revampversion == "1.0.0.0" then
        InGameMenuProductionFrame.populateCellForItemInSection = Utils.overwrittenFunction(InGameMenuProductionFrame.populateCellForItemInSection, InfoDisplayExtension.populateCellForItemInSection)
        InGameMenuProductionFrame.getProductionPoints = Utils.overwrittenFunction(InGameMenuProductionFrame.getProductionPoints, InfoDisplayExtension.getProductionPoints)
    end
end

addModEventListener(InfoDisplayExtension)