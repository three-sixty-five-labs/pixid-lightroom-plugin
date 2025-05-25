-- Access the Lightroom SDK namespaces.
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

local LrPathUtils = import 'LrPathUtils'
local LrFtp = import 'LrFtp'
local LrFileUtils = import 'LrFileUtils'
local LrErrors = import 'LrErrors'

local LrColor = import 'LrColor'

local LrLogger = import 'LrLogger'
local myLogger = LrLogger( 'exportLogger' )
myLogger:enable( 'print' )

require "config"
require "Utils"

local timerId

local timeoutParams = {
	timeout = 5,
	asynchronous = true
}

function outputToLog( message )
	myLogger:trace( message )
end

local operatingSystem = Utils.getOS()

local failures = {}
local ftpFailures = {}

-- Process pictures and save them as JPEG
local function processPhotos(LrCatalog, photos, outputFolder, size, ftpInfo, extra)
	outputToLog("[PROCESS] Start Process")
	LrFunctionContext.callWithContext("export", function(exportContext)
		local progressScope = LrDialogs.showModalProgressDialog({
			title = "Auto Export",
			caption = "starting ...",
			cannotCancel = false,
			functionContext = exportContext
		})

		local exportSettings = {
			LR_collisionHandling = "rename",
			LR_export_bitDepth = "8",
			LR_export_colorSpace = "sRGB",
			LR_export_destinationPathPrefix = outputFolder,
			LR_export_destinationType = "specificFolder",
			LR_export_useSubfolder = false,
			LR_format = "JPEG",
			LR_jpeg_quality = 1,
			LR_minimizeEmbeddedMetadata = true,
			LR_outputSharpeningOn = false,
			LR_reimportExportedPhoto = false,
			LR_renamingTokensOn = true,
			LR_size_doNotEnlarge = true,
			LR_size_units = "pixels",
			LR_tokens = "{{image_name}}",
			LR_useWatermark = false,
			LR_jpeg_useLimitSize = false,
			LR_jpeg_limitSize = null,	
		}

		if size ~= "original" then
			exportSettings['LR_size_doConstrain'] = true
			exportSettings['LR_size_maxHeight'] = tonumber(size)
			exportSettings['LR_size_maxWidth'] = tonumber(size)
			exportSettings['LR_size_resolution'] = 300
		end

		if extra['useFileSizeLimit'] then
			exportSettings['LR_jpeg_useLimitSize'] = true
			exportSettings['LR_jpeg_limitSize'] = tonumber(extra['fileSizeLimit'])
		end

		exportSession = LrExportSession({
			photosToExport = photos,
			exportSettings = exportSettings, 
		})

		local numPhotos = exportSession:countRenditions()
		local renditionParams = {
			progressScope = progressScope,
			renderProgressPortion = 1,
			stopIfCanceled = true,
		}

		local ftpInstance

		if ftpInfo['isEnabled'] then
			--simple table value assignment
			ftpPreset = {}
			ftpPreset["passive"] = "none"
			ftpPreset["path"] = "/"
			ftpPreset["port"] = 21
			ftpPreset["protocol"] = "ftp"
			ftpPreset["server"] = "ftp.pixid.app"
			ftpPreset["username"] = ftpInfo['ftpUsername']
			ftpPreset["password"] = ftpInfo['ftpPassword']

			ftpInstance = LrFtp.create( ftpPreset, true )
			
			if not ftpInstance then -- This really shouldn't ever happen.
				LrErrors.throwUserError( LOC "$$$/FtpUpload/Upload/Errors/InvalidFtpParameters=The specified FTP preset is incomplete and cannot be used." )
			end		
		end

		if extra['presetsInFavoriteIsApplied'] then
			local presetFolders = LrApplication.developPresetFolders()
			local presetFolder = presetFolders[1]
			local presets = presetFolder:getDevelopPresets()
			for i, photo in pairs(photos) do
				progressScope:setCaption("Applying presets (" .. i .. "/" .. numPhotos .. ")")
				progressScope:setPortionComplete(i - 1, numPhotos)

				LrCatalog:withWriteAccessDo("Applying presets ... ", function(context)
						for _, preset in pairs(presets) do
							photo:applyDevelopPreset(preset)
						end
						photo:setRawMetadata("rating", 1)
				end, timeoutParams)
			end
		end

		for i, rendition in exportSession:renditions(renditionParams) do

			if progressScope:isCanceled() then break end -- Stop processing if the cancel button has been pressed

			-- Common caption for progress bar
			local progressCaption = "Exporting " .. rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos .. ")"
			progressScope:setPortionComplete(i - 1, numPhotos)
			progressScope:setCaption(progressCaption)

			local success, pathOrMessage = rendition:waitForRender()
		
			if progressScope:isCanceled() then break end -- Check for cancellation again after photo has been rendered.
			LrCatalog:withWriteAccessDo("processing", function(context)	
				rendition.photo:setRawMetadata("rating", 2)
			end, timeoutParams)

			if success and ftpInfo['isEnabled'] then

				local filename = LrPathUtils.leafName( pathOrMessage )		
				local ftpSuccess = ftpInstance:putFile( pathOrMessage, filename )
				
				if not ftpSuccess then -- if file can't be exported, keep in a table
					table.insert( ftpFailures, filename )
				end
						
				-- When done with photo, delete temp file. There is a cleanup step that happens later,
				-- but this will help manage space in the event of a large upload.
				-- LrFileUtils.delete( pathOrMessage )
				LrCatalog:withWriteAccessDo("processing", function(context)	
					rendition.photo:setRawMetadata("rating", 3)
				end, timeoutParams)
			end

			if progressScope:isCanceled() then break end -- Check for cancellation again after photo has been rendered.

			if not success then -- if file can't be FTPed, keep in a table
				table.insert( failures, filename )
			end

		end

		if LrTasks.canYield() then
			LrTasks.yield()
		end

		if ftpInfo['isEnabled'] then
			ftpInstance:disconnect()
		end
		
	end)

	if LrTasks.canYield() then
		LrTasks.yield()
	end

	if progressScope then 
		progressScope:done()
	end
	outputToLog("[PROCESS] finish process")
