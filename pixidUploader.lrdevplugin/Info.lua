--[[----------------------------------------------------------------------------

Info.lua
Summary information for ftp_upload sample plug-in

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.


------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'org.365labs.app.pixid.autopresetuploader',

	LrPluginName = LOC "$$$/AutoPresetUploader/PluginName=Pixid Uploader Plug-in",
	
	LrExportMenuItems = {{
		title = "Export & Uploader console ...",
		file = "Uploader.lua",		
	}},

	VERSION = { major=0, minor=1, revision=0, build="20230903", },

}
