--[[
    Embedded Data Systems One-Wire Server plugin

    This software was originated by Chris Jackson, (c) Chris Jackson
    Thanks to Chris for his work on this software.
    Modified and updated by a-lurker, July 2020

    Modifications and updates by a-lurker to the orginal program
    is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    version 3 (GPLv3) as published by the Free Software Foundation;

    In addition to the GPLv3 License, this software is only for private
    or home useage. Commercial utilisation is not authorized.

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
]]

local PLUGIN_NAME     = 'OWServer'
local PLUGIN_SID      = 'urn:upnp-org:serviceId:OWServer1'
local PLUGIN_VERSION  = '0.52'
local THIS_LUL_DEVICE = nil

local m_json         = nil
local m_childDevices = {}
local m_newDevices   = {}

local m_OWServerTimeout = 10

local CD_JACKSON_SID = "urn:cd-jackson-com:serviceId"

local TEMPERATURE = {
    DEVICE       = "urn:schemas-micasaverde-com:device:TemperatureSensor:1",
    SERVICE      = "urn:upnp-org:serviceId:TemperatureSensor1",
    DEVICE_FILE  = "D_TemperatureSensor1.xml",
    SERVICE_FILE = "S_TemperatureSensor1.xml",
    VARIABLE     = "CurrentTemperature"
}

local DOORSENSOR = {
    DEVICE       = "urn:schemas-micasaverde-com:device:DoorSensor:1",
    SERVICE      = "urn:micasaverde-com:serviceId:SecuritySensor1",
    DEVICE_FILE  = "D_DoorSensor1.xml",
    SERVICE_FILE = "S_SecuritySensor1.xml",
    VARIABLE     = "Tripped"
}

local HUMIDITY = {
    DEVICE       = "urn:schemas-micasaverde-com:device:HumiditySensor:1",
    SERVICE      = "urn:micasaverde-com:serviceId:HumiditySensor1",
    DEVICE_FILE  = "D_HumiditySensor1.xml",
    SERVICE_FILE = "S_HumiditySensor1.xml",
    VARIABLE     = "CurrentLevel"
}

local BINARYLIGHT = {
    DEVICE       = "urn:schemas-upnp-org:device:BinaryLight:1",
    SERVICE      = "urn:upnp-org:serviceId:SwitchPower1",
    DEVICE_FILE  = "D_BinaryLight1.xml",
    SERVICE_FILE = "S_SwitchPower1.xml",
    VARIABLE     = "Status"
}

local LIGHTSENSOR = {
    DEVICE       = "urn:schemas-micasaverde-com:device:LightSensor:1",
    SERVICE      = "urn:micasaverde-com:serviceId:LightSensor1",
    DEVICE_FILE  = "D_LightSensor1.xml",
    SERVICE_FILE = "S_LightSensor1.xml",
    VARIABLE     = "CurrentLevel"
}

local PRESSURESENSOR = {
    DEVICE       = "urn:schemas-cd-jackson-com:device:OWPressureSensor:1",
    SERVICE      = CD_JACKSON_SID..":OWPressureSensor1",
    DEVICE_FILE  = "D_OWPressureSensor.xml",
    SERVICE_FILE = "S_OWPressureSensor.xml",
    VARIABLE     = "CurrentPressure"
}

-- HACK not fully implemented
local COUNTER = {
    DEVICE       = "urn:schemas-cd-jackson-com:device:OWCounter:1",
    SERVICE      = CD_JACKSON_SID..":OWCounter1",
    DEVICE_FILE  = "D_OWCounter.xml",
    SERVICE_FILE = "S_OWCounter.xml",
    VARIABLE     = ""
}

local ENERGY_SERVICE  = "urn:micasaverde-com:serviceId:EnergyMetering1"
local ENERGY_VARIABLE = "Watts"

local m_samplingPeriod  = '60'
local m_pollFastCounter = 0
local POLL_FAST         = '3'

local TYPE_UNDEFINED          =  0
local TYPE_IGNORE             =  1
local TYPE_TEMP_C             =  2
local TYPE_TEMP_F             =  3
local TYPE_HUMIDITY           =  4
local TYPE_LIGHTSWITCH        =  5
local TYPE_LIGHTSWITCH_ENERGY =  6
local TYPE_DEWPOINT_C         =  7
local TYPE_DEWPOINT_F         =  8
local TYPE_HEATINDEX_C        =  9
local TYPE_HEATINDEX_F        =  10
local TYPE_HUMINDEX           =  11
local TYPE_LIGHTSENSOR        =  12
local TYPE_LIGHTSENSOR_ENERGY =  13
local TYPE_PRESSURESENSOR     =  14
local TYPE_COUNTER            =  15
local TYPE_DOORSENSOR         =  16


local TypeTable = {}

TypeTable[TYPE_UNDEFINED] = {}
TypeTable[TYPE_UNDEFINED].Name = "Undefined"

TypeTable[TYPE_IGNORE] = {}
TypeTable[TYPE_IGNORE].Name = "Ignore"

TypeTable[TYPE_COUNTER] = {}
TypeTable[TYPE_COUNTER].Name               = "Counter"
TypeTable[TYPE_COUNTER].Average            = 1
TypeTable[TYPE_COUNTER].Device             = COUNTER.DEVICE
TypeTable[TYPE_COUNTER].Service            = COUNTER.SERVICE
TypeTable[TYPE_COUNTER].DeviceFile         = COUNTER.DEVICE_FILE
TypeTable[TYPE_COUNTER].ServiceFile        = COUNTER.SERVICE_FILE
TypeTable[TYPE_COUNTER].Variable           = COUNTER.VARIABLE
TypeTable[TYPE_COUNTER].Parameters         = PLUGIN_SID..",CountMultiplier=1\n"

TypeTable[TYPE_PRESSURESENSOR] = {}
TypeTable[TYPE_PRESSURESENSOR].Name        = "Pressure"
TypeTable[TYPE_PRESSURESENSOR].Average     = 10
TypeTable[TYPE_PRESSURESENSOR].Device      = PRESSURESENSOR.DEVICE
TypeTable[TYPE_PRESSURESENSOR].Service     = PRESSURESENSOR.SERVICE
TypeTable[TYPE_PRESSURESENSOR].DeviceFile  = PRESSURESENSOR.DEVICE_FILE
TypeTable[TYPE_PRESSURESENSOR].ServiceFile = PRESSURESENSOR.SERVICE_FILE
TypeTable[TYPE_PRESSURESENSOR].Variable    = PRESSURESENSOR.VARIABLE
TypeTable[TYPE_PRESSURESENSOR].Parameters  = ""

TypeTable[TYPE_TEMP_C] = {}
TypeTable[TYPE_TEMP_C].Name                = "Temperature (degC)"
TypeTable[TYPE_TEMP_C].Average             = 3
TypeTable[TYPE_TEMP_C].Device              = TEMPERATURE.DEVICE
TypeTable[TYPE_TEMP_C].Service             = TEMPERATURE.SERVICE
TypeTable[TYPE_TEMP_C].DeviceFile          = TEMPERATURE.DEVICE_FILE
TypeTable[TYPE_TEMP_C].ServiceFile         = TEMPERATURE.SERVICE_FILE
TypeTable[TYPE_TEMP_C].Variable            = TEMPERATURE.VARIABLE
TypeTable[TYPE_TEMP_C].Parameters          = PLUGIN_SID..",Units=C\n"

