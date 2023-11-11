# pixid Uploader Lightroom plugin
Photography Workflow Automation; with your camera tethered to Lightroom, your photo is going to get automatically exported to disk, uploaded to **[pixid](https://www.pixid.app/)** to display instantly to your client in our gallery *[sample gallery](https://www.pixid.app/g/48cb0cfa3aca694199ded43e1112f3ab)*

## Installation
1. Download plugin as a zip file from this *[link](https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/archive/refs/heads/main.zip)*. Then extract zip file to your computer.
2. Add the plugin by adding the folder in Lightroom via `File > Plug-in Manager` or press `Ctrl+Alt+Shift+,` (windows) or press `Command+Option+Shift+,` (mac)
   <img width="888" alt="image" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/1e2ab508-50ed-451d-9941-26a5ba3fab10">

## Usage
1. Open the `Export & Uploader Console` window by navigating to `File > Plug-in Extras > Export & Uploader Console`.

   <img width="574" alt="image" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/23e1ae69-f2cd-4dab-9d0c-0a7e7f86becc">
   <img width="716" alt="image" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/7e4d296f-54bc-493e-bb3c-c6a290983852">

2. Configuration options
   - Selet Lightroom folder you want to apply the script to
   - Select output photo size (1500px, 2000px, 4000px, or original size)
   - Select process interval, 60 seconds recommended
   - Specify the output folder (full path)
   - Select to whether apply presets in favorite folder or not
   - Enable FTP and specific username and password ( In order to enable pixid FTP upload capabilities, please contact pixid vie [Facebook page messenger](https://www.facebook.com/pixidapp) )
3. Now you have two options (A) apply the process just once by pressing `Process once` or (B) start the `Interval process` which run the script every configured interval.
4. This will process all pictures by:
   - Rating the processed picture with 2 stars to keep track which pictures do not need to be processed again
   - Exporting full quality JPEG to the specified Output folder
5. Press `Stop interval process` when you want to stop the watcher. If you want to run the script in the background press OK or Cancel. *Note: that it will keep on running as long as Lightroom is open (a more neat solution is yet to be found).*

## Improvements
If you have any suggestions for improvements feel free to open a pull request or creating an issue.

## End Credit
This plugin originally inspired by this [repo of OlafHaalstra](https://github.com/OlafHaalstra/Lightroom-Auto-Import-Export). Thank you.
