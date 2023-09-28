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

local LrLogger = import 'LrLogger'
local myLogger = LrLogger( 'exportLogger' )
myLogger:enable( 'print' )

function outputToLog( message )
	myLogger:trace( message )
end

local function getHome()
	local fh,err = assert(io.popen("echo $HOME 2>/dev/null","r"))
	if fh then
		home = fh:read()
	end

	return home or ""
end 

function getOS()
	-- ask LuaJIT first
	if jit then
		return jit.os
	end

	-- Unix, Linux variants
	local fh,err = assert(io.popen("uname -o 2>/dev/null","r"))
	if fh then
		osname = fh:read()
	end

	if osname == "Darwin" then 
		return "MacOS"
	end
	
	return osname or "Windows"
end

local operatingSystem = getOS()

-- Process pictures and save them as JPEG
local function processPhotos(photos, outputFolder, size, ftpInfo)
	LrFunctionContext.callWithContext("export", function(exportContext)

		local progressScope = LrDialogs.showModalProgressDialog({
			title = "Auto applying presets",
			caption = "",
			cannotCancel = false,
			functionContext = exportContext
		})

		if size == "2000px" then
			exportSession = LrExportSession({
				photosToExport = photos,
				exportSettings = {
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
					LR_size_doConstrain = true,
					LR_size_doNotEnlarge = true,
					LR_size_maxHeight = 2000,
					LR_size_maxWidth = 2000,
					LR_size_resolution = 72,
					LR_size_units = "pixels",
					LR_tokens = "{{image_name}}",
					LR_useWatermark = false,
				}
			})
		else
			exportSession = LrExportSession({
				photosToExport = photos,
				exportSettings = {
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
					-- LR_size_doConstrain = true,
					LR_size_doNotEnlarge = true,
					-- LR_size_maxHeight = 2000,
					-- LR_size_maxWidth = 2000,
					-- LR_size_resolution = 72,
					LR_size_units = "pixels",
					LR_tokens = "{{image_name}}",
					LR_useWatermark = false,
				}
			})
		end

		local numPhotos = exportSession:countRenditions()
		local renditionParams = {
			progressScope = progressScope,
			renderProgressPortion = 1,
			stopIfCanceled = true,
		}

		local ftpInstance

		if ftpInfo['isEnabled'] then
			ftpPreset = {}

			--simple table value assignment
			ftpPreset["passive"] = "none"
			ftpPreset["password"] = ftpInfo['ftpPassword']
			ftpPreset["path"] = "/"
			ftpPreset["port"] = 21
			ftpPreset["protocol"] = "ftp"
			ftpPreset["server"] = "ftp.pixid.app"
			ftpPreset["username"] = ftpInfo['ftpUsername']

			ftpInstance = LrFtp.create( ftpPreset, true )
			
			if not ftpInstance then -- This really shouldn't ever happen.
				LrErrors.throwUserError( LOC "$$$/FtpUpload/Upload/Errors/InvalidFtpParameters=The specified FTP preset is incomplete and cannot be used." )
			end		
		end

		for i, rendition in exportSession:renditions(renditionParams) do

			if progressScope:isCanceled() then break end -- Stop processing if the cancel button has been pressed

			-- Common caption for progress bar
			local progressCaption = rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos .. ")"

			progressScope:setPortionComplete(i - 1, numPhotos)
			progressScope:setCaption("Processing " .. progressCaption)

			local success, pathOrMessage = rendition:waitForRender()
		
			if progressScope:isCanceled() then break end -- Check for cancellation again after photo has been rendered.
			
			if success and ftpInfo['isEnabled'] then
	
				local filename = LrPathUtils.leafName( pathOrMessage )
			
				local success = ftpInstance:putFile( pathOrMessage, filename )
				
				if not success then -- if file can't uploaded, keep in a table
					table.insert( failures, filename )
				end
						
				-- When done with photo, delete temp file. There is a cleanup step that happens later,
				-- but this will help manage space in the event of a large upload.
				
				-- LrFileUtils.delete( pathOrMessage )
						
			end
		end

		if ftpInfo['isEnabled'] then
			ftpInstance:disconnect()
		end
		
	end)
end

