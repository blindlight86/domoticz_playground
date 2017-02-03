#!/usr/bin/python3

import urllib.request
import base64
from miflora.miflora_poller import MiFloraPoller, \
    MI_CONDUCTIVITY, MI_MOISTURE, MI_LIGHT, MI_TEMPERATURE, MI_BATTERY

# Settings for the domoticz server
domoticzserver   = "127.0.0.1:8080"
domoticzusername = ""
domoticzpassword = ""

# Sensor IDs
idx_temp  = "74"
idx_lux   = "72"
idx_moist = "73"
idx_cond  = "75"

#
poller = MiFloraPoller("aa:bb:cc:dd:ee:ff") 

############

base64string = base64.encodestring(('%s:%s' % (domoticzusername, domoticzpassword)).encode()).decode().replace('\n', '')

def domoticzrequest (url):
  request = urllib.request.Request(url)
  request.add_header("Authorization", "Basic %s" % base64string)
  response = urllib.request.urlopen(request)
  return response.read()

#print("Getting data from Mi Flora")
#print("FW: {}".format(poller.firmware_version()))
#print("Name: {}".format(poller.name()))
#print("Temperature: {}".format(poller.parameter_value("temperature")))
#print("Moisture: {}".format(poller.parameter_value(MI_MOISTURE)))
#print("Light: {}".format(poller.parameter_value(MI_LIGHT)))
#print("Conductivity: {}".format(poller.parameter_value(MI_CONDUCTIVITY)))
#print("Battery: {}".format(poller.parameter_value(MI_BATTERY)))

val_bat  = "{}".format(poller.parameter_value(MI_BATTERY))

# Update temp
val_temp = "{}".format(poller.parameter_value("temperature"))
domoticzrequest("http://" + domoticzserver + "/json.htm?type=command&param=udevice&idx=" + idx_temp + "&nvalue=0&svalue=" + val_temp + "&battery=" + val_bat)

# Update lux
val_lux = "{}".format(poller.parameter_value(MI_LIGHT))
domoticzrequest("http://" + domoticzserver + "/json.htm?type=command&param=udevice&idx=" + idx_lux + "&svalue=" + val_lux + "&battery=" + val_bat)

# Update moisture
val_moist = "{}".format(poller.parameter_value(MI_MOISTURE))
domoticzrequest("http://" + domoticzserver + "/json.htm?type=command&param=udevice&idx=" + idx_moist + "&nvalue=" + val_moist + "&battery=" + val_bat)

# Update conductivity
val_cond = "{}".format(poller.parameter_value(MI_CONDUCTIVITY))
domoticzrequest("http://" + domoticzserver + "/json.htm?type=command&param=udevice&idx=" + idx_cond + "&svalue=" + val_cond + "&battery=" + val_bat)