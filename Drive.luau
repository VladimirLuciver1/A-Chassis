local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local z1 = script.Parent
local car = z1.Car.Value
local parentValues = z1.Values
local _Tune = require(car["A-Chassis Tune"])

local isond = z1.IsOn

local FBrakeForce = _Tune.BrakeForce*_Tune.BrakeBias
local RBrakeForce = _Tune.BrakeForce*(1-_Tune.BrakeBias)
local PBrakeForceF = _Tune.PBrakeForce*_Tune.PBrakeBias
local PBrakeForceR = _Tune.PBrakeForce*(1-_Tune.PBrakeBias)
local EBrakeForce = _Tune.EBrakeForce
local SteerOuter = _Tune.SteerOuter
local SteerInner = _Tune.SteerInner
local RSteerOuter = _Tune.RSteerOuter
local RSteerInner = _Tune.RSteerInner

local _IsOn = _Tune.AutoStart
if _Tune.AutoStart and (_Tune.Engine or _Tune.Electric) then isond.Value=true end

local _GSteerT=0
local _GSteerC=0
local _GThrot=0
local _InThrot=0
local _IThrot=_Tune.IdleThrottle/100
local _GBrake=0
local _InBrake=0
local _IBrake=0

local _ClPressing = false
local _PlayerClutch = false
local _Clutch = 0
local _ClutchKick = 0
local _ClutchModulate = 0
local _RPM = 0
local _HP = 0
local _OutTorque = 0
local _CGear = 0
local _PGear = _CGear
local _ShiftUp = false
local _ShiftDn = false
local _Shifting = false
local _spLimit = 0

local _Boost = 0
local _TCount = 0
local _TPsi = 0
local _TBoost = 0
local _SCount = 0
local _SPsi = 0
local _SBoost = 0
local _NH = 0
local _NT = 0
local _EH = 0
local _ET = 0
local _TH = 0
local _TT = 0
local _SH = 0
local _ST = 0
local _BH = 0
local _BT = 0

local _TMode = _Tune.TransModes[1]

local _MSteer = false
local _SteerL = false
local _SteerR = false
local _PBrake = false
local _TCS = _Tune.TCSEnabled
local _TCSActive = false
local _TCSAmt = 0
local _ABS = _Tune.ABSEnabled
local _ABSActive = false

local FlipWait=tick()
local FlipDB=false

local _InControls = false

car.DriveSeat.ChildRemoved:Connect(function(child) 
	if child.Name=="SeatWeld" and child:IsA("Weld") then 
		for i,v in pairs(car:GetDescendants()) do
			if v:IsA("Sound") and v.Name == "Horn" then v:Stop() end
		end
		z1:Destroy() 
	end 
end)

local _CTRL = _Tune.Controls

local Controls = Instance.new("Folder",z1)
Controls.Name = "Controls"

for i,v in pairs(_CTRL) do
	local a=Instance.new("StringValue",Controls)
	a.Name=i
	a.Value=v.Name
	a.Changed:Connect(function()
		if i=="MouseThrottle" or i=="MouseBrake" then
			if a.Value == "MouseButton1" or a.Value == "MouseButton2" then
				_CTRL[i]=Enum.UserInputType[a.Value]
			else
				_CTRL[i]=Enum.KeyCode[a.Value]
			end
		else
			_CTRL[i]=Enum.KeyCode[a.Value]
		end
	end)
end

local _PPH = _Tune.Peripherals

for i,v in pairs(_PPH) do
	local a = Instance.new("IntValue",Controls)
	a.Name = i
	a.Value = v
	a.Changed:Connect(function() 
		a.Value=math.min(100,math.max(0,a.Value))
		_PPH[i] = a.Value
	end)
end

function DealWithInput(input,IsRobloxFunction)
	if (UserInputService:GetFocusedTextBox() ~= nil) or _InControls then
		_IThrot = _Tune.IdleThrottle/100
		_GSteerT = 0
		_IBrake = 0
		return
	end

	local keyCode = input.KeyCode
	local inputState = input.UserInputState
	local isInputBegin = inputState == Enum.UserInputState.Begin
	local isInputEnd = inputState == Enum.UserInputState.End

	if (keyCode == _CTRL["ContlrShiftDown"] or 
		(_MSteer and keyCode == _CTRL["MouseShiftDown"]) or 
		((not _MSteer) and keyCode == _CTRL["ShiftDown"])) and 
		((_IsOn and ((_TMode == "Auto" and _CGear <= 1) and _Tune.AutoShiftVers == "New") or _TMode == "Semi") or _TMode == "Manual") and 
		isInputBegin then
		_ShiftDn = true
		return
	end

	if (keyCode == _CTRL["ContlrShiftUp"] or 
		(_MSteer and keyCode == _CTRL["MouseShiftUp"]) or 
		((not _MSteer) and keyCode == _CTRL["ShiftUp"])) and 
		((_IsOn and ((_TMode == "Auto" and _CGear < 1) and _Tune.AutoShiftVers == "New") or _TMode == "Semi") or _TMode == "Manual") and 
		isInputBegin then
		_ShiftUp = true
		return
	end

	if (keyCode == _CTRL["ContlrClutch"] or 
		(_MSteer and keyCode == _CTRL["MouseClutch"]) or 
		((not _MSteer) and keyCode == _CTRL["Clutch"])) and 
		_TMode == "Manual" then
		_ClPressing = isInputBegin
		_PlayerClutch = isInputBegin
		return
	end

	if keyCode == _CTRL["ContlrPBrake"] or 
		(_MSteer and keyCode == _CTRL["MousePBrake"]) or 
		((not _MSteer) and keyCode == _CTRL["PBrake"]) then
		if isInputBegin then
			_PBrake = not _PBrake
		elseif isInputEnd and car.DriveSeat.Velocity.Magnitude > 5 then 
			_PBrake = false 
		end
		return
	end

	if (keyCode == _CTRL["ContlrToggleTMode"] or keyCode == _CTRL["ToggleTransMode"]) and isInputBegin then
		local n = 1
		for i, v in pairs(_Tune.TransModes) do
			if v == _TMode then 
				n = i 
				break 
			end
		end
		n = n + 1
		if n > #_Tune.TransModes then n = 1 end
		_TMode = _Tune.TransModes[n]
		return
	end

	if ((not _MSteer) and (keyCode == _CTRL["Throttle"] or keyCode == _CTRL["Throttle2"])) or 
		((((_CTRL["MouseThrottle"] == Enum.UserInputType.MouseButton1 or _CTRL["MouseThrottle"] == Enum.UserInputType.MouseButton2) and 
			input.UserInputType == _CTRL["MouseThrottle"]) or keyCode == _CTRL["MouseThrottle"]) and _MSteer) then
		_IThrot = (isInputBegin and _IsOn) and 1 or (_Tune.IdleThrottle/100)
		return
	end

	if ((not _MSteer) and (keyCode == _CTRL["Brake"] or keyCode == _CTRL["Brake2"])) or 
		((((_CTRL["MouseBrake"] == Enum.UserInputType.MouseButton1 or _CTRL["MouseBrake"] == Enum.UserInputType.MouseButton2) and 
			input.UserInputType == _CTRL["MouseBrake"]) or keyCode == _CTRL["MouseBrake"]) and _MSteer) then
		_IBrake = isInputBegin and 1 or 0
		return
	end

	if (not _MSteer) and (keyCode == _CTRL["SteerLeft"] or keyCode == _CTRL["SteerLeft2"]) then
		if isInputBegin then
			_GSteerT = -1
			_SteerL = true
		else
			_GSteerT = _SteerR and 1 or 0
			_SteerL = false
		end
		return
	end

	if (not _MSteer) and (keyCode == _CTRL["SteerRight"] or keyCode == _CTRL["SteerRight2"]) then
		if isInputBegin then
			_GSteerT = 1
			_SteerR = true
		else
			_GSteerT = _SteerL and -1 or 0
			_SteerR = false
		end
		return
	end

	if keyCode == _CTRL["ToggleMouseDrive"] and isInputEnd then
		_MSteer = not _MSteer
		_IThrot = _Tune.IdleThrottle/100
		_IBrake = 0
		_GSteerT = 0
		return
	end

	if _Tune.TCSEnabled and _IsOn and (keyCode == _CTRL["ToggleTCS"] or keyCode == _CTRL["ContlrToggleTCS"]) and isInputEnd then
		_TCS = not _TCS
		return
	end

	if _Tune.ABSEnabled and _IsOn and (keyCode == _CTRL["ToggleABS"] or keyCode == _CTRL["ContlrToggleABS"]) and isInputEnd then
		_ABS = not _ABS
		return
	end

	if input.UserInputType.Name:find("Gamepad") then
		if keyCode == _CTRL["ContlrSteer"] then
			local posX = input.Position.X
			if posX >= 0 then
				local cDZone = math.min(.99, _Tune.Peripherals.ControlRDZone/100)
				_GSteerT = math.abs(posX) > cDZone and ((posX-cDZone)/(1-cDZone)) or 0
			else
				local cDZone = math.min(.99, _Tune.Peripherals.ControlLDZone/100)
				_GSteerT = math.abs(posX) > cDZone and ((posX+cDZone)/(1-cDZone)) or 0
			end
		elseif keyCode == _CTRL["ContlrThrottle"] then
			_IThrot = _IsOn and math.max(_Tune.IdleThrottle/100, input.Position.Z) or (_Tune.IdleThrottle/100)
		elseif keyCode == _CTRL["ContlrBrake"] then
			_IBrake = input.Position.Z
		end
	end