-- Import pictures from folder where the rating is not 2 stars 
local function importFolder(LrCatalog, folder, outputFolder, size, ftpInfo)
	local presetFolders = LrApplication.developPresetFolders()
	local presetFolder = presetFolders[1]
	local presets = presetFolder:getDevelopPresets()
	LrTasks.startAsyncTask(function()
		local photos = folder:getPhotos()
		local export = {}

		for _, photo in pairs(photos) do
			if (photo:getRawMetadata("rating") ~= 1 ) then
				LrCatalog:withWriteAccessDo("Apply Preset", function(context)
					for _, preset in pairs(presets) do
						photo:applyDevelopPreset(preset)
					end
					photo:setRawMetadata("rating", 1)
					table.insert(export, photo)
				end)
			end
		end

		if #export > 0 then
			processPhotos(export, outputFolder, size, ftpInfo)
		end
	end)
end

-- GUI specification
local function mainDialog()
	LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)

		local props = LrBinding.makePropertyTable(context)
		local f = LrView.osFactory()

		local operatingSystem = getOS()
		local operatingSystemValue = f:static_text {
			title = operatingSystem
		}

		local outputFolderField = f:edit_field {
			immediate = true,
			width = 500,
			value = ( operatingSystem == "Windows" ) and "C:\\Pictures" or getHome() .. "/Pictures" 
		}

		local ftpUsernameField = f:edit_field {
			immediate = true,
			width = 100,
			value = "" 
		}

		local ftpPasswordField = f:password_field {
			immediate = true,
			width = 100,
			value = "" 
		}	

		local ftpIsEnabledCheckbox =  f:checkbox {
			title = "Enable FTP Upload",
			value = false,
			-- value = bind 'checkbox_state', -- bind to the key value checked_value = 'checked', -- this is the initial state unchecked_value = 'unchecked', -- when the user unchecks the box,
		}

		local staticTextValue = f:static_text {
			title = "Not started",
		}

		local function myCalledFunction()
			staticTextValue.title = props.myObservedString
		end

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
				items = folderCombo
			}

			local sizeField = f:combo_box {
				items = {"2000px", "original"},
				value = "2000px"
			}

			local intervalField = f:combo_box {
				items = {"3", "15", "30", "60"},
				value = "3",
				width_in_digits = 3
			}

			local watcherRunning = false

			-- Watcher, executes function and then sleeps x seconds using PowerShell
			local function watch(interval, ftpInfo)
				LrTasks.startAsyncTask(function()
					while watcherRunning do
						LrDialogs.showBezel("Processing images.")
						importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, sizeField.value, ftpInfo)
						if LrTasks.canYield() then
							LrTasks.yield()
						end
						if operatingSystem == "Windows" then
							LrTasks.execute("powershell Start-Sleep -Seconds " .. interval)
						else
							LrTasks.execute("sleep " .. interval)
						end
					end
				end)
			end

			props:addObserver("myObservedString", myCalledFunction)

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
						title = "Size: "
					},
					sizeField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Interval (second): ",
					},
					intervalField
				},
				f:row {
					f:static_text {
						alignment = "right",
						width = LrView.share "label_width",
						title = "Output Folder: "
					},
					outputFolderField
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
						alignment = "right",
						width = LrView.share "label_width",
						title = "Watcher running: "
					},
					staticTextValue,
				},
				f:row {
					f:push_button {
						title = "Process once",
						action = function()
							if folderField.value ~= "" then
								props.myObservedString = "Processed once"
								ftpInfo = {}
								ftpInfo['isEnabled'] = ftpIsEnabledCheckbox.value
								ftpInfo['ftpUsername'] = ftpUsernameField.value
								ftpInfo['ftpPassword'] = ftpPasswordField.value
								importFolder(LrCatalog, catalogFolders[folderIndex[folderField.value]], outputFolderField.value, sizeField.value, ftpInfo)
							else
								LrDialogs.message("Please select an input folder")
							end
						end
					},
					f:push_button {
						title = "Interval process",

						action = function()
							watcherRunning = true
							if folderField.value ~= "" then
								props.myObservedString = "Running"
								ftpInfo = {}
								ftpInfo['isEnabled'] = ftpIsEnabledCheckbox.value
								ftpInfo['ftpUsername'] = ftpUsernameField.value
								ftpInfo['ftpPassword'] = ftpPasswordField.value
								watch(intervalField.value, ftpInfo)
							else
								LrDialogs.message("Please select an input folder")
							end
						end
					},
					f:push_button {
						title = "Stop interval process",

						action = function()
							watcherRunning = false
							props.myObservedString = "Stopped after running"
						end
					}
				},
			}

			LrDialogs.presentModalDialog {
				title = "pixid : Auto Import / Export / FTP",
				contents = c,
			}

		end)

	end)
end

mainDialog()


