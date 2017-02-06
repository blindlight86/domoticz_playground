--[[
每个用户创建4个device，Switch——<用户>的iPhone；Custom——<用户>的iPhone电量；Custom——<用户>的iPhone离家；Text——<用户>的位置
每个用户创建2个变量，integer——<用户>_interval (用于保存时间间隔)；integer——<用户>_set_interval (用于强制设置时间间隔，默认0不设置)
注册高德地图开发者获取API
注册百度地图开发者获取API
填写用户各自icloud账号、密码
设置用户各自家坐标，地图半径
]]

commandArray = {}
json = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")() --json.lua路径
d_interval = 15 --默认刷新间隔
dcharging_interval = 5 --默认充电刷新间隔
dle20_interval = 30 --默认电量20%以下刷新间隔
dle10_interval = 60 --默认电量10%以下刷新间隔
local m = os.date('%M')

amapkey='高德key'
baiduAk='百度key'
users = {
	 Duke = {username = 'abc@icloud.com' ;
			 password = '********' ; 
			 devicename = 'iPhone' ;  --关于手机——名称 (必须完全一致)
			 homelongitude = 120 ; 
			 homelatitude = 30 ; 
			 cityname = "北京市" ; --删除指定字段缩短text长度
			 interval = 15 ; --用户自定刷新间隔
			 charging_interval = 5 ; --用户自定充电刷新间隔
			 le20_interval = 30 ; --用户自定电量20%以下刷新间隔
			 le10_interval = 60}; --用户自定电量10%以下刷新间隔
	 Rita = {username = '123@hotmail.com' ; 
			 password = '********' ; 
			 devicename = 'iPad' ; 
			 homelongitude = 151.1867 ; 
			 homelatitude = 11.66889106; 
			 cityname = "天津市"}
		}
radius = 0.15

--根据idx找到设备名称
function getdevname4idx(deviceIDX)
   for i, v in pairs(otherdevices_idx) do
      if v == deviceIDX then
        return i
      end
   end
   return 0
end

--获取查找我的iPhone信息
function fmipinfo(credentials)
	command = "curl -s -X POST -L -u '" .. credentials.username .. ":" .. credentials.password .. "' -H 'Content-Type: application/json; charset=utf-8' -H 'X-Apple-Find-Api-Ver: 3.0' -H 'X-Apple-Authscheme: UserIdGuest' -H 'X-Apple-Realm-Support: 1.0' -H 'User-agent: FindMyiPhone/500 CFNetwork/758.4.3 Darwin/15.5.0' -H 'X-Client-Name: iPad' -H 'X-Client-UUID: d98c8ae0db3311e687b92890643032df' -H 'Accept-Language: en-us' -H 'Connection: keep-alive' https://fmipmobile.icloud.com/fmipservice/device/" .. credentials.username .."/initClient"
	local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    output = json:decode(result)
	return output
end

--国内经纬度偏移与逆地理查询
function address(longitude, latitude)
	command1 = "curl -s 'http://restapi.amap.com/v3/assistant/coordinate/convert?key=" .. amapkey .. "&coordsys=gps&locations=" .. longitude .. "," .. latitude .. "&output=json'"
	local handle = io.popen(command1)
	local result = handle:read("*a")
	handle:close()
	output1= json:decode(result)
	lonlat=output1.locations
	dh=string.find(lonlat,',')
	lenlonlat=string.len(lonlat)
	lon=string.sub(lonlat,1,(dh-1))
	lat=string.sub(lonlat,(dh+1),lenlonlat)
	command2 = "curl -s 'restapi.amap.com/v3/geocode/regeo?key=" .. amapkey .. "&location=" .. lon .. "," .. lat .. "&output=json'"
	local handle = io.popen(command2)
	local result = handle:read("*a")
	handle:close()
	output2 = json:decode(result)
	addr = output2.regeocode.formatted_address
	if (type(addr)=="table") then
		command3 = "curl -s 'http://api.map.baidu.com/geocoder/v2/?callback=renderReverse&coordtype=wgs84ll&ak=" .. baiduAk .. "&coordsys=gps&location=" .. latitude .. "," .. longitude .. "&output=json'"
		local handle = io.popen(command3)
		local result = handle:read("*a")
		handle:close()
		result = string.gsub(result,"renderReverse&&renderReverse%(","")
		result = string.gsub(result,"%)","")
		output3= json:decode(result)
		addr = output3.result.addressComponent.country ..','.. output3.result.addressComponent.province ..','.. output3.result.addressComponent.city ..','.. output3.result.addressComponent.district ..','.. output3.result.addressComponent.street
	end
	return addr
end

--短网址
function shortenurl(text)
	commandsu = "curl -s 'http://tinyurl.com/api-create.php?url=" .. text .. "'"
	local handle = io.popen(commandsu)
	local result = handle:read("*a")
	handle:close()
	short_url = result
	return result
