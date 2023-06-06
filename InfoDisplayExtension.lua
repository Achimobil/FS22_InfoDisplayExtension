--[[
Copyright (C) Achimobil, 2022/2023

Author: Achimobil
Date: 10.05.2023
Version: 1.6.0.0

Contact:
https://github.com/Achimobil/FS22_InfoDisplayExtension


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

function InfoDisplayExtension:formatVolume(liters, precision, unit)
	if unit == "" then
		unit = nil;
	end
	
	return g_i18n:formatVolume(liters, precision, unit)
end

function InfoDisplayExtension:formatCapacity(liters, capacity, precision, unit)
	if unit == "" then
		unit = nil;
	end

	return g_i18n:formatVolume(liters, precision, "") .. " / " .. g_i18n:formatVolume(capacity, precision, unit);
end

function InfoDisplayExtension:storeScaledValues(superFunc)
	local scale = self.uiScale

	local function normalize(x, y)
		return x * scale * g_aspectScaleX / g_referenceScreenWidth, y * scale * g_aspectScaleY / g_referenceScreenHeight
	end

	self.boxWidth = normalize(440, 0)
	local _ = nil
	_, self.labelTextSize = normalize(0, HUDElement.TEXT_SIZE.DEFAULT_TITLE)
	_, self.rowTextSize = normalize(0, HUDElement.TEXT_SIZE.DEFAULT_TEXT)
	self.titleTextSize = self.labelTextSize
	self.labelTextOffsetX, self.labelTextOffsetY = normalize(0, 3)
	self.leftTextOffsetX, self.leftTextOffsetY = normalize(0, 6)
	self.rightTextOffsetX, self.rightTextOffsetY = normalize(0, 6)
	self.rowWidth, self.rowHeight = normalize(408, 26)
	self.listMarginWidth, self.listMarginHeight = normalize(16, 15)
end
KeyValueInfoHUDBox.storeScaledValues = Utils.overwrittenFunction(KeyValueInfoHUDBox.storeScaledValues, InfoDisplayExtension.storeScaledValues)

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
			local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeAndLevel.fillType);
			if fillTypeAndLevel.capacity == nil then
				table.insert(infoTable, {
					title = fillType.title,
					text = InfoDisplayExtension:formatVolume(fillTypeAndLevel.fillLevel, 0, fillType.unitShort)
				})
			else
				table.insert(infoTable, {
					title = fillType.title,
					text = InfoDisplayExtension:formatCapacity(fillTypeAndLevel.fillLevel, fillTypeAndLevel.capacity, 0, fillType.unitShort)
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
			text = InfoDisplayExtension:formatVolume(totalFillLevel, 0)
		}
	)
	
	if totalCapacity ~= 0 then
		table.insert(infoTable,
			{
				title = g_i18n:getText("infoDisplayExtension_TOTAL_CAPACITY"), 
				text = InfoDisplayExtension:formatVolume(totalCapacity, 0)
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
			local fillType = g_fillTypeManager:getFillTypeByIndex(fillType);
			table.insert(infoTable, {
				title = fillType.title,
				text = InfoDisplayExtension:formatCapacity(fillLevel, fillLevelCapacity, 0, fillType.unitShort)
			})
		end
	end

	for i = 1, #self.outputFillTypeIdsArray do
		fillType = self.outputFillTypeIdsArray[i]
		fillLevel = self:getFillLevel(fillType)
		fillLevelCapacity = self:getCapacity(fillType)

		if fillLevel > 1 then
			fillTypesDisplayed = true
			local fillType = g_fillTypeManager:getFillTypeByIndex(fillType);
			table.insert(infoTable, {
				title = fillType.title,
				text = InfoDisplayExtension:formatCapacity(fillLevel, fillLevelCapacity, 0, fillType.unitShort)
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
			cell:getAttribute("fillLevel"):setText(InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0, fillTypeDesc.unitShort));

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
	
	local shownProductionPoint = {}
	for _, productionPoint in ipairs (productionPoints) do
		-- remove the hidden productions of GtX Extended production points 
		if productionPoint.hiddenOnUI == nil or productionPoint.hiddenOnUI == false then
			table.insert(shownProductionPoint, productionPoint)
		end
	end
	
	table.sort(shownProductionPoint,compProductionPoints)
	return shownProductionPoint;
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
	-- spec.infoHealth.text = string.format("%d %%", health)

	table.insert(infoTable, spec.infoNumAnimals)
	-- table.insert(infoTable, spec.infoHealth)
	
	local isHorse = spec.animalTypeIndex == AnimalType.HORSE;
	local moreInfos = PlaceableHusbandryAnimals.setMoreInfos(clusters, isHorse);
	
	-- Alles irgendwie hübsch anzeigen
	if moreInfos.health ~= nil and moreInfos.highestHealth ~= nil and moreInfos.lowestHealth ~= nil then
		if moreInfos.health == moreInfos.highestHealth and moreInfos.health == moreInfos.lowestHealth then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "health", string.format("%d %%", moreInfos.health))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "healthRange", string.format("%d - %d %%", moreInfos.lowestHealth, moreInfos.highestHealth))
		end
	end
	
	if moreInfos.duration ~= nil and moreInfos.lowestDuration ~= nil and moreInfos.highestDuration ~= nil then
		if moreInfos.duration == moreInfos.lowestDuration and moreInfos.duration == moreInfos.highestDuration then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "duration", g_i18n:formatNumMonth(moreInfos.duration))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "durationRange", moreInfos.lowestDuration .. " - " .. g_i18n:formatNumMonth(moreInfos.highestDuration))
		end
	end
	
	if moreInfos.reproduction ~= nil and moreInfos.highestReproduction ~= nil and moreInfos.lowestReproduction ~= nil then
		if moreInfos.reproduction == moreInfos.highestReproduction and moreInfos.reproduction == moreInfos.lowestReproduction then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "reproduction", string.format("%d %%", moreInfos.reproduction))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "reproductionRange", string.format("%d - %d %%", moreInfos.lowestReproduction, moreInfos.highestReproduction))
		end
	end
	
	if moreInfos.beforeReproduction ~= nil and moreInfos.highestBeforeReproduction ~= nil and moreInfos.lowestBeforeReproduction ~= nil then
		if moreInfos.beforeReproduction == moreInfos.highestBeforeReproduction and moreInfos.beforeReproduction == moreInfos.lowestBeforeReproduction then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "beforeReproduction", string.format("%d %%", moreInfos.beforeReproduction))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "beforeReproductionRange", string.format("%d - %d %%", moreInfos.lowestBeforeReproduction, moreInfos.highestBeforeReproduction))
		end
	end
	
	if moreInfos.nextBirthIn ~= nil and moreInfos.nextBirthIn ~= 0 then
		PlaceableHusbandryAnimals.AddInfoText(infoTable, "nextBirthIn", g_i18n:formatNumMonth(moreInfos.nextBirthIn))
	end
	
	if moreInfos.dirt ~= nil and moreInfos.highestDirt ~= nil and moreInfos.lowestDirt ~= nil then
		if moreInfos.dirt == moreInfos.highestDirt and moreInfos.dirt == moreInfos.lowestDirt then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "dirt", string.format("%d %%", moreInfos.dirt))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "dirtRange", string.format("%d - %d %%", moreInfos.lowestDirt, moreInfos.highestDirt))
		end
	end
	
	if moreInfos.riding ~= nil and moreInfos.highestRiding ~= nil and moreInfos.lowestRiding ~= nil then
		if moreInfos.riding == moreInfos.highestRiding and moreInfos.riding == moreInfos.lowestRiding then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "riding", string.format("%d %%", moreInfos.riding))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "ridingRange", string.format("%d - %d %%", moreInfos.lowestRiding, moreInfos.highestRiding))
		end
	end
	
	if moreInfos.fitness ~= nil and moreInfos.highestFitness ~= nil and moreInfos.lowestFitness ~= nil then
		if moreInfos.fitness == moreInfos.highestFitness and moreInfos.fitness == moreInfos.lowestFitness then
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "fitness", string.format("%d %%", moreInfos.fitness))
		else
			PlaceableHusbandryAnimals.AddInfoText(infoTable, "fitnessRange", string.format("%d - %d %%", moreInfos.lowestFitness, moreInfos.highestFitness))
		end
	end
	
	-- for title, moreInfo in pairs(moreInfos) do
		-- table.insert(infoTable,
			-- {
				-- title = title, 
				-- text = tostring(moreInfo)
			-- }
		-- )
	-- end