TypeTable[TYPE_TEMP_F] = {}
TypeTable[TYPE_TEMP_F].Name                = "Temperature (degF)"
TypeTable[TYPE_TEMP_F].Average             = 3
TypeTable[TYPE_TEMP_F].Device              = TEMPERATURE.DEVICE
TypeTable[TYPE_TEMP_F].Service             = TEMPERATURE.SERVICE
TypeTable[TYPE_TEMP_F].DeviceFile          = TEMPERATURE.DEVICE_FILE
TypeTable[TYPE_TEMP_F].ServiceFile         = TEMPERATURE.SERVICE_FILE
TypeTable[TYPE_TEMP_F].Variable            = TEMPERATURE.VARIABLE
TypeTable[TYPE_TEMP_F].Parameters          = PLUGIN_SID..",Units=F\n"

TypeTable[TYPE_HUMIDITY] = {}
TypeTable[TYPE_HUMIDITY].Name              = "Humidity"
TypeTable[TYPE_HUMIDITY].Average           = 10
TypeTable[TYPE_HUMIDITY].Device            = HUMIDITY.DEVICE
TypeTable[TYPE_HUMIDITY].Service           = HUMIDITY.SERVICE
TypeTable[TYPE_HUMIDITY].DeviceFile        = HUMIDITY.DEVICE_FILE
TypeTable[TYPE_HUMIDITY].ServiceFile       = HUMIDITY.SERVICE_FILE
TypeTable[TYPE_HUMIDITY].Variable          = HUMIDITY.VARIABLE
TypeTable[TYPE_HUMIDITY].Parameters        = ""

TypeTable[TYPE_LIGHTSWITCH] = {}
TypeTable[TYPE_LIGHTSWITCH].Name           = "Light Switch"
TypeTable[TYPE_LIGHTSWITCH].Average        = 1
TypeTable[TYPE_LIGHTSWITCH].Device         = BINARYLIGHT.DEVICE
TypeTable[TYPE_LIGHTSWITCH].Service        = BINARYLIGHT.SERVICE
TypeTable[TYPE_LIGHTSWITCH].DeviceFile     = BINARYLIGHT.DEVICE_FILE
TypeTable[TYPE_LIGHTSWITCH].ServiceFile    = BINARYLIGHT.SERVICE_FILE
TypeTable[TYPE_LIGHTSWITCH].Variable       = BINARYLIGHT.VARIABLE
TypeTable[TYPE_LIGHTSWITCH].Parameters     = ""

TypeTable[TYPE_LIGHTSWITCH_ENERGY] = {}
TypeTable[TYPE_LIGHTSWITCH_ENERGY].Name        = "Light Switch + Energy";
TypeTable[TYPE_LIGHTSWITCH_ENERGY].Average     = 1
TypeTable[TYPE_LIGHTSWITCH_ENERGY].Device      = BINARYLIGHT.DEVICE
TypeTable[TYPE_LIGHTSWITCH_ENERGY].Service     = BINARYLIGHT.SERVICE
TypeTable[TYPE_LIGHTSWITCH_ENERGY].DeviceFile  = BINARYLIGHT.DEVICE_FILE
TypeTable[TYPE_LIGHTSWITCH_ENERGY].ServiceFile = BINARYLIGHT.SERVICE_FILE
TypeTable[TYPE_LIGHTSWITCH_ENERGY].Variable    = BINARYLIGHT.VARIABLE
TypeTable[TYPE_LIGHTSWITCH_ENERGY].Parameters  = PLUGIN_SID..",DeviceWatts=0\n"

TypeTable[TYPE_DEWPOINT_C] = {}
TypeTable[TYPE_DEWPOINT_C].Name           = "Dew Point (degC)";
TypeTable[TYPE_DEWPOINT_C].Average        = 10
TypeTable[TYPE_DEWPOINT_C].Device         = TEMPERATURE.DEVICE
TypeTable[TYPE_DEWPOINT_C].Service        = TEMPERATURE.SERVICE
TypeTable[TYPE_DEWPOINT_C].DeviceFile     = TEMPERATURE.DEVICE_FILE
TypeTable[TYPE_DEWPOINT_C].ServiceFile    = TEMPERATURE.SERVICE_FILE
TypeTable[TYPE_DEWPOINT_C].Variable       = TEMPERATURE.VARIABLE
TypeTable[TYPE_DEWPOINT_C].Parameters     = PLUGIN_SID..",Units=C\n"

TypeTable[TYPE_DEWPOINT_F] = {}
TypeTable[TYPE_DEWPOINT_F].Name           = "Dew Point (degF)";
TypeTable[TYPE_DEWPOINT_F].Average        = 10
TypeTable[TYPE_DEWPOINT_F].Device         = TEMPERATURE.DEVICE
TypeTable[TYPE_DEWPOINT_F].Service        = TEMPERATURE.SERVICE
TypeTable[TYPE_DEWPOINT_F].DeviceFile     = TEMPERATURE.DEVICE_FILE
TypeTable[TYPE_DEWPOINT_F].ServiceFile    = TEMPERATURE.SERVICE_FILE
TypeTable[TYPE_DEWPOINT_F].Variable       = TEMPERATURE.VARIABLE
TypeTable[TYPE_DEWPOINT_F].Parameters     = PLUGIN_SID..",Units=F\n"

TypeTable[TYPE_HEATINDEX_C] = {}
TypeTable[TYPE_HEATINDEX_C].Name          = "Heat Index (degC)";
TypeTable[TYPE_HEATINDEX_C].Average       = 10
TypeTable[TYPE_HEATINDEX_C].Device        = TEMPERATURE.DEVICE
TypeTable[TYPE_HEATINDEX_C].Service       = TEMPERATURE.SERVICE
TypeTable[TYPE_HEATINDEX_C].DeviceFile    = TEMPERATURE.DEVICE_FILE
TypeTable[TYPE_HEATINDEX_C].ServiceFile   = TEMPERATURE.SERVICE_FILE
TypeTable[TYPE_HEATINDEX_C].Variable      = TEMPERATURE.VARIABLE
TypeTable[TYPE_HEATINDEX_C].Parameters    = PLUGIN_SID..",Units=C\n"

TypeTable[TYPE_HEATINDEX_F] = {}
TypeTable[TYPE_HEATINDEX_F].Name          = "Heat Index (degF)";
TypeTable[TYPE_HEATINDEX_F].Average       = 10
TypeTable[TYPE_HEATINDEX_F].Device        = TEMPERATURE.DEVICE
TypeTable[TYPE_HEATINDEX_F].Service       = TEMPERATURE.SERVICE
TypeTable[TYPE_HEATINDEX_F].DeviceFile    = TEMPERATURE.DEVICE_FILE
TypeTable[TYPE_HEATINDEX_F].ServiceFile   = TEMPERATURE.SERVICE_FILE
TypeTable[TYPE_HEATINDEX_F].Variable      = TEMPERATURE.VARIABLE
TypeTable[TYPE_HEATINDEX_F].Parameters    = PLUGIN_SID..",Units=F\n"