end

-- Import pictures from folder where the rating is not 3 stars 
local function importFolder(LrCatalog, folder, outputFolder, size, ftpInfo, extra)
	outputToLog("[IMPORT] Start Import")
	local photos = folder:getPhotos()
	local photosToExport = {}

	for _, photo in pairs(photos) do
		local rating = photo:getRawMetadata("rating") or 0
		if rating == 0 then	
			table.insert(photosToExport, photo)

			-- if #photosToExport >= 3 then
			-- 	break  -- Stop processing after the first three photos
			-- end
		end
	end

	if #photosToExport > 0 then
		LrDialogs.showBezel(#photosToExport .. " photos to process")
		outputToLog("[IMPORT] found " ..  #photosToExport .. " photos to process")
		processPhotos(LrCatalog, photosToExport, outputFolder, size, ftpInfo, extra)
	else
		outputToLog("[IMPORT] nothing to process")
	end

outputToLog("[IMPORT] finish import")
end

-- GUI specification
local function mainDialog()
	LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)

		local props = LrBinding.makePropertyTable(context)
		local f = LrView.osFactory()

		local operatingSystemValue = f:static_text {
			title = Utils.getOS()
		}

		local outputFolderField = f:static_text {
			title = ( operatingSystem == "Windows" ) and "C:\\Pictures" or Utils.getHome() .. "/Pictures",
			value = ( operatingSystem == "Windows" ) and "C:\\Pictures" or Utils.getHome() .. "/Pictures",
			width = 500,
			truncate = 'head', 
		}

		local selectFolderButtonField = f:push_button {
				title = "Select Output Folder",
				action = function()
					local success, result = pcall(function()
						return LrDialogs.runOpenPanel {
								title = "Select Output Folder",
								canChooseFiles = false,
								canChooseDirectories = true,
								allowsMultipleSelection = false,
						}
					end)
				
					if success and result and #result > 0 then
						outputFolderField.value = tostring(result[1])
						outputFolderField.title = tostring(result[1])
					end
				end,
		}

		local sizeField = f:combo_box {
			items = {"2000", "3000", "4000", "5000", "6000", "original"},
			value = "2000",
			immediate = true,
		}

		local ftpUsernameField = f:edit_field {
			immediate = true,
			width = 100,
			value = "",
		}

		local ftpPasswordField = f:password_field {
			immediate = true,
			width = 100,
			value = "",
		}	

		local ftpIsEnabledCheckbox =  f:checkbox {
			title = "Enable FTP Upload",
			value = false,
			immediate = true,
		}

		local presetsInFavoriteIsAppliedCheckbox =  f:checkbox {
			title = "",
			value = false,
			immediate = true,
		}

		local useFileSizeLimitCheckbox =  f:checkbox {
			title = "",
			value = false,
			immediate = true,
		}

		local fileSizeLimitField = f:edit_field {
			immediate = true,
			width = 100,
			value = "750",
		}

		local statusText = f:static_text {
			title = "Not started",
			text_color = LrColor("blue")
		}

		local VERSION = require 'Info'.VERSION

		local versionField = f:static_text {
			title = string.format("Version: %d.%d.%d (Build %d)", VERSION.major, VERSION.minor, VERSION.revision, VERSION.build),
			alignment = "left",
			width = 500,
	}

		local function statusUpdateFunction()
			statusText.title = props.myObservedString
		end

		-- Setting default value for input
		if config['outputFolder'] ~= nil and config['outputFolder'] ~= '' then outputFolderField.value = config['outputFolder'] end
		if config['outputFolder'] ~= nil and config['outputFolder'] ~= '' then outputFolderField.title = config['outputFolder'] end
		if config['size'] ~= nil         and config['size'] ~= ''         then sizeField.value = config['size'] end
		if config['ftpUsername'] ~= nil  and config['ftpUsername'] ~= ''  then ftpUsernameField.value = config['ftpUsername'] end
		if config['ftpPassword'] ~= nil  and config['ftpPassword'] ~= ''  then ftpPasswordField.value = config['ftpPassword'] end
		if config['ftpIsEnabled'] ~= nil and config['ftpIsEnabled'] ~= '' then ftpIsEnabledCheckbox.value = config['ftpIsEnabled'] end
		if config['presetsInFavoriteIsApplied'] ~= nil and config['presetsInFavoriteIsApplied'] ~= '' then presetsInFavoriteIsAppliedCheckbox.value = config['presetsInFavoriteIsApplied'] end
		if config['useFileSizeLimit'] ~= nil and config['useFileSizeLimit'] ~= '' then useFileSizeLimitCheckbox.value = config['useFileSizeLimit'] end
		if config['fileSizeLimitKB'] ~= nil and config['fileSizeLimitKB'] ~= '' then fileSizeLimitField.value = config['fileSizeLimitKB'] end
		
		local sleepSeconds
		if config['sleep'] ~= nil and config['sleep'] ~= '' then sleepSeconds = config['sleep'] end

		
		LrTasks.startAsyncTask(function()
			local LrCatalog = LrApplication.activeCatalog()
			local catalogFolders = LrCatalog:getFolders()
			local folderCombo = {}
			local folderIndex = {}
			for i, folder in pairs(catalogFolders) do
				folderCombo[i] = folder:getName()
				folderIndex[folder:getName()] = i
			end

			local folderField = f:combo_box {
				items = folderCombo,
				immediate = true,
			}

			if config['lightroomFolder'] ~= nil and config['lightroomFolder'] ~= '' then folderField.value = config['lightroomFolder'] end

			local watcherRunning = false

			-- local function watch(ftpInfo, extra)
			-- 	outputToLog("[WATCH] Start Watcher")
			-- 	LrTasks.startAsyncTask(function()
			-- 		while watcherRunning do
			-- 			LrDialogs.showBezel("checking photos to process")
			-- 			outputToLog("[WATCH] Start calling importFolder")

			-- 			importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, sizeField.value, ftpInfo, extra)

			-- 			if LrTasks.canYield() then
			-- 					LrTasks.yield()
			-- 					outputToLog("[WATCH] calling importFolder is done")
			-- 			end

			-- 			-- Sleep using PowerShell or other platform-specific command
			-- 			-- if operatingSystem == "Windows" then
			-- 			-- 		LrTasks.execute("powershell Start-Sleep -Seconds " .. interval)
			-- 			-- else
			-- 			-- 		LrTasks.execute("sleep " .. interval)
			-- 			-- end
			-- 			outputToLog("[WATCH] Finishg a watch loop - Sleep between batch " .. sleepSeconds .." seconds")
			-- 			LrTasks.sleep(sleepSeconds)
			-- 		end
			-- 		outputToLog("[WATCH] Exit Watcher")
			-- 	end)
			-- end

			props:addObserver("myObservedString", statusUpdateFunction)

			local c = f:column {
				spacing = f:dialog_spacing(),
				f:row {
					fill_horizontal = 1,
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Operating system: "
					},
					operatingSystemValue,
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Select Lightroom Folder: "
					},
					folderField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Max Width/Height(px): "
					},
					sizeField
				},
				-- f:row {
				-- 	f:static_text {
				-- 		alignment = "right",
				-- 		width = LrView.share "label_width",
				-- 		title = "Interval (second): ",
				-- 	},
				-- 	intervalField
				-- },
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Output Folder: "
					},
					selectFolderButtonField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = ""
					},
					outputFolderField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Apply all presets in Favorite:"
					},
					presetsInFavoriteIsAppliedCheckbox
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Use File Size Limit:"
					},
					useFileSizeLimitCheckbox
				},
				f:row {
					f:static_text {
							alignment = "right",
							width = LrView.share "label_width",
							title = "File Size Limit (kb):",
					},
					fileSizeLimitField
				},
				f:row {
					f:separator { fill_horizontal = 1 }
				},
				f:row {
					ftpIsEnabledCheckbox
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "FTP Username: "
					},
					ftpUsernameField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "FTP Password: "
					},
					ftpPasswordField
				},
				f:row {
					f:separator { fill_horizontal = 1 }
				},
				f:row {
					fill_horizontal = 1,
					f:static_text {
						height_in_lines = 2, -- Adjust the height as needed
					},
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Process Status: ",
						text_color = LrColor("blue"),
					},
					statusText,
				},
				f:row {
					f:static_text {
						height_in_lines = 2, -- Adjust the height as needed
					},
					f:push_button {
						title = "do once // ครั้งเดียว",
						action = function()
							if folderField.value ~= nil and folderField.value ~= "" then
								props.myObservedString = "Processed once"
								ftpInfo = {}
								ftpInfo['isEnabled'] = ftpIsEnabledCheckbox.value
								ftpInfo['ftpUsername'] = ftpUsernameField.value
								ftpInfo['ftpPassword'] = ftpPasswordField.value
								extra = {}
								extra['presetsInFavoriteIsApplied'] = presetsInFavoriteIsAppliedCheckbox.value
								extra['useFileSizeLimit'] = useFileSizeLimitCheckbox.value
								extra['fileSizeLimit'] = fileSizeLimitField.value

								LrTasks.startAsyncTask(function()
									importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, sizeField.value, ftpInfo, extra)

									if LrTasks.canYield() then
										LrTasks.yield()
									end
								end)
							else
								LrDialogs.message("Please select an input folder")
							end
						end
					},
					f:push_button {
						title = "continuous // ต่อเนื่อง",
						action = function()
							watcherRunning = true
							LrDialogs.message("Alert", "ถ้าต้องการจบการทำงานให้กดปุ่ม 'Stop // หยุดทำ' \n\n Need to click 'Stop // หยุดทำ' button before OK or Cancel to close this plugin", "info")
							if folderField.value ~= nil and folderField.value ~= "" then
								props.myObservedString = "Running"
								ftpInfo = {}
								ftpInfo['isEnabled'] = ftpIsEnabledCheckbox.value
								ftpInfo['ftpUsername'] = ftpUsernameField.value
								ftpInfo['ftpPassword'] = ftpPasswordField.value
								extra = {}
								extra['presetsInFavoriteIsApplied'] = presetsInFavoriteIsAppliedCheckbox.value 
								extra['useFileSizeLimit'] = useFileSizeLimitCheckbox.value
								extra['fileSizeLimit'] = fileSizeLimitField.value

								outputToLog("[WATCH] Start Watcher")
								LrTasks.startAsyncTask(function()
									while watcherRunning do
										LrDialogs.showBezel("checking photos to process")
										outputToLog("[WATCH] Start calling importFolder")
				
										importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, sizeField.value, ftpInfo, extra)
				
										if LrTasks.canYield() then
												LrTasks.yield()
												outputToLog("[WATCH] calling importFolder is done")
										end
				
										outputToLog("[WATCH] Finishg a watch loop - Sleep between batch " .. sleepSeconds .." seconds")
										LrTasks.sleep(sleepSeconds)
									end
									outputToLog("[WATCH] Exit Watcher")
								end)
							else
								LrDialogs.message("Please select an input folder")
							end
						end
					},
					f:push_button {
						title = "Stop // หยุด",
						action = function()
							props.myObservedString = "Stopped after running"
							watcherRunning = false
						end
					}
				},
				f:row {
					f:separator { fill_horizontal = 1 }
				},
				f:row {
					versionField
				},	
			}

			LrDialogs.presentModalDialog {
				title = "pixid : Auto Preset / Export / Uploader",
				contents = c,
				-- actionVerb = "Need to click 'Stop Interval Process' before Cancel or Close",
			}

		end)

	end)
end

mainDialog()