-- print("moreInfos")
-- DebugUtil.printTableRecursively(moreInfos,"_",0,2)
end
PlaceableHusbandryAnimals.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryAnimals.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryAnimals)

function PlaceableHusbandryAnimals.AddInfoText(infoTable, title, text)
	table.insert(infoTable,
		{
			title = g_i18n:getText("infoDisplayExtension_animals_" .. title), 
			-- title = title, 
			text = tostring(text)
		}
	)
end

-- mor info from HappyLooser
function PlaceableHusbandryAnimals.setMoreInfos(clusters, isHorse)
	local moreInfos = {};
	if clusters ~= nil and type(clusters) == "table" and #clusters > 0 then
		local totalSellPrice = 0;
		local horseClusters = 0;
		local healthClusters = 0;
		local health = 0;
		local highestHealth = 0;
		local lowestHealth = 0;
		local reproductionClusters = 0;
		local reproduction = 0;
		local highestReproduction = 0;
		local lowestReproduction = nil;
		local beforeReproductionClusters = 0;
		local beforeReproduction = 0;
		local highestBeforeReproduction = 0;
		local lowestBeforeReproduction = nil;
		local durationClusters = 0;
		local duration = 0;
		local highestDuration = 0;
		local lowestDuration = nil;
		local fitness = 0;
		local highestFitness = 0;
		local lowestFitness = 0;
		local dirt = 0;
		local highestDirt = 0;
		local lowestDirt = 0;
		local riding = 0;
		local highestRiding = 0;
		local lowestRiding = 0;
		local nextBirthIn = 0;
		
		for _, cluster in ipairs(clusters) do
			totalSellPrice = totalSellPrice + cluster:getSellPrice();
			if cluster.health > highestHealth then highestHealth = cluster.health;end;
			if (cluster.health < lowestHealth) or lowestHealth == 0 then lowestHealth = cluster.health;end;
			health = health + cluster.health;
			healthClusters = healthClusters+1;
			local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster.subTypeIndex);
			if subType ~= nil then
				if subType.supportsReproduction and subType.reproductionMinHealth <= cluster:getHealthFactor() and subType.reproductionMinAgeMonth <= cluster.age then
					-- reproduktionzeit der Tiere ausrechnen
					duration = duration + subType.reproductionDurationMonth;
					durationClusters = durationClusters+1;					
					if subType.reproductionDurationMonth > highestDuration then highestDuration = subType.reproductionDurationMonth;end;
					if lowestDuration == nil then lowestDuration = subType.reproductionDurationMonth;end;
					if subType.reproductionDurationMonth < lowestDuration then lowestDuration = subType.reproductionDurationMonth;end;
				end;
				if cluster.age < subType.reproductionMinAgeMonth then
					-- Rate für 
					local minAgeFactor = MathUtil.clamp(cluster.age / subType.reproductionMinAgeMonth, 0, 1) * 100
					if minAgeFactor > highestBeforeReproduction then highestBeforeReproduction = minAgeFactor;end;
					if lowestBeforeReproduction == nil then lowestBeforeReproduction = minAgeFactor;end;
					if minAgeFactor < lowestBeforeReproduction then lowestBeforeReproduction = minAgeFactor;end;
					beforeReproduction = beforeReproduction + minAgeFactor;
					beforeReproductionClusters = beforeReproductionClusters+1;
				else
					if cluster.reproduction > highestReproduction then highestReproduction = cluster.reproduction;end;
					if lowestReproduction == nil then lowestReproduction = cluster.reproduction;end;
					if cluster.reproduction < lowestReproduction then lowestReproduction = cluster.reproduction;end;
					reproduction = reproduction + cluster.reproduction;
					reproductionClusters = reproductionClusters+1;
					-- wann der nächste Nachwuchs?
					
					if cluster:getCanReproduce() then
						local months = subType.reproductionDurationMonth - (subType.reproductionDurationMonth * cluster:getReproductionFactor())
						if nextBirthIn == 0 then nextBirthIn = months;end;
						if months < nextBirthIn then nextBirthIn = months;end;
					end
				end;
			end;
			if isHorse and cluster.dirt ~= nil and cluster.fitness ~= nil and cluster.riding ~= nil then							
				horseClusters = horseClusters+1;
				if cluster.dirt > highestDirt then highestDirt = cluster.dirt;end;
				if (cluster.dirt < lowestDirt) or lowestDirt == 0 then lowestDirt = cluster.dirt;end;
				dirt = dirt + cluster.dirt;						
				if cluster.fitness > highestFitness then highestFitness = cluster.fitness;end;
				if (cluster.fitness < lowestFitness) or lowestFitness == 0 then lowestFitness = cluster.fitness;end;
				fitness = fitness + cluster.fitness;
				if cluster.riding > highestRiding then highestRiding = cluster.riding;end;
				if (cluster.riding < lowestRiding) or lowestRiding == 0 then lowestRiding = cluster.riding;end;
				riding = riding + cluster.riding;						
			end;
		end;
		
		moreInfos.totalSellPrice = totalSellPrice;
		
		if healthClusters == 0 then 
			moreInfos.healthClusters = nil;
		else
			moreInfos.health = health / healthClusters;
		end
		moreInfos.highestHealth = highestHealth;
		moreInfos.lowestHealth = lowestHealth;
		
		if durationClusters == 0 then 
			moreInfos.durationClusters = nil;
		else
			moreInfos.duration = duration / durationClusters;
		end
		moreInfos.highestDuration = highestDuration;
		moreInfos.lowestDuration = lowestDuration or 0;
		
		if reproductionClusters == 0 then 
			moreInfos.reproductionClusters = nil;
		else
			moreInfos.reproduction = reproduction / reproductionClusters;
		end
		moreInfos.highestReproduction = highestReproduction;
		moreInfos.lowestReproduction = lowestReproduction or 0;
				
		if beforeReproduction == 0 then 
			moreInfos.beforeReproduction = nil;
		else
			moreInfos.beforeReproduction = beforeReproduction / beforeReproductionClusters;
		end
		moreInfos.highestBeforeReproduction = highestBeforeReproduction;
		moreInfos.lowestBeforeReproduction = lowestBeforeReproduction or 0;
		moreInfos.nextBirthIn = nextBirthIn;
		
		if isHorse then
			if horseClusters == 0 then 
				moreInfos.dirt = nil;
			else
				moreInfos.dirt = 100 - (dirt / horseClusters);
			end
			moreInfos.highestDirt = 100 - highestDirt;
			moreInfos.lowestDirt = 100 - lowestDirt;
			
			if horseClusters == 0 then 
				moreInfos.fitness = nil;
			else
				moreInfos.fitness = fitness / horseClusters;
			end
			moreInfos.highestFitness = highestFitness;
			moreInfos.lowestFitness = lowestFitness;
			
			if horseClusters == 0 then 
				moreInfos.riding = nil;
			else
				moreInfos.riding = riding / horseClusters;
			end
			moreInfos.highestRiding = highestRiding;
			moreInfos.lowestRiding = lowestRiding;
		end;				
	end;
	return moreInfos;
