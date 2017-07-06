--创建一个text设备存放需要播报的文字，此代码设备名为'出行建议'

commandArray = {}

json = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")()
API_Key='abcdef1234567'
Secret_Key='hijk89012'
mpd_host='10.0.0.101'
mpd_port='6600'

t1 = os.time()
s = otherdevices_lastupdate['小米人体感应-大门']
year = string.sub(s, 1, 4)
month = string.sub(s, 6, 7)
day = string.sub(s, 9, 10)
hour = string.sub(s, 12, 13)
minutes = string.sub(s, 15, 16)
seconds = string.sub(s, 18, 19)
t2 = os.time{year=year, month=month, day=day, hour=hour, min=minutes, sec=seconds}
difference = (os.difftime (t1, t2))

if(devicechanged['大门门磁']=='Open' and difference < 90) then
--if(devicechanged['Xiaomi Wireless Switch']=='Click') then
	command="curl -s 'https://openapi.baidu.com/oauth/2.0/token?grant_type=client_credentials&client_id=" .. API_Key .. "&client_secret=" .. Secret_Key.."'"
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	output= json:decode(result)
	expires_time=output.expires_in
	if(tonumber(expires_time)<=259200) then
		print ("百度语音token将在3天后失效")
	end
	token=output.access_token
	os.execute('wget -O /home/pi/domoticz/tts/tts.mp3 "http://tsn.baidu.com/text2audio?tex='..otherdevices['出行建议']..'&lan=zh&cuid=blindlight&ctp=1&tok='..token..'"')
	os.execute('mpc -h '..mpd_host..' -p '..mpd_port..' clear')
	os.execute('mpc -h '..mpd_host..' -p '..mpd_port..' volume 100')
	os.execute('mpc -h '..mpd_host..' -p '..mpd_port..' add tts/tts.mp3')
	os.execute('mpc -h '..mpd_host..' -p '..mpd_port..' play 1')
end

return commandArray