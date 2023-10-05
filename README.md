# pixid Uploader Lightroom plugin
Photography Workflow Automation; with your camera tethered to Lightroom, your photo is going to get presets applied, exported to disk, uploaded to **[pixid](https://www.pixid.app/)** to display instantly to your client in our gallery *[sample gallery](https://www.pixid.app/g/48cb0cfa3aca694199ded43e1112f3ab)*

### Installation
1. Download plugin as a zip file from this *[link](https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/archive/refs/heads/main.zip)*. Then extract zip file to your computer.
2. Add the plugin by adding the folder in Lightroom via `File > Plug-in Manager` or press `Ctrl+Alt+Shift+,` (windows) or press `Command+Option+Shift+,` (mac)
   <img width="885" alt="Lightroom-Plugin-Install" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/c77013ca-eb0d-44bc-ad78-a358badf0f4f">

### Usage
1. Prepare your presets in the favorites folder. For convenience you can create a preset that first applies Auto Settings and then another preset to create the look and feel you want to have. For example you can set it up like this:
   
   <img width="276" alt="image" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/55c05da0-0fcc-4d09-8cc2-fab0a6d67171">
2. Open the `Export & Uploader Console` window by navigating to `File > Plug-in Extras > Export & Uploader Console`.
   <img width="570" alt="image" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/06d4a619-c780-40b7-bafb-f27e5cb2b160">
   <img width="707" alt="image" src="https://github.com/three-sixty-five-labs/pixid-lightroom-plugin/assets/3371594/c9b60cab-1af3-4464-b7df-6a520606b727">
3. Configuration options
   - Selet Lightroom folder you want to apply the script to
   - Select output photo size (1500px, 2000px, 4000px, or original size)
   - Select process interval, 60 seconds recommended
   - Specify the output folder (full path)
   - Enable FTP and specific username and password ( In order to enable pixid FTP upload capabilities, please contact pixid vie [Facebook page messenger](https://www.facebook.com/pixidapp) )
4. Now you have two options (A) apply the process just once by pressing `Process once` or (B) start the `Interval process` which run the script every configured interval.
5. This will process all pictures by:
   - Applying the presets in the selected Lightroom folder
   - Rating the processed picture with 2 stars to keep track which pictures do not need to be processed again
   - Exporting full quality JPEG to the specified Output folder
6. Press `Stop interval process` when you want to stop the watcher. If you want to run the script in the background press OK or Cancel. *Note: that it will keep on running as long as Lightroom is open (a more neat solution is yet to be found).*

### Improvements
If you have any suggestions for improvements feel free to open a pull request or creating an issue.

### End Credit
This plugin originally inspired by this [repo of OlafHaalstra](https://github.com/OlafHaalstra/Lightroom-Auto-Import-Export). Thank you.