end;

function InfoDisplayExtension:updateInfoPlaceableHusbandryFood(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryFood
	local fillLevel = self:getTotalFood()
	local capacity = self:getFoodCapacity()
	spec.info.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryFood.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryFood.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryFood)

function InfoDisplayExtension:updateInfoPlaceableHusbandryMilk(_, superFunc, infoTable)
	local spec = self.spec_husbandryMilk

	superFunc(self, infoTable)

	local fillLevel = self:getHusbandryFillLevel(spec.fillType)
	local capacity = self:getHusbandryCapacity(spec.fillType)
	spec.info.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryMilk.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryMilk.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryMilk)

function InfoDisplayExtension:updateInfoPlaceableHusbandryLiquidManure(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryLiquidManure;
	local fillLevel = self:getHusbandryFillLevel(spec.fillType);
	local capacity = self:getHusbandryCapacity(spec.fillType);
	spec.info.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryLiquidManure.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryLiquidManure.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryLiquidManure)

function InfoDisplayExtension:updateInfoPlaceableHusbandryStraw(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryStraw;
	local fillLevel = self:getHusbandryFillLevel(spec.inputFillType);
	local capacity = self:getHusbandryCapacity(spec.inputFillType);
	spec.info.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

	table.insert(infoTable, spec.info)
end
PlaceableHusbandryStraw.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryStraw.updateInfo, InfoDisplayExtension.updateInfoPlaceableHusbandryStraw)