end

local Drive={}

if _Tune.Config == "FWD" or _Tune.Config == "AWD" then for i,v in pairs(car.Wheels:GetChildren()) do if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then table.insert(Drive,v) end end end
if _Tune.Config == "RWD" or _Tune.Config == "AWD" then for i,v in pairs(car.Wheels:GetChildren()) do if v.Name=="RL" or v.Name=="RR" or v.Name=="R" then table.insert(Drive,v) end end end
local wDia = 0 for i,v in pairs(Drive) do if v.Size.x>wDia then wDia = v.Size.x end end
for i,v in pairs(car.Wheels:GetChildren()) do if (math.abs(v["#BV"].MotorMaxTorque-PBrakeForceF)<1) or (math.abs(v["#BV"].MotorMaxTorque-PBrakeForceR)<1) then _PBrake=true end end

function Inputs(dt)
	local deltaTime = (60/(1/dt))
	if _InThrot <= _IThrot then
		_InThrot = math.min(_IThrot, _InThrot + (_Tune.ThrotAccel * deltaTime))
	else
		_InThrot = math.max(_IThrot, _InThrot - (_Tune.ThrotDecel * deltaTime))
	end
	if _InBrake <= _IBrake then
		_InBrake = math.min(_IBrake, _InBrake + (_Tune.BrakeAccel * deltaTime))
	else
		_InBrake = math.max(_IBrake, _InBrake - (_Tune.BrakeDecel * deltaTime))
	end
end

if _Tune.SteeringType == 'New' then
	SteerOuter = (_Tune.LockToLock*180)/_Tune.SteerRatio
	SteerInner = math.min(SteerOuter-(SteerOuter*(1-_Tune.Ackerman)),SteerOuter*1.2)
end

local mathRad, mathMin, mathMax = math.rad, math.min, math.max