TypeTable[TYPE_HUMINDEX] = {}
TypeTable[TYPE_HUMINDEX].Name             = "Humidity Index";
TypeTable[TYPE_HUMINDEX].Average          = 10
TypeTable[TYPE_HUMINDEX].Device           = HUMIDITY.DEVICE
TypeTable[TYPE_HUMINDEX].Service          = HUMIDITY.SERVICE
TypeTable[TYPE_HUMINDEX].DeviceFile       = HUMIDITY.DEVICE_FILE
TypeTable[TYPE_HUMINDEX].ServiceFile      = HUMIDITY.SERVICE_FILE
TypeTable[TYPE_HUMINDEX].Variable         = HUMIDITY.VARIABLE
TypeTable[TYPE_HUMINDEX].Parameters       = "";

TypeTable[TYPE_LIGHTSENSOR] = {}
TypeTable[TYPE_LIGHTSENSOR].Name          = "Light Sensor";
TypeTable[TYPE_LIGHTSENSOR].Average       = 1
TypeTable[TYPE_LIGHTSENSOR].Device        = LIGHTSENSOR.DEVICE
TypeTable[TYPE_LIGHTSENSOR].Service       = LIGHTSENSOR.SERVICE
TypeTable[TYPE_LIGHTSENSOR].DeviceFile    = LIGHTSENSOR.DEVICE_FILE
TypeTable[TYPE_LIGHTSENSOR].ServiceFile   = LIGHTSENSOR.SERVICE_FILE
TypeTable[TYPE_LIGHTSENSOR].Variable      = LIGHTSENSOR.VARIABLE
TypeTable[TYPE_LIGHTSENSOR].Parameters    = ""

TypeTable[TYPE_LIGHTSENSOR_ENERGY] = {}
TypeTable[TYPE_LIGHTSENSOR_ENERGY].Name        = "Light Sensor + Energy";
TypeTable[TYPE_LIGHTSENSOR_ENERGY].Average     = 1
TypeTable[TYPE_LIGHTSENSOR_ENERGY].Device      = LIGHTSENSOR.DEVICE
TypeTable[TYPE_LIGHTSENSOR_ENERGY].Service     = LIGHTSENSOR.SERVICE
TypeTable[TYPE_LIGHTSENSOR_ENERGY].DeviceFile  = LIGHTSENSOR.DEVICE_FILE
TypeTable[TYPE_LIGHTSENSOR_ENERGY].ServiceFile = LIGHTSENSOR.SERVICE_FILE
TypeTable[TYPE_LIGHTSENSOR_ENERGY].Variable    = LIGHTSENSOR.VARIABLE
TypeTable[TYPE_LIGHTSENSOR_ENERGY].Parameters  = PLUGIN_SID..",DeviceWatts=0\n"

TypeTable[TYPE_DOORSENSOR] = {}
TypeTable[TYPE_DOORSENSOR].Name          = "Door Sensor";
TypeTable[TYPE_DOORSENSOR].Average       = 1
TypeTable[TYPE_DOORSENSOR].Device        = DOORSENSOR.DEVICE
TypeTable[TYPE_DOORSENSOR].Service       = DOORSENSOR.SERVICE
TypeTable[TYPE_DOORSENSOR].DeviceFile    = DOORSENSOR.DEVICE_FILE
TypeTable[TYPE_DOORSENSOR].ServiceFile   = DOORSENSOR.SERVICE_FILE
TypeTable[TYPE_DOORSENSOR].Variable      = DOORSENSOR.VARIABLE
TypeTable[TYPE_DOORSENSOR].Parameters    = ""


local DEVICE_DS18B20_TEMP       =  0

local DEVICE_EDS0065_TEMP       =  1
local DEVICE_EDS0065_HUMIDITY   =  2
local DEVICE_EDS0065_DEWPOINT   =  3
local DEVICE_EDS0065_HUMINDEX   =  4
local DEVICE_EDS0065_HEATINDEX  =  5
local DEVICE_EDS0065_COUNTER1   =  6
local DEVICE_EDS0065_COUNTER2   =  7
local DEVICE_EDS0065_LED        =  8
local DEVICE_EDS0065_RELAY      =  9

local DEVICE_EDS0068_TEMP       =  10
local DEVICE_EDS0068_HUMIDITY   =  11
local DEVICE_EDS0068_DEWPOINT   =  12
local DEVICE_EDS0068_HUMINDEX   =  13
local DEVICE_EDS0068_HEATINDEX  =  14
local DEVICE_EDS0068_PRESSUREMB =  15
local DEVICE_EDS0068_PRESSUREHG =  16
local DEVICE_EDS0068_LIGHT      =  17
local DEVICE_EDS0068_COUNTER1   =  18
local DEVICE_EDS0068_COUNTER2   =  19
local DEVICE_EDS0068_LED        =  20
local DEVICE_EDS0068_RELAY      =  21

local DEVICE_DS2406_INPUTA      =  22
local DEVICE_DS2406_INPUTB      =  23

local DEVICE_DS2423_COUNTERA    =  24
local DEVICE_DS2423_COUNTERB    =  25

local DEVICE_EDS0067_TEMP       =  26
local DEVICE_EDS0067_LIGHT      =  27
local DEVICE_EDS0067_COUNTER1   =  28
local DEVICE_EDS0067_COUNTER2   =  29
local DEVICE_EDS0067_LED        =  30
local DEVICE_EDS0067_RELAY      =  31

local DEVICE_DS18S20_TEMP       =  32


local DeviceTable = {}

DeviceTable[DEVICE_DS2423_COUNTERA] = {}
DeviceTable[DEVICE_DS2423_COUNTERA].Device    = "DS2423"
DeviceTable[DEVICE_DS2423_COUNTERA].Name      = "Counter A"
DeviceTable[DEVICE_DS2423_COUNTERA].Parameter = "Counter_A"
DeviceTable[DEVICE_DS2423_COUNTERA].Command   = ""
DeviceTable[DEVICE_DS2423_COUNTERA].Services  = {TYPE_COUNTER, TYPE_IGNORE}

DeviceTable[DEVICE_DS2423_COUNTERB] = {}
DeviceTable[DEVICE_DS2423_COUNTERB].Device    = "DS2423"
DeviceTable[DEVICE_DS2423_COUNTERB].Name      = "Counter B"
DeviceTable[DEVICE_DS2423_COUNTERB].Parameter = "Counter_B"
DeviceTable[DEVICE_DS2423_COUNTERB].Command   = ""
DeviceTable[DEVICE_DS2423_COUNTERB].Services  = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_DS2406_INPUTA] = {}
DeviceTable[DEVICE_DS2406_INPUTA].Device    = "DS2406"
DeviceTable[DEVICE_DS2406_INPUTA].Name      = "Input A"
DeviceTable[DEVICE_DS2406_INPUTA].Parameter = "InputLevel_A"
DeviceTable[DEVICE_DS2406_INPUTA].Command   = ""
DeviceTable[DEVICE_DS2406_INPUTA].Services  = {TYPE_LIGHTSENSOR, TYPE_LIGHTSENSOR_ENERGY, TYPE_DOORSENSOR, TYPE_IGNORE}

