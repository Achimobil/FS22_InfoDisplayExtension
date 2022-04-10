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
				local outputModeText = self.i18n:getText("ui_production_output_storing")

				if outputMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
					outputModeText = self.i18n:getText("ui_production_output_selling")
				elseif outputMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
					outputModeText = self.i18n:getText("ui_production_output_distributing")
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