function Steering(dt)
	local deltaTime = (60/(1/dt))
	if _MSteer then
		local msWidth = mathMax(1,mouse.ViewSizeX*_Tune.Peripherals.MSteerWidth/200)
		local mdZone = _Tune.Peripherals.MSteerDZone/100
		local mST = ((mouse.X-mouse.ViewSizeX/2)/msWidth)
		if math.abs(mST)<=mdZone then
			_GSteerT = 0
		else
			local absVal = math.abs(mST)
			local sign = mST / absVal
			_GSteerT = (mathMax(mathMin((absVal-mdZone),(1-mdZone)),0)/(1-mdZone))^_Tune.MSteerExp * sign
		end
	end
	if _GSteerC < _GSteerT then
		if _GSteerC<0 then
			_GSteerC = mathMin(_GSteerT,_GSteerC+(_Tune.ReturnSpeed*deltaTime))
		else
			_GSteerC = mathMin(_GSteerT,_GSteerC+(_Tune.SteerSpeed*deltaTime))
		end
	else
		if _GSteerC>0 then
			_GSteerC = mathMax(_GSteerT,_GSteerC-(_Tune.ReturnSpeed*deltaTime))
		else
			_GSteerC = mathMax(_GSteerT,_GSteerC-(_Tune.SteerSpeed*deltaTime))
		end
	end
	if not car:FindFirstChild("DriveSeat") then return end
	local velMag = car.DriveSeat.Velocity.Magnitude
	local sDecay = (1-mathMin(velMag/_Tune.SteerDecay,1-(_Tune.MinSteer/100)))
	local rsDecay = (1-mathMin(velMag/_Tune.RSteerDecay,1-(_Tune.MinSteer/100)))
	local rsMul = mathMax(0,1-(velMag/_Tune.RSteerDecay))
	local FL, FR, RL, RR = car.Wheels.FL, car.Wheels.FR, car.Wheels.RL, car.Wheels.RR
	local F, R
	local hasF = car.Wheels:FindFirstChild("F") ~= nil
	local hasR = car.Wheels:FindFirstChild("R") ~= nil
	if hasF then F = car.Wheels.F end
	if hasR then R = car.Wheels.R end
	for i,v in pairs(car.Wheels:GetChildren()) do
		local name = v.Name
		local steerAngle = 0
		if name=="F" then
			v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*_Tune.SteerInner*sDecay),0)
		elseif name=="FL" then
			if _GSteerC >= 0 then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*SteerOuter*sDecay),0)
			else
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*SteerInner*sDecay),0)
			end	
		elseif name=="FR" then
			if _GSteerC >= 0 then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*SteerInner*sDecay),0)
			else
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*SteerOuter*sDecay),0)
			end
		elseif name=='R' then
			if _Tune.FWSteer=='None' then
			elseif _Tune.FWSteer=='Static' then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerInner*rsDecay*rsMul),0)
			elseif _Tune.FWSteer=='Speed' then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*RSteerInner*rsDecay*mathMin(1,(velMag/_Tune.RSteerSpeed))),0)
			elseif _Tune.FWSteer=='Both' then
				v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerInner*rsDecay*mathMax(-1,rsMul)),0)
			end
		elseif name=='RL' then
			if _Tune.FWSteer=='None' then
			elseif _Tune.FWSteer=='Static' then
				if _GSteerC >= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerOuter*rsDecay*rsMul),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerInner*rsDecay*rsMul),0)
				end
			elseif _Tune.FWSteer=='Speed' then
				local minVel = mathMin(1,(velMag/_Tune.RSteerSpeed))
				if _GSteerC >= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*RSteerOuter*rsDecay*minVel),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*RSteerInner*rsDecay*minVel),0)
				end
			elseif _Tune.FWSteer=='Both' then
				local maxVel = mathMax(-1,rsMul)
				if _GSteerC >= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerOuter*rsDecay*maxVel),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerInner*rsDecay*maxVel),0)
				end
			end
		elseif name=='RR' then
			if _Tune.FWSteer=='None' then
			elseif _Tune.FWSteer=='Static' then
				if _GSteerC >= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerInner*rsDecay*rsMul),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerOuter*rsDecay*rsMul),0)
				end
			elseif _Tune.FWSteer=='Speed' then
				local minVel = mathMin(1,(velMag/_Tune.RSteerSpeed))
				if _GSteerC >= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*RSteerInner*rsDecay*minVel),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,-mathRad(_GSteerC*RSteerOuter*rsDecay*minVel),0)
				end
			elseif _Tune.FWSteer=='Both' then
				local maxVel = mathMax(-1,rsMul)
				if _GSteerC >= 0 then
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerInner*rsDecay*maxVel),0)
				else
					v.Arm.Steer.CFrame=v.Base.CFrame*CFrame.Angles(0,mathRad(_GSteerC*RSteerOuter*rsDecay*maxVel),0)
				end
			end
		end
	end
end

local fFD = _Tune.FinalDrive*_Tune.FDMult
local fFDr = fFD*30/math.pi
local cGrav = workspace.Gravity*_Tune.InclineComp/32.2
local wDRatio = wDia*math.pi/60
local cfWRot = CFrame.Angles(math.pi/2,-math.pi/2,0)
local cfYRot = CFrame.Angles(0,math.pi,0)

if not _Tune.Engine and _Tune.Electric then 
	_Tune.Redline = _Tune.E_Redline 
	_Tune.PeakRPM = _Tune.E_Trans2 
	_Tune.Turbochargers = 0
	_Tune.Superchargers = 0
	_Tune.Clutch = false 
	_Tune.IdleRPM = 0 
	_Tune.ClutchType = "Clutch" 
	_Tune.AutoShiftType = "DCT" 
	_Tune.ShiftUpTime = 0.1 
	_Tune.ShiftDnTime = 0.1 
end

_TCount = _Tune.Turbochargers
_TPsi = _Tune.T_Boost*_Tune.Turbochargers
_SCount = _Tune.Superchargers
_SPsi = _Tune.S_Boost*_Tune.Superchargers

local HP=_Tune.Horsepower/100
local HP_T=((_Tune.Horsepower*((_TPsi)*(_Tune.CompressionRatio/10))/7.5)/2)/100
local HP_S=((_Tune.Horsepower*((_SPsi)*(_Tune.CompressionRatio/10))/7.5)/2)/100

local Peak=_Tune.PeakRPM/1000
local Sharpness=_Tune.PeakSharpness
local CurveMult=_Tune.CurveMult
local EQ=_Tune.EqPoint/1000

function CurveN(RPM)
	RPM=RPM/1000
	return ((-(RPM-Peak)^2)*math.min(HP/(Peak^2),CurveMult^(Peak/HP))+HP)*(RPM-((RPM^Sharpness)/(Sharpness*Peak^(Sharpness-1))))
end
local PeakCurveN = CurveN(_Tune.PeakRPM)

function CurveT(RPM)
	RPM=RPM/1000
	return ((-(RPM-Peak)^2)*math.min(HP_T/(Peak^2),CurveMult^(Peak/HP_T))+HP_T)*(RPM-((RPM^Sharpness)/(Sharpness*Peak^(Sharpness-1))))
end
local PeakCurveT = CurveT(_Tune.PeakRPM)

function CurveS(RPM)
	RPM=RPM/1000
	return ((-(RPM-Peak)^2)*math.min(HP_S/(Peak^2),CurveMult^(Peak/HP_S))+HP_S)*(RPM-((RPM^Sharpness)/(Sharpness*Peak^(Sharpness-1))))
end
local PeakCurveS = CurveS(_Tune.PeakRPM)

local EHP=_Tune.E_Horsepower/100
local ETQ=_Tune.E_Torque/100
local ETrans1=_Tune.E_Trans1/1000
local ETrans2=_Tune.E_Trans2/1000
local ELimit=_Tune.E_Redline/1000 

function elecHP(RPM)
	RPM=RPM/1000
	local retVal=1e-9
	if RPM<=ETrans1 then
		retVal=((((RPM/ETrans1)^_Tune.EH_FrontMult)/(1/EHP))*(RPM/ETrans1))+((((RPM/ETrans1)^(1/_Tune.EH_FrontMult))/(1/EHP))*(1-(RPM/ETrans1)))
	elseif ETrans1<RPM and RPM<ETrans2 then
		retVal=EHP
	elseif ETrans2<=RPM then
		retVal=EHP-(((RPM-ETrans2)/(ELimit-ETrans2))^_Tune.EH_EndMult)/(1/(EHP*(_Tune.EH_EndPercent/100)))
	end
	return retVal