DeviceTable[DEVICE_DS2406_INPUTB] = {}
DeviceTable[DEVICE_DS2406_INPUTB].Device    = "DS2406"
DeviceTable[DEVICE_DS2406_INPUTB].Name      = "Input B"
DeviceTable[DEVICE_DS2406_INPUTB].Parameter = "InputLevel_B"
DeviceTable[DEVICE_DS2406_INPUTB].Command   = ""
DeviceTable[DEVICE_DS2406_INPUTB].Services  = {TYPE_IGNORE, TYPE_LIGHTSENSOR, TYPE_LIGHTSENSOR_ENERGY, TYPE_DOORSENSOR}

DeviceTable[DEVICE_DS18B20_TEMP] = {}
DeviceTable[DEVICE_DS18B20_TEMP].Device    = "DS18S20"
DeviceTable[DEVICE_DS18B20_TEMP].Name      = "Temperature"
DeviceTable[DEVICE_DS18B20_TEMP].Parameter = "Temperature"
DeviceTable[DEVICE_DS18B20_TEMP].Command   = ""
DeviceTable[DEVICE_DS18B20_TEMP].Services  = {TYPE_TEMP_C, TYPE_TEMP_F, TYPE_IGNORE}

DeviceTable[DEVICE_DS18S20_TEMP] = {}
DeviceTable[DEVICE_DS18S20_TEMP].Device    = "DS18B20"
DeviceTable[DEVICE_DS18S20_TEMP].Name      = "Temperature"
DeviceTable[DEVICE_DS18S20_TEMP].Parameter = "Temperature"
DeviceTable[DEVICE_DS18S20_TEMP].Command   = ""
DeviceTable[DEVICE_DS18S20_TEMP].Services  = {TYPE_TEMP_C, TYPE_TEMP_F, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0065_TEMP] = {}
DeviceTable[DEVICE_EDS0065_TEMP].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_TEMP].Name      = "Temperature"
DeviceTable[DEVICE_EDS0065_TEMP].Parameter = "Temperature"
DeviceTable[DEVICE_EDS0065_TEMP].Command   = ""
DeviceTable[DEVICE_EDS0065_TEMP].Services  = {TYPE_TEMP_C, TYPE_TEMP_F, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0065_HUMIDITY] = {}
DeviceTable[DEVICE_EDS0065_HUMIDITY].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_HUMIDITY].Name      = "Humidity"
DeviceTable[DEVICE_EDS0065_HUMIDITY].Parameter = "Humidity"
DeviceTable[DEVICE_EDS0065_HUMIDITY].Command   = ""
DeviceTable[DEVICE_EDS0065_HUMIDITY].Services  = {TYPE_HUMIDITY, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0065_DEWPOINT] = {}
DeviceTable[DEVICE_EDS0065_DEWPOINT].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_DEWPOINT].Name      = "Dew Point"
DeviceTable[DEVICE_EDS0065_DEWPOINT].Parameter = "Dewpoint"
DeviceTable[DEVICE_EDS0065_DEWPOINT].Command   = ""
DeviceTable[DEVICE_EDS0065_DEWPOINT].Services  = {TYPE_IGNORE, TYPE_DEWPOINT_C, TYPE_DEWPOINT_F}

DeviceTable[DEVICE_EDS0065_HUMINDEX] = {}
DeviceTable[DEVICE_EDS0065_HUMINDEX].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_HUMINDEX].Name      = "Humidity Index"
DeviceTable[DEVICE_EDS0065_HUMINDEX].Parameter = "Humindex"
DeviceTable[DEVICE_EDS0065_HUMINDEX].Command   = ""
DeviceTable[DEVICE_EDS0065_HUMINDEX].Services  = {TYPE_IGNORE, TYPE_HUMINDEX}

DeviceTable[DEVICE_EDS0065_HEATINDEX] = {}
DeviceTable[DEVICE_EDS0065_HEATINDEX].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_HEATINDEX].Name      = "Heat Index"
DeviceTable[DEVICE_EDS0065_HEATINDEX].Parameter = "HeatIndex"
DeviceTable[DEVICE_EDS0065_HEATINDEX].Command   = ""
DeviceTable[DEVICE_EDS0065_HEATINDEX].Services  = {TYPE_IGNORE, TYPE_HEATINDEX_C, TYPE_HEATINDEX_F}

DeviceTable[DEVICE_EDS0065_COUNTER1] = {}
DeviceTable[DEVICE_EDS0065_COUNTER1].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_COUNTER1].Name      = "Counter 1"
DeviceTable[DEVICE_EDS0065_COUNTER1].Parameter = "Counter1"
DeviceTable[DEVICE_EDS0065_COUNTER1].Command   = ""
DeviceTable[DEVICE_EDS0065_COUNTER1].Services  = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_EDS0065_COUNTER2] = {}
DeviceTable[DEVICE_EDS0065_COUNTER2].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_COUNTER2].Name      = "Counter 2"
DeviceTable[DEVICE_EDS0065_COUNTER2].Parameter = "Counter2"
DeviceTable[DEVICE_EDS0065_COUNTER2].Command   = ""
DeviceTable[DEVICE_EDS0065_COUNTER2].Services  = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_EDS0065_LED] = {}
DeviceTable[DEVICE_EDS0065_LED].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_LED].Name      = "LED"
DeviceTable[DEVICE_EDS0065_LED].Parameter = "LEDState"
DeviceTable[DEVICE_EDS0065_LED].Command   = "LEDState"
DeviceTable[DEVICE_EDS0065_LED].Services  = {TYPE_IGNORE, TYPE_LIGHTSWITCH}

DeviceTable[DEVICE_EDS0065_RELAY] = {}
DeviceTable[DEVICE_EDS0065_RELAY].Device    = "EDS0065"
DeviceTable[DEVICE_EDS0065_RELAY].Name      = "Relay"
DeviceTable[DEVICE_EDS0065_RELAY].Parameter = "RelayState"
DeviceTable[DEVICE_EDS0065_RELAY].Command   = "RelayState"
DeviceTable[DEVICE_EDS0065_RELAY].Services  = {TYPE_IGNORE, TYPE_LIGHTSWITCH, TYPE_LIGHTSWITCH_ENERGY}