end
--位置，电池状态，获取时间更新
function updateinfo(user,credentials)
	info=fmipinfo(credentials)
	for key,value in pairs(info.content) do
      if value.name == credentials.devicename then
        lon = value.location.longitude
        lat = value.location.latitude
		bat = value.batteryLevel * 100 / 1
		powerstateval = value.batteryStatus
		timestamp = math.floor(value.location.timeStamp/1000)
		timedelta = os.difftime(os.time(),timestamp)
		print (lon)
		print (lat)
		--电池状态
		powerstatus = '未知'
		if powerstateval == 'NotCharging' then
			powerstatus = '使用中'
		elseif (powerstateval == 'Charging') then
			powerstatus = '充电中'
		elseif (powerstateval == 'Charged') then
			powerstatus = '已充满'
		end
		
		--时间格式调整
		if (timedelta >=3600) then
			fixedtime = '一个小时前'
		elseif (timedelta>=60) then
			minutes = math.floor(timedelta/60)
			seconds = timedelta % 60
			fixedtime = minutes .. '分' .. seconds .. '秒前'
		elseif (timedelta<60) then
			seconds = timedelta %60
			fixedtime = seconds .. '秒前'
		end
		
		distance = math.sqrt(((lon - credentials.homelongitude) * 111.320 * math.cos(math.rad(lat)))^2 + ((lat - credentials.homelatitude) * 110.547)^2)
		distance = math.floor((distance*1000+0.5)/1000)
		position = address(lon,lat)
		position=string.gsub(position,credentials.cityname,"");
		if (string.find(position, "区")~=nil) then
			long_url = 'http://uri.amap.com/marker?position='..lon..','..lat
			short_url=shortenurl(long_url)
			position_text = '<a style="color:black" target="blank" href="http://uri.amap.com/marker?position='..lon..','..lat..'">'..position..'('..fixedtime..')</a><br>电池状态:' .. powerstatus.. '</br>'
		else
			long_url = 'http://api.map.baidu.com/marker?title='..user..'&content=这&output=html&location='..lat..','..lon
			short_url=shortenurl(long_url)
			--position_text = '<a style="color:black" target="blank" href="http://cn.bing.com/ditu/?lvl=17&cp='..lat..'~'..lon..'">'..position..'('..fixedtime..')</a><br>电池状态:' .. powerstatus.. '</br>'
			position_text = '<a style="color:black" target="blank" href="http://api.map.baidu.com/marker?title='..user..'&content=我在这&output=html&location='..lat..','..lon..'">'..position..'('..fixedtime..')</a><br>电池状态:' .. powerstatus.. '</br>'
		end
		table.insert(commandArray,{['UpdateDevice'] = otherdevices_idx[user .. '的位置'] .. '|0|' .. position_text})
		table.insert(commandArray,{['UpdateDevice'] = otherdevices_idx[user .. '的iPhone离家'] .. '|0|' .. distance})
        if distance < radius  then
          if otherdevices[user .. '的iPhone'] == 'Off' then
            commandArray[user .. '的iPhone'] = 'On'
            table.insert(commandArray, {['SendNotification'] = '位置更新#' .. user .. '到家了'})
          end
        else
          if otherdevices[user .. '的iPhone'] == 'On' then
            commandArray[user .. '的iPhone'] = 'Off'
            table.insert(commandArray, {['SendNotification'] = '位置更新#' .. user .. '离家了'})
          end
        end
		if (powerstatus~='未知') then
			table.insert(commandArray,{['UpdateDevice'] = otherdevices_idx[user .. '的iPhone电量'] .. '|0|' .. bat})
		end
		
		if (credentials.interval==nil) then 
			interval = d_interval 
			charging_interval =	dcharging_interval
			le20_interval = dle20_interval
			le10_interval = dle10_interval
		else
			interval = credentials.interval 
			charging_interval =	credentials.charging_interval
			le20_interval = credentials.le20_interval
			le10_interval = credentials.le10_interval
		end
		
		commandArray['Variable:'..user..'_interval']=tostring(interval)
		if (powerstateval == 'Charging' or powerstateval == 'Charged') then
			commandArray['Variable:'..user..'_interval']=tostring(charging_interval)
		else
			if (bat==0) then
				commandArray['Variable:'..user..'_interval']='1'
			elseif (bat<=10) then
				commandArray['Variable:'..user..'_interval']=tostring(le10_interval)
			elseif (bat<=20) then
				commandArray['Variable:'..user..'_interval']=tostring(le20_interval)
			end
		end
		if (uservariables[user..'_set_interval'] ~= 0) then
			commandArray['Variable:'..user..'_interval'] = tostring(uservariables[user..'_set_interval'])
		end
		
		print(position_text)
        print('查找我的iPhone： ' .. user .. '在' .. position .. '于' .. fixedtime .. '，电池状态：' .. bat .. '%,' .. powerstatus)
      end
    end
 end


for user,credentials in pairs(users) do
	while true do
		if (m == 0) then m=60 end
		interval = uservariables[user..'_interval']
		--print (user..'刷新间隔'..interval..'分钟')
		if ( interval > 5) then
			if ((m+1) % interval ==0) then
				info=fmipinfo(credentials)
				print ('刷新查找我的iPhone服务')
			end
		end
		if (m % interval ~=0) then break end
		updateinfo(user,credentials)
		break
	end
end

return commandArray