end

function elecTQ(RPM)
	RPM=RPM/1000
	local retVal=1e-9
	if RPM<ETrans1 then
		retVal=ETQ
	elseif ETrans1<=RPM then
		retVal=ETQ-(((RPM-ETrans1)/(ELimit-ETrans1))^_Tune.ET_EndMult)/(1/(ETQ*(_Tune.ET_EndPercent/100)))
	end
	return retVal
end

function GetNCurve(x,gear)
	local hp=(math.max(CurveN(x)/(PeakCurveN/HP),0))*100
	return hp,((hp*(EQ/x))*_Tune.Ratios[gear+2]*fFD)*1000
end

function GetECurve(x,gear)
	local hp=(math.max(elecHP(x),0))*100
	local tq=(math.max(elecTQ(x),0))*100
	if gear~=0 then
		return hp,math.max(tq*_Tune.Ratios[gear+2]*fFD,0)
	else
		return 0,0
	end
end

function GetTCurve(x,gear)
	local hp=(math.max(CurveT(x)/(PeakCurveT/HP_T),0))*100
	return hp,((hp*(EQ/x))*_Tune.Ratios[gear+2]*fFD)*1000
end	

function GetSCurve(x,gear)
	local hp=(math.max(CurveS(x)/(PeakCurveS/HP_S),0))*100
	return hp,((hp*(EQ/x))*_Tune.Ratios[gear+2]*fFD)*1000
end	

local NCache = {}
local ECache = {}
local TCache = {}
local SCache = {}

for gear,ratio in pairs(_Tune.Ratios) do
	local nhpPlot = {}
	local ehpPlot = {}
	local thpPlot = {}
	local shpPlot = {}
	for rpm = 0, math.ceil((_Tune.Redline+100)/100) do
		local ntqPlot = {}
		local etqPlot = {}
		local ttqPlot = {}
		local stqPlot = {}
		if rpm~=0 then
			if _Tune.Engine then
				ntqPlot.Horsepower,ntqPlot.Torque = GetNCurve(rpm*100,gear-2)
				if _TCount~=0 then
					ttqPlot.Horsepower,ttqPlot.Torque = GetTCurve(rpm*100,gear-2)
				else
					ttqPlot.Horsepower,ttqPlot.Torque = 0,0
				end
				if _SCount~=0 then
					stqPlot.Horsepower,stqPlot.Torque = GetSCurve(rpm*100,gear-2)
				else
					stqPlot.Horsepower,stqPlot.Torque = 0,0
				end
			else
				ntqPlot.Horsepower,ntqPlot.Torque = 0,0
				ttqPlot.Horsepower,ttqPlot.Torque = 0,0
				stqPlot.Horsepower,stqPlot.Torque = 0,0
			end
			if _Tune.Electric then
				etqPlot.Horsepower,etqPlot.Torque = GetECurve(rpm*100,gear-2)
			else
				etqPlot.Horsepower,etqPlot.Torque = 0,0
			end
		else
			ntqPlot.Horsepower,ntqPlot.Torque = 0,0
			etqPlot.Horsepower,etqPlot.Torque = 0,0
			ttqPlot.Horsepower,ttqPlot.Torque = 0,0
			stqPlot.Horsepower,stqPlot.Torque = 0,0
		end
		if _Tune.Engine then
			nhp,ntq = GetNCurve((rpm+1)*100,gear-2)
			if _TCount~=0 then
				thp,ttq = GetTCurve((rpm+1)*100,gear-2)
			else
				thp,ttq = 0,0
			end
			if _SCount~=0 then
				shp,stq = GetSCurve((rpm+1)*100,gear-2)
			else
				shp,stq = 0,0
			end
		else
			nhp,ntq = 0,0
			thp,ttq = 0,0
			shp,stq = 0,0
		end
		if _Tune.Electric then
			ehp,etq = GetECurve((rpm+1)*100,gear-2)
		else
			ehp,etq = 0,0
		end
		ntqPlot.HpSlope,ntqPlot.TqSlope = (nhp-ntqPlot.Horsepower),(ntq-ntqPlot.Torque)
		etqPlot.HpSlope,etqPlot.TqSlope = (ehp-etqPlot.Horsepower),(etq-etqPlot.Torque)
		ttqPlot.HpSlope,ttqPlot.TqSlope = (thp-ttqPlot.Horsepower),(ttq-ttqPlot.Torque)
		stqPlot.HpSlope,stqPlot.TqSlope = (shp-stqPlot.Horsepower),(stq-stqPlot.Torque)
		nhpPlot[rpm] = ntqPlot
		ehpPlot[rpm] = etqPlot
		thpPlot[rpm] = ttqPlot
		shpPlot[rpm] = stqPlot
	end
	table.insert(NCache,nhpPlot)
	table.insert(ECache,ehpPlot)
	table.insert(TCache,thpPlot)
	table.insert(SCache,shpPlot)
end

task.wait()

function Auto()
	local maxSpin = 0
	for _, v in pairs(Drive) do 
		if v.RotVelocity.Magnitude > maxSpin then 
			maxSpin = v.RotVelocity.Magnitude 
		end 
	end
	if not _IsOn then return end
	if _Tune.AutoShiftVers == "Old" and _CGear == 0 then 
		_CGear = 1 
		_ClPressing = false 
		return
	end
	if _CGear >= 1 then
		local carVelocity = car.DriveSeat.Velocity.Magnitude
		if (_CGear == 1 and _InBrake > 0 and carVelocity < 5) and _Tune.AutoShiftVers == "Old" then
			_CGear = -1 
			_ClPressing = false
			return
		end
		if carVelocity > 5 then
			if _Tune.AutoShiftMode == "RPM" then
				if _RPM > (_Tune.PeakRPM + _Tune.AutoUpThresh) then
					if not _ShiftUp and not _Shifting then 
						_ShiftUp = true 
					end
				elseif _CGear > 1 then
					local predictedRPM = math.max(
						math.min(maxSpin * _Tune.Ratios[_CGear+1] * fFDr, _Tune.Redline + 100),
						_Tune.IdleRPM
					)
					if predictedRPM < (_Tune.PeakRPM - _Tune.AutoDownThresh) then
						if not _ShiftDn and not _Shifting then 
							_ShiftDn = true 
						end
					end
				end
			else
				local upshiftSpeed = math.ceil(wDRatio * (_Tune.PeakRPM + _Tune.AutoUpThresh) / _Tune.Ratios[_CGear+2] / fFD)
				local downshiftSpeed = math.ceil(wDRatio * (_Tune.PeakRPM - _Tune.AutoDownThresh) / _Tune.Ratios[_CGear+1] / fFD)

				if carVelocity > upshiftSpeed then
					if not _ShiftUp and not _Shifting then 
						_ShiftUp = true 
					end
				elseif carVelocity < downshiftSpeed and _CGear > 1 then
					if not _ShiftDn and not _Shifting then 
						_ShiftDn = true 
					end
				end
			end
		end
	else
		if (_InThrot - (_Tune.IdleThrottle/100) > 0 and car.DriveSeat.Velocity.Magnitude < 5) and _Tune.AutoShiftVers == "Old" then
			_CGear = 1 
			_ClPressing = false
		end
	end