function InfoDisplayExtension:updateInfoPlaceableHusbandryWater(_, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryWater

	if not spec.automaticWaterSupply then
		local fillLevel = self:getHusbandryFillLevel(spec.fillType);
		local capacity = self:getHusbandryCapacity(spec.fillType);
		spec.info.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

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

	local fillLevel = spec.manureHeap:getFillLevel(spec.manureHeap.fillTypeIndex);
	local capacity = spec.manureHeap:getCapacity(spec.manureHeap.fillTypeIndex);
	spec.infoFillLevel.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

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

			-- nur den ersten filltype abfragen, da die anderen da schon drin sind
			fillLevel = self:getFillLevel(info.fillTypes[1]);
			capacity = self.fillTypeToUnloadingSpot[info.fillTypes[1]].capacity;

			info.text = InfoDisplayExtension:formatCapacity(fillLevel, capacity, 0);

			table.insert(infoTable, info)
		end
	end
end
FeedingRobot.updateInfo = Utils.overwrittenFunction(FeedingRobot.updateInfo, InfoDisplayExtension.updateInfoFeedingRobot)

function InfoDisplayExtension:PlayerHUDUpdaterShowSplitShapeInfo(superFunc, splitShape)
--[[ original aus Patch 1.8.1 überschrieben
Grund:
Weitere informationen zu Bäumen anzeigen.]]
	if not entityExists(splitShape) or not getHasClassId(splitShape, ClassIds.MESH_SPLIT_SHAPE) then
		return
	end

	local splitTypeId = getSplitType(splitShape)

	if splitTypeId == 0 then
		return
	end

	local isSplit = getIsSplitShapeSplit(splitShape)
	local isStatic = getRigidBodyType(splitShape) == RigidBodyType.STATIC

	if isSplit and isStatic then
		return
	end

	local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(splitShape)
	local splitType = g_splitTypeManager:getSplitTypeByIndex(splitTypeId)
	local splitTypeName = splitType and splitType.title
	local length = math.max(sizeX, sizeY, sizeZ)
	local box = self.objectBox

	box:clear()

	if isSplit then
		box:setTitle(g_i18n:getText("infohud_wood"))
	else
		box:setTitle(g_i18n:getText("infohud_tree"))		
	end

	if splitTypeName ~= nil then
		box:addLine(g_i18n:getText("infohud_type"), splitTypeName)
	end

	box:addLine(g_i18n:getText("infohud_length"), g_i18n:formatNumber(length, 1) .. " m")
	
	-- durchmesser ist auch interessant
	local diameter = math.min(sizeX, sizeY, sizeZ)
	box:addLine(g_i18n:getText("infohud_diameter"), g_i18n:formatNumber(diameter, 1) .. " m")

	if g_currentMission:getIsServer() and not isStatic then
		local mass = getMass(splitShape)

		box:addLine(g_i18n:getText("infohud_mass"), g_i18n:formatMass(mass))
	end
	
	if not isSplit then
		-- Anzeigenzusätzlicher informationen
		local foundTree = nil;
		
		-- in 3 ebenen suchen erst mal
		local splitShapeParent = getParent(splitShape);
		local splitShapeGrandParent = getParent(splitShapeParent);
		
		-- suchen der Infos in den treesData.growingTrees
		for id, tree in pairs(g_treePlantManager.treesData.growingTrees) do
			if tree.node == splitShape or tree.node == splitShapeParent or tree.node == splitShapeGrandParent then
				foundTree = tree;
			end
		end
		for id, tree in pairs(g_treePlantManager.treesData.splitTrees) do
			if tree.node == splitShape or tree.node == splitShapeParent or tree.node == splitShapeGrandParent then
				foundTree = tree;
			end
		end
		
		if foundTree ~= nil then
			local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromIndex(foundTree.treeType)
			
			local growStateText = g_i18n:getText("infohud_fullGrown");
			if foundTree.growthState ~= 1 then
				local numOfGrowStates = table.getn(treeTypeDesc.treeFilenames);
				local growthStateI = math.floor(foundTree.growthState * (numOfGrowStates - 1)) + 1
				growStateText = tostring(growthStateI) .. " / " .. tostring(numOfGrowStates);
			end
			box:addLine(g_i18n:getText("infohud_growthState"), growStateText)
			
			-- alter in Stunden mit Angabe des maximal alters
			local ageText = g_i18n:getText("infohud_fullGrown");
			if foundTree.growthState ~= 1 then
				local totalGrowHours = treeTypeDesc.growthTimeHours / g_currentMission.environment.timeAdjustment;
				local ageInHours = totalGrowHours * foundTree.growthState;
				ageText = g_i18n:formatNumber(ageInHours) .. " / " .. g_i18n:formatNumber(totalGrowHours) .. "h";
			end
			
			box:addLine(g_i18n:getText("infohud_ageInHours"), ageText)
		end
	end

	box:showNextFrame()
end
PlayerHUDUpdater.showSplitShapeInfo = Utils.overwrittenFunction(PlayerHUDUpdater.showSplitShapeInfo, InfoDisplayExtension.PlayerHUDUpdaterShowSplitShapeInfo)

-- hier brauche ich nicht überschreiben, nur direkt die funktion möglich machen reicht.
function Wearable:showInfo(superFunc, box)
	-- print(string.format("Wearable.showInfo(%s, %s)", superFunc, box));
	-- local damage = self.spec_wearable.damage
	if self.ideNeededPowerValue == nil then
		
		local neededPower = PowerConsumer.loadSpecValueNeededPower(self.xmlFile)
		
		self.ideNeededPowerValue = neededPower.base;
		
		if self.configurations.powerConsumer ~= nil then
			self.ideNeededPowerValue = neededPower.config[self.configurations.powerConsumer];
		end
		
		if self.ideNeededPowerValue == nil then
			self.ideNeededPowerValue = 0;
		end
	end

	if self.ideNeededPowerValue ~= nil and self.ideNeededPowerValue ~= 0 then
		local hp, kw = g_i18n:getPower(self.ideNeededPowerValue)
		local neededPower = string.format(g_i18n:getText("shop_neededPowerValue"), MathUtil.round(kw), MathUtil.round(hp));
		box:addLine(g_i18n:getText("shop_neededPower"), neededPower)
	end

	superFunc(self, box)
end

function InfoDisplayExtension:showInfo(box)
	if self.ideHasPower == nil then
		local powerConfig = Motorized.loadSpecValuePowerConfig(self.xmlFile)
		
		self.ideHasPower = 0;
		
		if powerConfig ~= nil then
			for configName, config in pairs(self.configurations) do
				local configPower = powerConfig[configName][config]

				if configPower ~= nil then
					self.ideHasPower = configPower
				end
			end
		end
	end
	
	if self.ideHasPower ~= nil and self.ideHasPower ~= 0 then
		local hp, kw = g_i18n:getPower(self.ideHasPower)
		local neededPower = string.format(g_i18n:getText("shop_neededPowerValue"), MathUtil.round(kw), MathUtil.round(hp));
		box:addLine(g_i18n:getText("infoDisplayExtension_currentPower"), neededPower)
	end
end

Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, InfoDisplayExtension.showInfo)