DeviceTable[DEVICE_EDS0068_TEMP] = {}
DeviceTable[DEVICE_EDS0068_TEMP].Device     = "EDS0068"
DeviceTable[DEVICE_EDS0068_TEMP].Name       = "Temperature"
DeviceTable[DEVICE_EDS0068_TEMP].Parameter  = "Temperature"
DeviceTable[DEVICE_EDS0068_TEMP].Command    = ""
DeviceTable[DEVICE_EDS0068_TEMP].Services   = {TYPE_TEMP_C, TYPE_TEMP_F, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0068_HUMIDITY] = {}
DeviceTable[DEVICE_EDS0068_HUMIDITY].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_HUMIDITY].Name      = "Humidity"
DeviceTable[DEVICE_EDS0068_HUMIDITY].Parameter = "Humidity"
DeviceTable[DEVICE_EDS0068_HUMIDITY].Command   = ""
DeviceTable[DEVICE_EDS0068_HUMIDITY].Services  = {TYPE_HUMIDITY, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0068_DEWPOINT] = {}
DeviceTable[DEVICE_EDS0068_DEWPOINT].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_DEWPOINT].Name      = "Dew Point"
DeviceTable[DEVICE_EDS0068_DEWPOINT].Parameter = "Dewpoint"
DeviceTable[DEVICE_EDS0068_DEWPOINT].Command   = ""
DeviceTable[DEVICE_EDS0068_DEWPOINT].Services  = {TYPE_IGNORE, TYPE_DEWPOINT_C, TYPE_DEWPOINT_F}

DeviceTable[DEVICE_EDS0068_HUMINDEX] = {}
DeviceTable[DEVICE_EDS0068_HUMINDEX].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_HUMINDEX].Name      = "Humidity Index"
DeviceTable[DEVICE_EDS0068_HUMINDEX].Parameter = "Humindex"
DeviceTable[DEVICE_EDS0068_HUMINDEX].Command   = ""
DeviceTable[DEVICE_EDS0068_HUMINDEX].Services  = {TYPE_IGNORE, TYPE_HUMINDEX}

DeviceTable[DEVICE_EDS0068_HEATINDEX] = {}
DeviceTable[DEVICE_EDS0068_HEATINDEX].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_HEATINDEX].Name      = "Heat Index"
DeviceTable[DEVICE_EDS0068_HEATINDEX].Parameter = "HeatIndex"
DeviceTable[DEVICE_EDS0068_HEATINDEX].Command   = ""
DeviceTable[DEVICE_EDS0068_HEATINDEX].Services  = {TYPE_IGNORE, TYPE_HEATINDEX_C, TYPE_HEATINDEX_F}

DeviceTable[DEVICE_EDS0068_PRESSUREMB] = {}
DeviceTable[DEVICE_EDS0068_PRESSUREMB].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_PRESSUREMB].Name      = "Pressure (Mb)"
DeviceTable[DEVICE_EDS0068_PRESSUREMB].Parameter = "BarometricPressureMb"
DeviceTable[DEVICE_EDS0068_PRESSUREMB].Command   = ""
DeviceTable[DEVICE_EDS0068_PRESSUREMB].Services  = {TYPE_PRESSURESENSOR, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0068_PRESSUREHG] = {}
DeviceTable[DEVICE_EDS0068_PRESSUREHG].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_PRESSUREHG].Name      = "Pressure (Hg)"
DeviceTable[DEVICE_EDS0068_PRESSUREHG].Parameter = "BarometricPressureHg"
DeviceTable[DEVICE_EDS0068_PRESSUREHG].Command   = ""
DeviceTable[DEVICE_EDS0068_PRESSUREHG].Services  = {TYPE_IGNORE, TYPE_PRESSURESENSOR}

DeviceTable[DEVICE_EDS0068_LIGHT] = {}
DeviceTable[DEVICE_EDS0068_LIGHT].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_LIGHT].Name      = "Light"
DeviceTable[DEVICE_EDS0068_LIGHT].Parameter = "Light"
DeviceTable[DEVICE_EDS0068_LIGHT].Command   = ""
DeviceTable[DEVICE_EDS0068_LIGHT].Services  = {TYPE_IGNORE, TYPE_LIGHTSENSOR, TYPE_LIGHTSENSOR_ENERGY}

DeviceTable[DEVICE_EDS0068_COUNTER1] = {}
DeviceTable[DEVICE_EDS0068_COUNTER1].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_COUNTER1].Name      = "Counter 1"
DeviceTable[DEVICE_EDS0068_COUNTER1].Parameter = "Counter1"
DeviceTable[DEVICE_EDS0068_COUNTER1].Command   = ""
DeviceTable[DEVICE_EDS0068_COUNTER1].Services  = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_EDS0068_COUNTER2] = {}
DeviceTable[DEVICE_EDS0068_COUNTER2].Device    = "EDS0068"
DeviceTable[DEVICE_EDS0068_COUNTER2].Name      = "Counter 2"
DeviceTable[DEVICE_EDS0068_COUNTER2].Parameter = "Counter2"
DeviceTable[DEVICE_EDS0068_COUNTER2].Command   = ""
DeviceTable[DEVICE_EDS0068_COUNTER2].Services  = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_EDS0068_LED] = {}
DeviceTable[DEVICE_EDS0068_LED].Device       = "EDS0068"
DeviceTable[DEVICE_EDS0068_LED].Name         = "LED"
DeviceTable[DEVICE_EDS0068_LED].Parameter    = "LEDState"
DeviceTable[DEVICE_EDS0068_LED].Command      = "LEDState"
DeviceTable[DEVICE_EDS0068_LED].Services     = {TYPE_IGNORE, TYPE_LIGHTSWITCH}

DeviceTable[DEVICE_EDS0068_RELAY] = {}
DeviceTable[DEVICE_EDS0068_RELAY].Device     = "EDS0068"
DeviceTable[DEVICE_EDS0068_RELAY].Name       = "Relay"
DeviceTable[DEVICE_EDS0068_RELAY].Parameter  = "RelayState"
DeviceTable[DEVICE_EDS0068_RELAY].Command    = "RelayState"
DeviceTable[DEVICE_EDS0068_RELAY].Services   = {TYPE_IGNORE, TYPE_LIGHTSWITCH, TYPE_LIGHTSWITCH_ENERGY}

DeviceTable[DEVICE_EDS0067_TEMP] = {}
DeviceTable[DEVICE_EDS0067_TEMP].Device      = "EDS0067"
DeviceTable[DEVICE_EDS0067_TEMP].Name        = "Temperature"
DeviceTable[DEVICE_EDS0067_TEMP].Parameter   = "Temperature"
DeviceTable[DEVICE_EDS0067_TEMP].Command     = ""
DeviceTable[DEVICE_EDS0067_TEMP].Services    = {TYPE_TEMP_C, TYPE_TEMP_F, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0067_LIGHT] = {}
DeviceTable[DEVICE_EDS0067_LIGHT].Device      = "EDS0067"
DeviceTable[DEVICE_EDS0067_LIGHT].Name        = "Light"
DeviceTable[DEVICE_EDS0067_LIGHT].Parameter   = "Light"
DeviceTable[DEVICE_EDS0067_LIGHT].Command     = ""
DeviceTable[DEVICE_EDS0067_LIGHT].Services    = {TYPE_LIGHTSENSOR, TYPE_LIGHTSENSOR_ENERGY, TYPE_IGNORE}

