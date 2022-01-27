# <img align="left" src="https://a-lurker.github.io/icons/Embedded_Data_Systems_50_50.png"> Vera-Plugin-EDS-One-Wire-Server

Acquire data from an Embedded Data Systems One-Wire Server.

This software was originated by Chris Jackson, circa 2011, to run on a Vera. Thanks to Chris for his work on this software; it has worked well on Vera. It's been updated here (2020 - 2022) to work with openLuup and AltUI.

The plugin reads the XML provided by the server at this URL:

http://OWServer_IP_address/details.xml

More information on the EDS OW server here:

[Embedded Data Systems](https://www.embeddeddatasystems.com/)

Note the plugin needs access to a json library. Older Veras won't have one but newer Veras will have dkjson.lua already installed. The plugin searches for a number of different json libraries:

[Refer to this code](https://github.com/a-lurker/Vera-Plugin-EDS-One-Wire-Server/blob/d04c8456384aa158b1fbf8e7efac30faa4c08d23/Luup_device/L_OWServer.lua#L605)

Install the plugin from the Alt App Store: in AltUI go to the "More" tab and select "App Store" from the drop down menu. You will find the plugin under "def" as "EDS One Wire Server". Install it.

Alternatively you can download the files and manually create the plugin in Vera using these values:
| Entry box: AltUI / Vera UI    | Data          |
| ------------- | ------------- |
| Device Name / Description | One Wire Server |
| D_xxx.xml filename / Upnp Device Filename | D_OWServer.xml |
| I_xxx.xml filename / Upnp Implementation Filename | I_OWServer.xml |

- Create the device and restart the Luup Engine.
- Go to the plugin in "No Room" and under the "Attributes" tab, enter the OW server IP address in the "ip" entry box. Save the IP address setting and restart the Luup Engine. Once restarted, refresh your browser. Go to the "Settings" tab. It should now show how many devices it has detected.

- Go to the "Add Devices" tab. It should show a list of the devices. Set the options for each device. For example, for temperature devices, you can choose "degC" or "degF" or to "Ignore" the device ie do not install the device. Push the "Add" button when ready. The Luup Engine should restart automatically. Once the restart is finished, refresh you browser and all the child devices should now be shown.

The plugin polls the devices every 60 second (the default). This can be made longer but not shorter. Refer to "SamplingPeriod" variable; units are in seconds. However 600 ie 10 minutes is a more realistic value.

Temperatures are averaged every 3 readings, while pressure and humidity are averaged over 10 readings. The value can be changed via the "Average" variable on each child device.

This code allows your own hardware to emulate an Embedded Data Systems server and this plugin could then be used with that hardware:

[OW-SERVER Emulator](https://github.com/dbemowsk/OW-SERVER_Emulator)