function InfoDisplayExtension:updateInfoRollercoasterStateBuilding(superFunc, infoTable)
	table.insert(infoTable, self.infoBoxRequiredGoods)
	
	local remainingSeconds = 0;

	for i, input in ipairs(self.inputs) do
		if input.remainingAmount > 0 then
			local fillLevel = self.rollercoaster:getFillLevel(input.fillType.index);
			local missing = math.max(0, input.remainingAmount - fillLevel)
			if missing ~= 0 then
				input.infoTableEntry.text = InfoDisplayExtension:formatVolume(input.remainingAmount, 0) .. " (" .. g_i18n:getText("infohud_missing") .. " " .. InfoDisplayExtension:formatVolume(missing, 0) .. ")";
			end
			
			-- restlaufzeit bis state ende
			if input.remainingAmount > 0 then
				local remainSecondsHere = input.remainingAmount / input.usagePerSecond;
				remainingSeconds = math.max(remainingSeconds, remainSecondsHere)
			end
			
			table.insert(infoTable, input.infoTableEntry)
		end
	end
	
	table.insert(infoTable, {
		title = g_i18n:getText("infohud_remaingTime"),
		text = g_i18n:formatMinutes(remainingSeconds / 60)
	})
end

function InfoDisplayExtension:updateInfoBoatyardStateBuilding(superFunc, infoTable)
	table.insert(infoTable, self.infoBoxRequiredGoods)
	
	local remainingSeconds = 0;

	for i, input in ipairs(self.inputs) do
		if input.remainingAmount > 0 then
			local fillLevel = self.boatyard:getFillLevel(input.fillType.index);
			local missing = math.max(0, input.remainingAmount - fillLevel)
			if missing ~= 0 then
				input.infoTableEntry.text = InfoDisplayExtension:formatVolume(input.remainingAmount, 0) .. " (" .. g_i18n:getText("infohud_missing") .. " " .. InfoDisplayExtension:formatVolume(missing, 0) .. ")";
			end
			
			-- restlaufzeit bis state ende
			if input.remainingAmount > 0 then
				local remainSecondsHere = input.remainingAmount / input.usagePerSecond;
				remainingSeconds = math.max(remainingSeconds, remainSecondsHere)
			end
			
			table.insert(infoTable, input.infoTableEntry)
		end
	end
	
	table.insert(infoTable, {
		title = g_i18n:getText("infohud_remaingTime"),
		text = g_i18n:formatMinutes(remainingSeconds / 60)
	})
end

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
	
	-- prüfen ob dlc aktiv
	if g_modIsLoaded["pdlc_forestryPack"] then
		pdlc_forestryPack.RollercoasterStateBuilding.updateInfo = Utils.overwrittenFunction(pdlc_forestryPack.RollercoasterStateBuilding.updateInfo, InfoDisplayExtension.updateInfoRollercoasterStateBuilding)
		pdlc_forestryPack.BoatyardStateBuilding.updateInfo = Utils.overwrittenFunction(pdlc_forestryPack.BoatyardStateBuilding.updateInfo, InfoDisplayExtension.updateInfoBoatyardStateBuilding)
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