DeviceTable[DEVICE_EDS0067_COUNTER1] = {}
DeviceTable[DEVICE_EDS0067_COUNTER1].Device    = "EDS0067"
DeviceTable[DEVICE_EDS0067_COUNTER1].Name      = "Counter 1"
DeviceTable[DEVICE_EDS0067_COUNTER1].Parameter = "Counter1"
DeviceTable[DEVICE_EDS0067_COUNTER1].Command   = ""
DeviceTable[DEVICE_EDS0067_COUNTER1].Services  = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_EDS0067_COUNTER2] = {}
DeviceTable[DEVICE_EDS0067_COUNTER2].Device     = "EDS0067"
DeviceTable[DEVICE_EDS0067_COUNTER2].Name       = "Counter 2"
DeviceTable[DEVICE_EDS0067_COUNTER2].Parameter  = "Counter2"
DeviceTable[DEVICE_EDS0067_COUNTER2].Command    = ""
DeviceTable[DEVICE_EDS0067_COUNTER2].Services   = {TYPE_IGNORE, TYPE_COUNTER}

DeviceTable[DEVICE_EDS0067_LED] = {}
DeviceTable[DEVICE_EDS0067_LED].Device       = "EDS0067"
DeviceTable[DEVICE_EDS0067_LED].Name         = "LED"
DeviceTable[DEVICE_EDS0067_LED].Parameter    = "LEDState"
DeviceTable[DEVICE_EDS0067_LED].Command      = "LEDState"
DeviceTable[DEVICE_EDS0067_LED].Services     = {TYPE_IGNORE, TYPE_LIGHTSWITCH}

DeviceTable[DEVICE_EDS0067_RELAY] = {}
DeviceTable[DEVICE_EDS0067_RELAY].Device     = "EDS0067"
DeviceTable[DEVICE_EDS0067_RELAY].Name       = "Relay"
DeviceTable[DEVICE_EDS0067_RELAY].Parameter  = "RelayState"
DeviceTable[DEVICE_EDS0067_RELAY].Command    = "RelayState"
DeviceTable[DEVICE_EDS0067_RELAY].Services   = {TYPE_IGNORE, TYPE_LIGHTSWITCH, TYPE_LIGHTSWITCH_ENERGY}


-- don't change this, it won't do anything. Use the debugEnabled flag instead
local DEBUG_MODE = false

local function debug(textParm, logLevel)
    if DEBUG_MODE then
        local text = ''
        local theType = type(textParm)
        if (theType == 'string') then
            text = textParm
        else
            text = 'type = '..theType..', value = '..tostring(textParm)
        end
        luup.log(PLUGIN_NAME..' debug: '..text,50)

    elseif (logLevel) then
        local text = ''
        if (type(textParm) == 'string') then text = textParm end
        luup.log(PLUGIN_NAME..' debug: '..text, logLevel)
    end
end

-- If non existent, create the variable. Update
-- the variable, only if it needs to be updated
local function updateVariable(varK, varV, sid, id)
    if (sid == nil) then sid = PLUGIN_SID      end
    if (id  == nil) then  id = THIS_LUL_DEVICE end

    if (varV == nil) then
        if (varK == nil) then
            luup.log(PLUGIN_NAME..' debug: '..'Error: updateVariable was supplied with nil values', 1)
        else
            luup.log(PLUGIN_NAME..' debug: '..'Error: updateVariable '..tostring(varK)..' was supplied with a nil value', 1)
        end
        return
    end

    local newValue = tostring(varV)
    debug(newValue..' --> '..varK)

    local currentValue = luup.variable_get(sid, varK, id)
    if ((currentValue ~= newValue) or (currentValue == nil)) then
        luup.variable_set(sid, varK, newValue, id)
    end
end

-- If possible, get a JSON parser. If none available, returns nil. Note that typically UI5 may not have a parser available.
local function loadJsonModule()
    local jsonModules = {
        'dkjson',               -- UI7 firmware
        'openLuup.json',        -- https://community.getvera.com/t/pure-lua-json-library-akb-json/185273
        'akb-json',             -- https://community.getvera.com/t/pure-lua-json-library-akb-json/185273
        'json',                 -- OWServer plugin
        'json-dm2',             -- dataMine plugin
        'dropbox_json_parser',  -- dropbox plugin
        'hue_json',             -- hue plugin
        'L_ALTUIjson',          -- AltUI plugin
        'cjson',                -- openLuup?
        'rapidjson'             -- how many json libs are there?
    }

    local ptr  = nil
    local json = nil
    for n = 1, #jsonModules do
        -- require does not load the module, if it's already loaded
        -- Vera has overloaded require to suit their requirements, so it works differently from openLuup
        -- openLuup:
        --    ok:     returns true or false indicating if the module was loaded successfully or not
        --    result: contains the ptr to the module or an error string showing the path(s) searched for the module
        -- Vera:
        --    ok:     returns true or false indicating the require function executed but require may have or may not have loaded the module
        --    result: contains the ptr to the module or an error string showing the path(s) searched for the module
        --    log:    log reports 'luup_require can't find xyz.json'
        local ok, result = pcall(require, jsonModules[n])
        ptr = package.loaded[jsonModules[n]]
        if (ptr) then
            json = ptr
            debug('Using: '..jsonModules[n])
            break
        end
    end
    if (not json) then debug('No JSON library found',50) return json end
    return json
end