end

function Gear()
	local maxSpin = 0
	for _, v in pairs(Drive) do 
		if v.RotVelocity.Magnitude > maxSpin then 
			maxSpin = v.RotVelocity.Magnitude 
		end 
	end

	if _ShiftUp and not _Shifting then
		local cantShift = (_TMode == "Manual" and not _ClPressing) or 
			(_TMode == "Manual" and _Tune.ClutchRel and (_InThrot - (_Tune.IdleThrottle/100) > 0)) or 
			_CGear == #_Tune.Ratios - 2 or 
			(_TMode ~= "Manual" and not _IsOn)

		if cantShift then 
			_ShiftUp = false 
			return 
		end

		local NextGear = math.min(_CGear + 3, #_Tune.Ratios)

		if _TMode ~= "Manual" then
			_Shifting = true
			if _CGear > 0 then 
				if _Tune.AutoShiftType == "DCT" then 
					task.wait(_Tune.ShiftUpTime)
				elseif _Tune.AutoShiftType == "Rev" then
					local targetRPM = math.max(math.min(maxSpin * _Tune.Ratios[NextGear] * fFDr, _Tune.Redline - _Tune.RevBounce), _Tune.IdleRPM)
					repeat 
						task.wait() 
					until _RPM <= targetRPM or not _IsOn or _ShiftDn 
				end
			end
		end
		_ShiftUp = false
		_Shifting = false
		if _TMode ~= "Manual" and not _IsOn then return end
		_CGear = math.min(_CGear + 1, #_Tune.Ratios - 2)
		if (_TMode ~= "Manual" or (_TMode == "Manual" and _CGear == 1)) and _IsOn then 
			_ClPressing = false 
		end
	end
	if _ShiftDn and not _Shifting then
		if (_TMode == "Manual" and not _ClPressing) or _CGear == -1 or (_TMode ~= "Manual" and not _IsOn) then 
			_ShiftDn = false 
			return 
		end
		local PrevGear = math.min(_CGear + 1, #_Tune.Ratios)
		if _TMode ~= "Manual" then
			_Shifting = true
			if _CGear > 1 then 
				if _Tune.AutoShiftType == "DCT" then 
					task.wait(_Tune.ShiftDnTime)
				elseif _Tune.AutoShiftType == "Rev" then
					local targetRPM = math.max(math.min(maxSpin * _Tune.Ratios[PrevGear] * fFDr, _Tune.Redline - _Tune.RevBounce), _Tune.IdleRPM)
					repeat 
						task.wait() 
					until _RPM >= targetRPM or not _IsOn or _ShiftUp
				end
			end
		end
		_ShiftDn = false
		_Shifting = false
		if _TMode ~= "Manual" and not _IsOn then return end
		_CGear = math.max(_CGear - 1, -1)
		if (_TMode ~= "Manual" or (_TMode == "Manual" and _CGear == -1)) and _IsOn then 
			_ClPressing = false 
		end
	end
end

local _GoalRPM=0
local tqTCS = 1
local sthrot = 0
local _StallOK = false
local ticc = tick()

function Engine(dt)
	local deltaTime = (60/(1/dt))
	if ((_CGear == 0 or _Shifting) and _IsOn) then 
		_ClPressing = true
		_Clutch = 1
		_StallOK = false
	end

	local revMin = _Tune.IdleRPM 
	local goalMin = _Tune.IdleRPM 
	local goalMax = _Tune.Redline
	if _Tune.Stall and _Tune.Clutch then revMin = 0 end

	if _Shifting and _ShiftUp then 
		_GThrot = 0
	elseif _Shifting and _ShiftDn then
		_GThrot = (_Tune.ShiftThrot/100)
	else
		if (_Tune.AutoShiftVers == "Old" and _CGear==-1 and _TMode=="Auto") then
			_GThrot = _InBrake
		else
			_GThrot = _InThrot
		end
	end

	if (_Tune.AutoShiftVers == "Old" and _CGear==-1 and _TMode=="Auto") then
		_GBrake = _InThrot-(_Tune.IdleThrottle/100)
	else
		_GBrake = _InBrake
	end

	if not _IsOn then 
		ticc = tick()
		revMin = 0 
		goalMin = 0
		_GThrot = _Tune.IdleThrottle/100
		if _TMode~="Manual" then 
			_CGear = 0 
			_ClPressing = true 
			_Clutch = 1 
		end
	end

	if ((_ClPressing and _CGear == 0) or (_PlayerClutch and _CGear ~= 0)) and _Tune.NeutralLimit then
		if (_CGear == 0 and not _Tune.LimitClutch) or _Tune.LimitClutch then
			goalMax = _Tune.NeutralRevRPM
		end
	end
	local maxSpin = 0
	local maxCount = 0
	local revThrot = _GThrot

	for i,v in pairs(Drive) do 
		maxSpin = maxSpin + v.RotVelocity.Magnitude 
		maxCount = maxCount + 1 
	end
	if maxCount > 0 then
		maxSpin = maxSpin/maxCount
	end

	if _GoalRPM > goalMax+100 then 
		revThrot = _Tune.IdleThrottle/100
	end

	if _Tune.Engine or _Tune.Electric then
		_GoalRPM = math.clamp((_RPM-_Tune.RevDecay*deltaTime)+((_Tune.RevDecay+_Tune.RevAccel)*revThrot*deltaTime),goalMin,_Tune.Redline+100)
	end

	if _GoalRPM > _Tune.Redline then 
		if _CGear < #_Tune.Ratios-2 then
			_GoalRPM = _GoalRPM-_Tune.RevBounce
		else
			_GoalRPM = _GoalRPM-_Tune.RevBounce*.5
		end
	end

	local _WheelRPM = maxSpin*_Tune.Ratios[_CGear+2]*fFDr

	if _Tune.Clutch then
		if parentValues.AutoClutch.Value and _IsOn then
			if _Tune.ClutchType == "Clutch" then
				if _ClPressing then _ClutchKick = 1 end
				_ClutchKick = _ClutchKick*(_Tune.ClutchEngage/100)		
				local ClRPMInfluence = 0
				if _Tune.ClutchMode ~= "New" then
					ClRPMInfluence = math.max((_RPM-_Tune.IdleRPM)*_Tune.ClutchRPMMult/(_Tune.Redline-_Tune.IdleRPM),0)
				end
				local speedFactor = (parentValues.Velocity.Value.Magnitude/_Tune.SpeedEngage)/math.abs(_CGear)
				_ClutchModulate = math.min(speedFactor + ClRPMInfluence - _ClutchKick, 1)
			elseif _Tune.ClutchType == "CVT" or (_Tune.ClutchType == "TorqueConverter" and _Tune.TQLock) then
				local clutchEngageFactor = _Tune.ClutchEngage/100
				local noThrottleAndLowSpeed = (_GThrot-(_Tune.IdleThrottle/100)==0 and parentValues.Velocity.Value.Magnitude<_Tune.SpeedEngage)
				local throttleButLowRPM = (_GThrot-(_Tune.IdleThrottle/100)~=0 and (_RPM < _Tune.RPMEngage and _WheelRPM < _Tune.RPMEngage))

				if noThrottleAndLowSpeed or throttleButLowRPM then
					_ClutchModulate = math.min(_ClutchModulate*clutchEngageFactor, 1)
				else
					_ClutchModulate = math.min(_ClutchModulate*clutchEngageFactor+(1-clutchEngageFactor), 1)
				end
			elseif _Tune.ClutchType == "TorqueConverter" and not _Tune.TQLock then
				_ClutchModulate = math.min((_RPM/_Tune.Redline)*0.7, 1)
			end
			_Clutch = _ClPressing and 1 or math.min(1-_ClutchModulate,1)
			_StallOK = (_Clutch<=0.01) or _StallOK
		else
			_StallOK = _Tune.Stall
			_Clutch = parentValues.Clutch.Value
		end
	else
		_StallOK = false
		_Clutch = (_ClPressing or _Shifting) and 1 or 0
	end

	local aRPM = math.max(math.min((_GoalRPM*_Clutch) + (_WheelRPM*(1-_Clutch)),_Tune.Redline+100),revMin)
	local clutchP = _ClPressing and 0 or math.min(math.abs(aRPM-_RPM)/(_Tune.Flywheel*deltaTime),.9)
	_RPM = _RPM*clutchP + aRPM*(1-clutchP)

	if _RPM<=(_Tune.IdleRPM/4) and _StallOK and (tick()-ticc>=0.2) then 
		isond.Value = not _Tune.Stall 
	end

	_spLimit = (_Tune.Redline+100)/(fFDr*_Tune.Ratios[_CGear+2])
	if _RPM>_Tune.Redline then 
		_RPM = _RPM - (_CGear<#_Tune.Ratios-2 and _Tune.RevBounce or _Tune.RevBounce*.5)
	end

	local TPsi = _TCount > 0 and _TPsi/_TCount or 0
	local _BThrot = _GThrot

	if _Tune.Engine then
		if _TCount > 0 then
			local boostFactor = (_HP*(_BThrot*1.2)/_Tune.Horsepower)/8 - (_TBoost/TPsi*(TPsi/15))
			local lagFactor = (8/(_Tune.T_BoostLag/(deltaTime)))*2

			if _TCount ~= 2 then
				_TBoost = _TBoost + ((boostFactor * lagFactor)/TPsi)*15
			else
				if _TBoost < 1 then
					_TBoost = _TBoost + ((boostFactor * lagFactor)/TPsi)*15
				else
					_TBoost = _TBoost + ((boostFactor * (8/(_Tune.T2_BoostLag/(deltaTime)))*2)/TPsi)*15
				end
			end
			_TBoost = math.clamp(_TBoost, 0.05, 2)
		else
			_TBoost = 0
		end

		if _SCount > 0 then
			if _BThrot > sthrot then
				sthrot = math.min(_BThrot, sthrot+_Tune.S_Sensitivity*deltaTime)
			elseif _BThrot < sthrot then
				sthrot = math.max(_BThrot, sthrot-_Tune.S_Sensitivity*deltaTime)
			end
			_SBoost = (_RPM/_Tune.Redline)*(.5+(1.5*sthrot))
		else
			_SBoost = 0
		end
	else
		_TBoost = 0
		_SBoost = 0
	end

	if _Tune.Engine then
		local rpm100 = math.floor(math.min(_Tune.Redline,math.max(0,_RPM))/100)
		local rpmFrac = (((_RPM-math.floor(_RPM/100))/100)%1)
		local cTq = NCache[_CGear+2][rpm100]
		_NH = cTq.Horsepower + (cTq.HpSlope * rpmFrac)
		_NT = cTq.Torque + (cTq.TqSlope * rpmFrac)
		if _TCount > 0 then
			local tTq = TCache[_CGear+2][rpm100]
			_TH = (tTq.Horsepower + (tTq.HpSlope * rpmFrac)) * (_TBoost/2)
			_TT = (tTq.Torque + (tTq.TqSlope * rpmFrac)) * (_TBoost/2)
		else
			_TH, _TT = 0, 0
		end
		if _SCount > 0 then
			local sTq = SCache[_CGear+2][rpm100]
			_SH = (sTq.Horsepower + (sTq.HpSlope * rpmFrac)) * (_SBoost/2)
			_ST = (sTq.Torque + (sTq.TqSlope * rpmFrac)) * (_SBoost/2)
		else
			_SH, _ST = 0, 0
		end
		_BH = _TH + _SH
		_BT = _TT + _ST
	else
		_NH, _NT = 0, 0
		_TH, _TT = 0, 0
		_SH, _ST = 0, 0
		_BH, _BT = 0, 0
	end
	if _Tune.Electric and _CGear ~= 0 then
		local rpm100 = math.floor(math.min(_Tune.Redline,math.max(100,_RPM))/100)
		local rpmFrac = (((_RPM-math.floor(_RPM/100))/100)%1)

		local eTq = ECache[_CGear+2][rpm100]
		_EH = eTq.Horsepower + (eTq.HpSlope * rpmFrac)
		_ET = eTq.Torque + (eTq.TqSlope * rpmFrac)
	else
		_EH, _ET = 0, 0
	end
	_HP = _NH + _BH + _EH
	_OutTorque = _NT + _BT + _ET
	local driveSeatt = car:FindFirstChild("DriveSeat")
	if not driveSeatt then return end
	local iComp = (car.DriveSeat.CFrame.lookVector.y) * cGrav
	if _CGear == -1 then iComp = -iComp end
	_OutTorque = _OutTorque * math.max(1, (1+iComp))
	local fwspeed, fwcount, rwspeed, rwcount = 0, 0, 0, 0
	local wheels = car.Wheels:GetChildren()
	for i, v in pairs(wheels) do
		local name = v.Name
		if name == "FL" or name == "FR" or name == "F" then
			fwspeed = fwspeed + v.RotVelocity.Magnitude
			fwcount = fwcount + 1
		elseif name == "RL" or name == "RR" or name == "R" then
			rwspeed = rwspeed + v.RotVelocity.Magnitude
			rwcount = rwcount + 1
		end
	end
	if fwcount > 0 then fwspeed = fwspeed / fwcount end
	if rwcount > 0 then rwspeed = rwspeed / rwcount end
	local cwspeed = (fwspeed + rwspeed) / 2
	for i, v in pairs(wheels) do
		local name = v.Name
		local aRef = (name == "FL" or name == "RL") and -1 or 1
		local diffMult = 1
		local RRdiffMult, RLdiffMult, FRdiffMult, FLdiffMult = 1, 1, 1, 1
		if _Tune.DifferentialType == 'Old' then
			if name == "FL" or name == "FR" then
				if fwspeed > 0 then
					diffMult = math.max(0, math.min(1, 1 + (((v.RotVelocity.Magnitude-fwspeed)/fwspeed)/(math.max(_Tune.FDiffSlipThres,1)/100))*((_Tune.FDiffLockThres-50)/50)))
					if _Tune.Config == "AWD" and cwspeed > 0 then
						diffMult = math.max(0, math.min(1, diffMult*(1+(((fwspeed-cwspeed)/cwspeed)/(math.max(_Tune.CDiffSlipThres,1)/100))*((_Tune.CDiffLockThres-50)/50))))
					end
				end
			elseif name == "RL" or name == "RR" then
				if rwspeed > 0 then 
					diffMult = math.max(0, math.min(1, 1 + (((v.RotVelocity.Magnitude-rwspeed)/rwspeed)/(math.max(_Tune.RDiffSlipThres,1)/100))*((_Tune.RDiffLockThres-50)/50)))
					if _Tune.Config == "AWD" and cwspeed > 0 then
						diffMult = math.max(0, math.min(1, diffMult*(1+(((rwspeed-cwspeed)/cwspeed)/(math.max(_Tune.CDiffSlipThres,1)/100))*((_Tune.CDiffLockThres-50)/50))))
					end
				end
			end
		else
			if name == "FR" and car.Wheels:FindFirstChild("FL") then
				local FLRotMag = car.Wheels.FL.RotVelocity.Magnitude
				if FLRotMag > 0 then 
					local avg = ((v.RotVelocity.Magnitude/FLRotMag)-1)*(_Tune.FDiffPreload/10)
					FRdiffMult = math.ceil(math.max(0, math.min(2, 1-(((_Tune.FDiffPower/100)*avg*_GThrot) + ((_Tune.FDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
					FLdiffMult = 2-FRdiffMult
				end
			elseif name == "FL" and car.Wheels:FindFirstChild("FR") then
				local FRRotMag = car.Wheels.FR.RotVelocity.Magnitude
				if FRRotMag > 0 then 
					local avg = ((v.RotVelocity.Magnitude/FRRotMag)-1)*(_Tune.FDiffPreload/10)
					FLdiffMult = math.ceil(math.max(0, math.min(2, 1-(((_Tune.FDiffPower/100)*avg*_GThrot) + ((_Tune.FDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
					FRdiffMult = 2-FLdiffMult
				end
			elseif name == "RR" and car.Wheels:FindFirstChild("RL") then
				local RLRotMag = car.Wheels.RL.RotVelocity.Magnitude
				if RLRotMag > 0 then 
					local avg = ((v.RotVelocity.Magnitude/RLRotMag)-1)*(_Tune.RDiffPreload/10)
					RRdiffMult = math.ceil(math.max(0, math.min(2, 1-(((_Tune.RDiffPower/100)*avg*_GThrot) + ((_Tune.RDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
					RLdiffMult = 2-RRdiffMult
				end
			elseif name == "RL" and car.Wheels:FindFirstChild("RR") then
				local RRRotMag = car.Wheels.RR.RotVelocity.Magnitude
				if RRRotMag > 0 then
					local avg = ((v.RotVelocity.Magnitude/RRRotMag)-1)*(_Tune.RDiffPreload/10)
					RLdiffMult = math.ceil(math.max(0, math.min(2, 1-(((_Tune.RDiffPower/100)*avg*_GThrot) + ((_Tune.RDiffCoast/100)*avg*(1-_GThrot)))))*100)/100
					RRdiffMult = 2-RLdiffMult
				end
			end
		end
		_TCSActive = false
		_ABSActive = false
		local on = isond.Value and 1 or 0
		local throt = _GThrot
		local brake = _GBrake
		local clutch = _ClPressing and 0 or 1
		local tq = _OutTorque
		local tqABS = 1
		if _ABS and brake > 0 and math.abs(v.RotVelocity.Magnitude*(v.Size.x/2) - v.Velocity.Magnitude) - _Tune.ABSThreshold > 0 then
			tqABS = 0
			_ABSActive = true
		end
		local PBrakeV = _PBrake and 1 or 0
		local driven = false
		for _, a in pairs(Drive) do if a == v then driven = true break end end
		if driven then
			if _Tune.Config == "AWD" then
				local bias = (_Tune.TorqueVector+1)/2
				if string.find(name, "F") then
					tq = tq * (1-bias)
				elseif string.find(name, "R") then
					tq = tq * bias
				end
			end
			tqTCS = 1
			if _TCS and throt > 0 then
				local slipDiff = math.abs(v.RotVelocity.Magnitude*(v.Size.x/2) - v.Velocity.Magnitude) - _Tune.TCSThreshold
				if slipDiff > 0 then
					tqTCS = 1 - (math.min(slipDiff/_Tune.TCSGradient, 1) * (1-(_Tune.TCSLimit/100)))
					if tqTCS < 1 then
						_TCSAmt = tqTCS
						_TCSActive = true
					end
				end
			end
			local dir = _CGear == -1 and -1 or 1
			if _Tune.ClutchKick and car.DriveSeat.Velocity.Magnitude < _Tune.KickSpeedThreshold and 
				_RPM > _Tune.Redline - _Tune.KickRPMThreshold and v["#BV"].MotorMaxTorque < 1 then 
				tq = tq * _Tune.KickMult
			end
			local tqOUT = (tq/1.5) * (60/workspace:GetRealPhysicsFPS()) * throt * tqTCS * on * clutch
			local motorTq = tqOUT * diffMult
			if name == 'RR' then
				v["#AV"].MotorMaxTorque = motorTq * RRdiffMult
			elseif name == 'RL' then
				v["#AV"].MotorMaxTorque = motorTq * RLdiffMult
			elseif name == 'FR' then
				v["#AV"].MotorMaxTorque = motorTq * FRdiffMult
			elseif name == 'FL' then
				v["#AV"].MotorMaxTorque = motorTq * FLdiffMult
			else
				v["#AV"].MotorMaxTorque = motorTq
			end
			v["#AV"].AngularVelocity = _spLimit * dir
			local brakeTorque = 0
			if string.find(name, "F") then
				brakeTorque = (FBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(EBrakeForce*((1-throt)*(_RPM/_Tune.Redline)))+(PBrakeForceF*PBrakeV)
			else
				brakeTorque = (RBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(EBrakeForce*((1-throt)*(_RPM/_Tune.Redline)))+(PBrakeForceR*PBrakeV)
			end
			v["#BV"].MotorMaxTorque = brakeTorque
		else
			v["#AV"].MotorMaxTorque = 0
			v["#AV"].AngularVelocity = 0
			local brakeTorque = 0
			if string.find(name, "F") then
				brakeTorque = (FBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(PBrakeForceF*PBrakeV)
			else
				brakeTorque = (RBrakeForce*(60/workspace:GetRealPhysicsFPS())*brake*tqABS)+(PBrakeForceR*PBrakeV)
			end
			v["#BV"].MotorMaxTorque = brakeTorque
		end
	end
end

function Flip()
	if not car:FindFirstChild("DriveSeat") or not car.DriveSeat:FindFirstChild("Flip") then return end
	local isUpsideDown = (car.DriveSeat.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector.y <= 0.1
	if not isUpsideDown or FlipDB then
		FlipWait = tick()
	else
		if tick() - FlipWait >= 3 then
			FlipDB = true
			local gyro = car.DriveSeat.Flip
			gyro.maxTorque = Vector3.new(10000, 0, 10000)
			gyro.P = 3000
			gyro.D = 500
			task.wait(1)
			gyro.maxTorque = Vector3.new(0, 0, 0)
			gyro.P = 0
			gyro.D = 0

			FlipDB = false
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	_IsOn = isond.Value
	_InControls = z1.ControlsOpen.Value
	Inputs(dt)
	Steering(dt)
	Gear()
	Engine(dt)

	parentValues.Gear.Value = _CGear
	parentValues.RPM.Value = _RPM
	local boostTurbo = (_TBoost/2) * _TPsi
	local boostSuper = (_SBoost/2) * _SPsi
	parentValues.Boost.Value = boostTurbo + boostSuper
	parentValues.BoostTurbo.Value = boostTurbo
	parentValues.BoostSuper.Value = boostSuper
	parentValues.HpNatural.Value = _NH
	parentValues.HpElectric.Value = _EH
	parentValues.HpTurbo.Value = _TH
	parentValues.HpSuper.Value = _SH
	parentValues.HpBoosted.Value = _BH
	parentValues.Horsepower.Value = _HP
	local gearRatio = _Tune.Ratios[_CGear+2]
	parentValues.TqNatural.Value = _NT/gearRatio/fFD
	parentValues.TqElectric.Value = _ET/gearRatio/fFD
	parentValues.TqTurbo.Value = _TT/gearRatio/fFD
	parentValues.TqSuper.Value = _ST/gearRatio/fFD
	local tqBoosted = parentValues.TqTurbo.Value + parentValues.TqSuper.Value
	parentValues.TqBoosted.Value = tqBoosted
	parentValues.Torque.Value = parentValues.TqNatural.Value + parentValues.TqElectric.Value + tqBoosted
	parentValues.TransmissionMode.Value = _TMode
	parentValues.Throttle.Value = _GThrot
	parentValues.Brake.Value = _GBrake
	if parentValues.AutoClutch.Value then
		parentValues.Clutch.Value = _Clutch
	end
	parentValues.SteerC.Value = _GSteerC
	parentValues.SteerT.Value = _GSteerT
	parentValues.PBrake.Value = _PBrake
	parentValues.TCS.Value = _TCS
	parentValues.TCSActive.Value = _TCSActive
	parentValues.TCSAmt.Value = 1 - _TCSAmt
	parentValues.ABS.Value = _ABS
	parentValues.ABSActive.Value = _ABSActive
	parentValues.MouseSteerOn.Value = _MSteer
	parentValues.Velocity.Value = car.DriveSeat.Velocity
end)

-------------------------
--[[
	--// viexd3v >~<
]]

local screenGUI = script:FindFirstAncestorWhichIsA("ScreenGui")
if not screenGUI then return end

local carControlFrame = screenGUI:WaitForChild("CarControl")
local mainContainer = carControlFrame:WaitForChild("MainContainer")
local buttonsContainer = carControlFrame:WaitForChild("ButtonsContainer")
local SGUContainer = screenGUI:FindFirstChild("SGUContainer")
local transmissionButton = mainContainer:WaitForChild("Transmission")
local pBrakeButton = buttonsContainer:WaitForChild("Handbrake")
local Buttons = screenGUI:WaitForChild("Buttons")

transmissionButton.MouseButton1Click:Connect(function()
	local customInput = {
		KeyCode = _CTRL["ContlrToggleTMode"],
		UserInputState = Enum.UserInputState.Begin,
		UserInputType = {
			Name = "Button1"
		}
	}
	DealWithInput(customInput)
end)

pBrakeButton.MouseButton1Down:Connect(function() _PBrake = true end)
pBrakeButton.MouseButton1Up:Connect(function() _PBrake = false end)

if UserInputService.TouchEnabled then
	Buttons.Visible = true
	buttonsContainer.Position = UDim2.new(1, -8, 0.6, 0)
	buttonsContainer.AnchorPoint = Vector2.new(1, 0.5)
	if SGUContainer then
		SGUContainer.Position = UDim2.new(0, 8, 0.94, 0)
		SGUContainer.AnchorPoint = Vector2.new(0, 1)
		SGUContainer.UIListLayout.FillDirection = Enum.FillDirection.Vertical
	end
end

--// VIEX PART ENDED
-------------------------
local function GameLoop()
	local lastTime = tick()
	local waitTime = 0.0667
	while true do
		local currentTime = tick()
		local elapsed = currentTime - lastTime
		local sleepTime = math.max(0, waitTime - elapsed)
		task.wait(sleepTime)
		lastTime = tick()
		if _TMode == "Auto" then 
			Auto() 
		end
		if _Tune.AutoFlip then 
			Flip() 
		end
	end
end

task.spawn(GameLoop)

UserInputService.InputBegan:Connect(DealWithInput)
UserInputService.InputChanged:Connect(DealWithInput)
UserInputService.InputEnded:Connect(DealWithInput)