local function round(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function celsiusToF(Celsius)
    return (Celsius * 9/5) + 32
end

--[[
    Entry point for all html page requests and all ajax function calls
    Accesed via http://Vera_IP_Address:3480/data_request?id=lr_owCtrl
    Function needs to be global

    URL parmeters ?funct=
        create        returns htlm
        getnew        returns json
        gettypes      returns json
        getdevcap     returns json
]]
function incomingCtrl(lul_request, lul_parameters)
    debug("Executing incomingCtrl")

    local funct = lul_parameters.funct
    -- local service = lul_parameters.service

    if (funct == "create") then
        local devices   = lul_parameters.cnt
        local createDev = {}

        -- receive the data from the UI and create the child devices
        for cnt = 1, devices do
            createDev[cnt] = {}
            createDev[cnt].ROMId   = lul_parameters["Rom"..cnt]
            createDev[cnt].Device  = tonumber(lul_parameters["Dev"..cnt])
            createDev[cnt].Service = tonumber(lul_parameters["Typ"..cnt])
            -- debug("Loop "..cnt)
            -- debug("Dev"..cnt..": " .. lul_parameters["Dev"..cnt])
            -- debug("Typ"..cnt..": " .. lul_parameters["Typ"..cnt])
            -- debug("ROM"..cnt..": " .. lul_parameters["Rom"..cnt])
        end

        createNewDevices(createDev)

        return "OK", 'text/html'

    elseif (funct == "getnew") then
        local DevList = {}
        local Cnt = 0

        for kNew, vNew in pairs(m_newDevices) do
            for kDev, vDev in pairs(DeviceTable) do
                if (vDev.Device == vNew) then
                    DevList[Cnt] = {}
                    DevList[Cnt].ROMId  = kNew
                    DevList[Cnt].Device = kDev
                    Cnt = Cnt + 1
                end
            end
        end

        return m_json.encode(DevList), 'application/json'
    elseif (funct == "gettypes") then
        return m_json.encode(TypeTable), 'application/json'
    elseif (funct == "getdevcap") then
        return m_json.encode(DeviceTable), 'application/json'
    end
end

--[[
   The luup append function works as follows:
   Function:  append
   Parameters:  parent device (string or number),
        child ptr (binary object),
        id (string),
        description (string),
        device_type (string),
        device_filename (string),
        implementation_filename (string),
        parameters (string),
        embedded (boolean)
        [, invisible (boolean)]
]]
local function createNewDevices(createDev)
    local parameters = ""
    local children = luup.chdev.start(THIS_LUL_DEVICE)

    -- add in the existing children so we don't loose any when we sync!
    for _, v in pairs(m_childDevices) do
        parameters = PLUGIN_SID..",ROMId="..v.ROMId.."\n"..PLUGIN_SID..",Param="..v.Param.."\n"

        luup.chdev.append(THIS_LUL_DEVICE, children,
            v.ROMId..":"..v.Param, "",
            v.Device, "", "", "", false)
    end

    for _, v in pairs(createDev) do
        if (v.Service > TYPE_IGNORE) then
            parameters = ""
            parameters = parameters..PLUGIN_SID..",DeviceFile="..TypeTable[v.Service].DeviceFile.."\n"
            parameters = parameters..PLUGIN_SID..",ROMId="     ..v.ROMId.."\n"
            parameters = parameters..PLUGIN_SID..",Param="     ..DeviceTable[v.Device].Parameter.."\n"
            parameters = parameters..PLUGIN_SID..",Average="   ..TypeTable[v.Service].Average.."\n"
            parameters = parameters..PLUGIN_SID..",ServiceId=" ..TypeTable[v.Service].Service.."\n"
            parameters = parameters..PLUGIN_SID..",Variable="  ..TypeTable[v.Service].Variable.."\n"
            parameters = parameters..PLUGIN_SID..",Command="   ..DeviceTable[v.Device].Command.."\n"
            parameters = parameters..TypeTable[v.Service].Parameters
            -- debug(parameters)

            luup.chdev.append(THIS_LUL_DEVICE, children,
                v.ROMId..":"..DeviceTable[v.Device].Parameter, DeviceTable[v.Device].Name.."["..v.ROMId.."]",
                TypeTable[v.Service].Device, TypeTable[v.Service].DeviceFile,
                "", parameters, false)
        end
    end

    luup.chdev.sync(THIS_LUL_DEVICE, children)
end

-- Helper functions, return what the swich is switching to
local function togglePowerState(lul_device, lul_settings)
    local reverse = luup.variable_get("urn:micasaverde-com:serviceId:HaDevice1","ReverseOnOff",lul_device)
    local power = "0"

    local value = luup.variable_get( "urn:upnp-org:serviceId:SwitchPower1", "Status", lul_device )

    -- if the current state is OFF, or reverse logic and ON
    if (value=="0" or (value=="1" and reverse=="1")) then
        power = "1"
    end

    return power
end

-- http://Vera_IP_address/devices.htm?rom=4300000200AD1928&variable=UserByte1&value=75
local function sendCommand(Device, Value)
    -- debug("sendCommand: Device " .. Device .. " to "..Value)
    local lul_cmd = 'http://' .. luup.devices[THIS_LUL_DEVICE].ip .. '/devices.htm?rom=' .. m_childDevices[Device].ROMId .. "&variable=" .. m_childDevices[Device].Command .. "&value=".. Value

    -- debug("sendCommand --> " .. lul_cmd)
    local code, res = luup.inet.wget(lul_cmd, m_OWServerTimeout, "", "")

    m_pollFastCounter = 6
    luup.call_timer('pollOWServer', 1, POLL_FAST, "")
end

-- UNUSED code?
function getPowerState(lul_device, lul_settings)
    local reverse = luup.variable_get("urn:micasaverde-com:serviceId:HaDevice1","ReverseOnOff",lul_device)
    local power = "0"

    -- if the new state is ON, or reverse logic and OFF
    if (lul_settings.newTargetValue=="1" or (lul_settings.newTargetValue=="0" and reverse=="1")) then
        power = "1"
    end

    return power
end

-- Run as a job
function setTarget(lul_device, lul_settings)
    sendCommand(lul_device, togglePowerState(lul_device, lul_settings))

    -- 0 Waiting to start
    -- 2 Error (red in UI)
    -- 3 Job abborted (red in UI)
    -- 4 Job done (green in UI)
    -- 5 Waiting for callback (blue in UI)

    -- return 5-job_WaitingForCallback, x second timeout
    return 4, 0
end

-- Run as a job
function toggleState(lul_device, lul_settings)
    sendCommand(lul_device, togglePowerState(lul_device, lul_settings))

    -- 0 Waiting to start
    -- 2 Error (red in UI)
    -- 3 Job abborted (red in UI)
    -- 4 Job done (green in UI)
    -- 5 Waiting for callback (blue in UI)
    return 4, 0
end

-- Poll the OWServer for data
-- Function needs to be global
function pollOWServer()
    debug("OWserver poll start: device: "..tostring(THIS_LUL_DEVICE))
    local OWServer  = {}
    local OWDevices = {}

    -- poll the OW-SERVER and get 'details.xml'
    local code, res = luup.inet.wget("http://"..luup.devices[THIS_LUL_DEVICE].ip.."/details.xml", m_OWServerTimeout, "", "")

    if (code ~= 0) then
        luup.call_timer('pollOWServer', 1, m_samplingPeriod, "")
        debug("Poll error: EDS URL read failed")
        return
    end

    --debug(res)

    -- process the XML file into a table
    local Count = 0
    local ni,c,label,xarg, empty
    local i, j = 1, 1
    while true do
        ni, j, c, label, xarg, empty = string.find(res, "<(%/?)([%w:_]+)(.-)(%/?)>", i)
        if not ni then
            break
        end
        local text = string.sub(res, i, ni-1)

        if not string.find(text, "^%s*$") then
            if (Count == 0) then
                OWServer[label] = text
            else
                OWDevices[Count][label] = text
            end
        end
        if c == "" then   -- start tag
            if (string.sub(label, 1, 3) == "owd") then
                Count = Count + 1
                OWDevices[Count] = {}
            end
        end
        i = j+1
    end

    -- DevicesConnected is a tag found in the server xml report
    updateVariable('Devices', OWServer.DevicesConnected)

    -- EDS OW-Server-Enet v1 has only one 'one wire' channel, so it has only one associated error count
    -- EDS OW-Server-Enet v2 has three 'one wire' channels, so it has three associated error counts
    if (OWServer.DataErrors) then
        updateVariable("DataErrorsChannel1", OWServer.DataErrors)
        updateVariable("DataErrorsChannel2", '--')
        updateVariable("DataErrorsChannel3", '--')
    else
        updateVariable("DataErrorsChannel1", OWServer.DataErrorsChannel1)
        updateVariable("DataErrorsChannel2", OWServer.DataErrorsChannel2)
        updateVariable("DataErrorsChannel3", OWServer.DataErrorsChannel3)
    end

    -- loop through all the One-Wire devices in the XML-file table
    local found = 0
    for Count = 1, #OWDevices do
        found = 0

        -- search all child devices to find any with the ROMId
        for _, v in pairs(m_childDevices) do
            if (v.ROMId == OWDevices[Count]["ROMId"]) then
                 -- debug("Processing: "..OWDevices[Count]["ROMId"].."::"..v.Param.." == "..OWDevices[Count][v.Param])
                found = 1

                -- process some special parameters here....
                if (v.Service == TEMPERATURE.SERVICE) then
                    -- Celsius to Farhenheit conversion?
                    if (v.Units == "F") then
                        OWDevices[Count][v.Param] = celsiusToF(OWDevices[Count][v.Param])
                    end
                elseif (v.ServiceId == COUNTER.SERVICE) then
                    -- store the raw counter value
                    -- HACK not fully implemented
                    -- HACK note Average (with a capital A) is not initialised anywhere
                    -- updateVariable(v.Variable, Average, v.Service, v.Device)
                end

                -- keep a loop buffer to allow rolling average filter
                v.History[v.Counter] = round(OWDevices[Count][v.Param],1)
                v.Counter = v.Counter + 1
                if (v.Counter > v.Average) then
                    v.Counter = 1
                    v.Record  = 1
                else
                    v.Record  = 0
                end

                -- store the current data
                if (v.Record == 1) then
                    local average = 0

                    for avgCnt=1, v.Average do
                        average = average + v.History[avgCnt]
                    end

                    average = round(average / v.Average, 1)

                    updateVariable(v.Variable, average, v.Service, v.Id)

                    -- power - Update watts
                    if (v.Watts ~= nil) then
                        if (average == 0) then
                            updateVariable(ENERGY_VARIABLE, 0, ENERGY_SERVICE, v.Id)
                        else
                            updateVariable(ENERGY_VARIABLE, v.Watts, ENERGY_SERVICE, v.Id)
                        end
                    end
                end

                -- remember the last data
                v.LastData = OWDevices[Count][v.Param]
            end
        end

        -- did we find a new device?
        if (found == 0) then
            if (m_newDevices[OWDevices[Count]["ROMId"]] == nil) then
                m_newDevices[OWDevices[Count]["ROMId"]] = OWDevices[Count]["Name"]
                debug("New device found "..OWDevices[Count]["ROMId"] .. " " ..OWDevices[Count]["Name"],50)
            end
        end
    end

    if (m_pollFastCounter > 0) then
        m_pollFastCounter = m_pollFastCounter - 1
        luup.call_timer('pollOWServer', 1, POLL_FAST, "")
        debug("Set timer "..POLL_FAST)
    else
        luup.call_timer('pollOWServer', 1, m_samplingPeriod, "")
        debug("Set timer "..m_samplingPeriod)
    end
    debug("OWserver poll end: device: "..tostring(THIS_LUL_DEVICE))
end

-- Run once at Luup engine startup.
function initialise(lul_device)
    THIS_LUL_DEVICE = lul_device
    debug("Initialising One Wire Server: device: "..tostring(THIS_LUL_DEVICE),50)

    debug('Using: '.._VERSION)   -- returns the string: 'Lua x.y'

    -- set up some defaults:
    updateVariable('PluginVersion', PLUGIN_VERSION)

    -- set up some defaults:
    local debugEnabled = luup.variable_get(PLUGIN_SID, 'DebugEnabled', THIS_LUL_DEVICE)
    if ((debugEnabled == nil) or (debugEnabled == '')) then
        debugEnabled = '0'
        updateVariable('DebugEnabled', debugEnabled)
    end
    DEBUG_MODE = (debugEnabled == '1')

    local pluginEnabled = luup.variable_get(PLUGIN_SID, 'PluginEnabled', THIS_LUL_DEVICE)
    if ((pluginEnabled == nil) or (pluginEnabled == '')) then
        pluginEnabled = '1'
        updateVariable('PluginEnabled', pluginEnabled)
    end

    if (pluginEnabled ~= '1') then return true, 'All OK', PLUGIN_NAME end

    m_json = loadJsonModule()
    if (m_json == nil) then
        luup.task("No JSON library found", 2, string.format("%s[%d]", luup.devices[THIS_LUL_DEVICE].description, THIS_LUL_DEVICE), -1)
        return false, 'No JSON library found', PLUGIN_NAME
    end

    -- check for a valid device ip address
    local ipa = luup.devices[THIS_LUL_DEVICE].ip
    local ipAddress = ipa:match('^(%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?)')

    if ((ipAddress == nil) or (ipAddress == '')) then return false, 'Enter a valid IP address', PLUGIN_NAME end

    local linkToDeviceWebPage = "<a href='http://"..ipAddress.."/' target='_blank'>EDS OW server web page</a>"
    updateVariable('LinkToDeviceWebPage', linkToDeviceWebPage)


    -- allow the user to change the sampling period
    m_samplingPeriod = luup.variable_get(PLUGIN_SID, "SamplingPeriod", THIS_LUL_DEVICE)
    if ((m_samplingPeriod == nil) or (m_samplingPeriod == '')) then
        m_samplingPeriod = '20'
        updateVariable("SamplingPeriod", m_samplingPeriod)
    end

    -- build the child list
    for k, v in pairs(luup.devices) do
        if (v.device_num_parent == THIS_LUL_DEVICE) then

            local childDevice    = {}
            childDevice.Id       = k
            childDevice.ROMId    = luup.variable_get(PLUGIN_SID, "ROMId",       k)
            childDevice.Device   = luup.variable_get(PLUGIN_SID, "DeviceId",    k)
            childDevice.Service  = luup.variable_get(PLUGIN_SID, "ServiceId",   k)
            childDevice.Variable = luup.variable_get(PLUGIN_SID, "Variable",    k)
            childDevice.Param    = luup.variable_get(PLUGIN_SID, "Param",       k)
            childDevice.Command  = luup.variable_get(PLUGIN_SID, "Command",     k)
            childDevice.Watts    = luup.variable_get(PLUGIN_SID, "DeviceWatts", k)
            childDevice.Average  = luup.variable_get(PLUGIN_SID, "Average",     k)
            childDevice.Units    = luup.variable_get(PLUGIN_SID, "Units",       k)
            childDevice.History  = {}
            childDevice.Counter  = 1
            childDevice.Record   = 0

            if (childDevice.Average == nil) then childDevice.Average = 5 end

            childDevice.Average = tonumber(childDevice.Average)

            m_childDevices[k] = childDevice
        end
    end

    -- register handlers to serve the JSON data
    luup.register_handler("incomingCtrl", "owCtrl")

    -- Set the timer to go off in 15 seconds after start up, to get an initial update. We'll also do ten
    -- fast polls at that point, so that we can force an average to pretty much be created immediately.
    m_pollFastCounter = 10
    luup.call_timer('pollOWServer', 1, "15", "")

    -- required for UI7. UI5 uses true or false for the passed parameter.
    -- UI7 uses 0 or 1 or 2 for the parameter. This works for both UI5 and UI7
    luup.set_failure(false)

    -- startup is done
    return true, 'All OK', PLUGIN_NAME
end
