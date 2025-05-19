function MakeWeld(x,y,type,s) 
	if type==nil then type="Weld" end
	local W=Instance.new(type,x) 
	W.Part0=x W.Part1=y 
	W.C0=x.CFrame:inverse()*x.CFrame 
	W.C1=y.CFrame:inverse()*x.CFrame 
	if type=="Motor" and s~=nil then 
		W.MaxVelocity=s 
	end 
	return W	
end

function ModelWeld(a, b) 
	if a:IsA("BasePart") then 
		MakeWeld(b, a, "Weld") 
	elseif a:IsA("Model") then 
		local children = a:GetChildren()
		for i = 1, #children do
			ModelWeld(children[i], b) 
		end 
	end 
end

function UnAnchor(a) 
	if a:IsA("BasePart") then 
		a.Anchored = false  
	end 
	local children = a:GetChildren()
	for i = 1, #children do 
		UnAnchor(children[i]) 
	end 
end

local car = script.Parent.Parent
local _Tune = require(script.Parent)

task.wait(_Tune.LoadDelay)

local Drive = car.Wheels:GetChildren()

function DReduce(p)
	local children = p:GetChildren()
	for i = 1, #children do
		local v = children[i]
		if v:IsA("BasePart") then
			if not v.CustomPhysicalProperties then 
				v.CustomPhysicalProperties = PhysicalProperties.new(v.Material) 
			end
			local props = v.CustomPhysicalProperties
			v.CustomPhysicalProperties = PhysicalProperties.new(
				0.0001,
				props.Friction,
				props.Elasticity,
				props.FrictionWeight,
				props.ElasticityWeight
			)
			v.Massless = true
		end
		DReduce(v)
	end
end
DReduce(car)

function getParts(model, t, a)
	local aCFrame = a.CFrame
	local children = model:GetChildren()
	for i = 1, #children do
		local v = children[i]
		if v:IsA("BasePart") then 
			table.insert(t, {v, aCFrame:toObjectSpace(v.CFrame)})
		elseif v:IsA("Model") then 
			getParts(v, t, a)
		end
	end
end

local fDensity = _Tune.FWheelDensity
local rDensity = _Tune.RWheelDensity

local cos, sin, rad = math.cos, math.sin, math.rad
local pi = math.pi

local fDistX = _Tune.FWsBoneLen * cos(rad(_Tune.FWsBoneAngle))
local fDistY = _Tune.FWsBoneLen * sin(rad(_Tune.FWsBoneAngle))
local rDistX = _Tune.RWsBoneLen * cos(rad(_Tune.RWsBoneAngle))
local rDistY = _Tune.RWsBoneLen * sin(rad(_Tune.RWsBoneAngle))

local fSLX = _Tune.FSusLength * cos(rad(_Tune.FSusAngle))
local fSLY = _Tune.FSusLength * sin(rad(_Tune.FSusAngle))
local rSLX = _Tune.RSusLength * cos(rad(_Tune.RSusAngle))
local rSLY = _Tune.RSusLength * sin(rad(_Tune.RSusAngle))

local surfaceTypes = {"Top", "Bottom", "Left", "Right", "Front", "Back"}
local angles90 = CFrame.Angles(rad(90), 0, rad(90))
local anglesNeg90 = CFrame.Angles(rad(90), 0, rad(-90))

for _, v in pairs(Drive) do
	local isFrontWheel = v.Name == "FL" or v.Name == "FR" or v.Name == "F"
	if v:IsA("BasePart") then
		if not v.CustomPhysicalProperties then 
			v.CustomPhysicalProperties = PhysicalProperties.new(v.Material) 
		end
		local props = v.CustomPhysicalProperties
		local density = isFrontWheel and fDensity or rDensity
		v.CustomPhysicalProperties = PhysicalProperties.new(
			density,
			props.Friction,
			props.Elasticity,
			props.FrictionWeight,
			props.ElasticityWeight
		)
	end
	for i = 1, #surfaceTypes do
		v[surfaceTypes[i] .. "Surface"] = Enum.SurfaceType.SmoothNoOutlines
	end
	local WParts = {}
	local tPos = v.Position - car.DriveSeat.Position
	if v.Name == "FL" or v.Name == "RL" then
		v.CFrame = car.DriveSeat.CFrame * angles90
	else
		v.CFrame = car.DriveSeat.CFrame * anglesNeg90
	end
	v.CFrame = v.CFrame + tPos
	if v:FindFirstChild("Parts") then
		getParts(v.Parts, WParts, v)
	end
	if v:FindFirstChild("Fixed") then
		getParts(v.Fixed, WParts, v)
	end
	if v.Name=="FL" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.FCamber),math.rad(-_Tune.FCaster),math.rad(_Tune.FToe))
	elseif v.Name=="FR" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.FCamber),math.rad(_Tune.FCaster),math.rad(-_Tune.FToe))
	elseif v.Name=="RL" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.RCamber),math.rad(-_Tune.RCaster),math.rad(_Tune.RToe))
	elseif v.Name=="RR" then
		v.CFrame = v.CFrame*CFrame.Angles(math.rad(_Tune.RCamber),math.rad(_Tune.RCaster),math.rad(-_Tune.RToe))
	end
	for _,a in pairs(WParts) do
		a[1].CFrame=v.CFrame:toWorldSpace(a[2])
	end
	local arm=Instance.new("Part",v)
	arm.Name="Arm"
	arm.Anchored=true
	arm.CanCollide=false
	arm.Size=Vector3.new(_Tune.AxleSize,_Tune.AxleSize,_Tune.AxleSize)
	arm.CFrame=(v.CFrame*CFrame.new(0,_Tune.StAxisOffset,0))*CFrame.Angles(-math.pi/2,-math.pi/2,0)
	arm.CustomPhysicalProperties = PhysicalProperties.new(_Tune.AxleDensity,0,0,100,100)
	arm.TopSurface=Enum.SurfaceType.Smooth
	arm.BottomSurface=Enum.SurfaceType.Smooth
	arm.Transparency=1
	local base=arm:Clone()
	base.Parent=v
	base.Name="Base"
	base.CFrame=base.CFrame*CFrame.new(0,_Tune.AxleSize,0)
	base.BottomSurface=Enum.SurfaceType.Hinge
	local axle=arm:Clone()
	axle.Parent=v
	axle.Name="Axle"
	axle.CFrame=CFrame.new(v.Position-((v.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector*((v.Size.x/2)+(axle.Size.x/2))),v.Position)*CFrame.Angles(0,math.pi,0)
	axle.BackSurface=Enum.SurfaceType.Hinge
	local axlep=arm:Clone()
	axlep.Parent=v
	axlep.Name='AxleP'
	axlep.CFrame=v.CFrame
	MakeWeld(axlep,axle)
	if v.Name=="F" or v.Name=="R" then
		local axle2=arm:Clone()
		axle2.Parent=v
		axle2.Name="Axle"
		axle2.CFrame=CFrame.new(v.Position+((v.CFrame*CFrame.Angles(math.pi/2,0,0)).lookVector*((v.Size.x/2)+(axle2.Size.x/2))),v.Position)*CFrame.Angles(0,math.pi,0)
		axle2.BackSurface=Enum.SurfaceType.Hinge
		MakeWeld(arm,axle2)
	end
	if _Tune.SuspensionEnabled==true then
		local SuspensionGeometry=v:FindFirstChild("SuspensionGeometry")
		if SuspensionGeometry then
			local WeldModel=SuspensionGeometry:FindFirstChild('Weld')
			if WeldModel then
				ModelWeld(WeldModel,car.DriveSeat)
			end
			MakeWeld(SuspensionGeometry.SpringTop,car.DriveSeat)
			MakeWeld(SuspensionGeometry.Hub,base)
			local susparts=SuspensionGeometry:GetDescendants()
			for _,p in pairs(susparts) do
				if p:IsA('Part') then
					if _Tune.CustomSuspensionDensity~=0 then
						p.CustomPhysicalProperties=PhysicalProperties.new(_Tune.CustomSuspensionDensity,0,0,0,0)
					else
						p.CustomPhysicalProperties=PhysicalProperties.new(_Tune.CustomSuspensionDensity,0,0,0,0)
						p.Massless=true
					end
				end
			end
			if _Tune.SusVisible==true then
				for _,p in pairs(susparts) do
					if p:IsA('Part') then
						p.Transparency=.5
					elseif p:IsA("SpringConstraint") or p:IsA("HingeConstraint") or p:IsA("BallSocketConstraint") then
						p.Visible=true
					end
				end
			else
				for _,p in pairs(susparts) do
					if p:IsA('Part') then
						p.Transparency=1
					elseif p:IsA("SpringConstraint") or p:IsA("HingeConstraint") or p:IsA("BallSocketConstraint") then
						p.Visible=false
					end
				end
			end
			local g = Instance.new("BodyGyro",SuspensionGeometry:FindFirstChild('SpringBottom'))
			g.Name = "Stabilizer"
			g.MaxTorque = Vector3.new(0,0,1)
			g.P = 0
			sp=SuspensionGeometry:FindFirstChildOfClass('SpringConstraint')
			sp.LimitsEnabled = true
			sp.Visible=_Tune.SusVisible
			sp.Radius=_Tune.SusRadius
			sp.Thickness=_Tune.SusThickness
			sp.Color=BrickColor.new(_Tune.SusColor)
			sp.Coils=_Tune.SusCoilCount
			if v.Name == "FL" or v.Name=="FR" or v.Name =="F" then
				g.D = _Tune.FGyroDampening
				sp.Damping = _Tune.FSusDamping
				sp.Stiffness = _Tune.FSusStiffness
				sp.FreeLength = _Tune.FSusLength+_Tune.FPreCompress
				sp.MaxLength = _Tune.FSusLength+_Tune.FExtensionLim
				sp.MinLength = _Tune.FSusLength-_Tune.FCompressLim
			else
				g.D = _Tune.RGyroDampening
				sp.Damping = _Tune.RSusDamping
				sp.Stiffness = _Tune.RSusStiffness
				sp.FreeLength = _Tune.RSusLength+_Tune.RPreCompress
				sp.MaxLength = _Tune.RSusLength+_Tune.RExtensionLim
				sp.MinLength = _Tune.RSusLength-_Tune.RCompressLim
			end
			v.Massless=false
		else
			local sa=arm:Clone()
			sa.Parent=v
			sa.Name="#SA"
			if v.Name == "FL" or v.Name=="FR" or v.Name =="F" then
				local aOff = _Tune.FAnchorOffset
				sa.CFrame=v.CFrame*CFrame.new(_Tune.AxleSize/2,-fDistX,-fDistY)*CFrame.new(aOff[3],aOff[1],-aOff[2])*CFrame.Angles(-math.pi/2,-math.pi/2,0)
			else
				local aOff = _Tune.RAnchorOffset
				sa.CFrame=v.CFrame*CFrame.new(_Tune.AxleSize/2,-rDistX,-rDistY)*CFrame.new(aOff[3],aOff[1],-aOff[2])*CFrame.Angles(-math.pi/2,-math.pi/2,0)
			end
			local sb=sa:Clone()
			sb.Parent=v
			sb.Name="#SB"
			sb.CFrame=sa.CFrame*CFrame.new(0,0,_Tune.AxleSize)
			sb.FrontSurface=Enum.SurfaceType.Hinge	
			local g = Instance.new("BodyGyro",sb)
			g.Name = "Stabilizer"
			g.MaxTorque = Vector3.new(0,0,1)
			g.P = 0
			local sf1 = Instance.new("Attachment",sa)
			sf1.Name = "SAtt"
			local sf2 = sf1:Clone()
			sf2.Parent = sb
			if v.Name == "FL" or v.Name == "FR" or v.Name == "F" then
				local aOff = _Tune.FSpringOffset
				if v.Name == "FL" then
					sf1.Position = Vector3.new(fDistX-fSLX+aOff[1],-fDistY+fSLY+aOff[2],_Tune.AxleSize/2+aOff[3])
					sf2.Position = Vector3.new(fDistX+aOff[1],-fDistY+aOff[2],-_Tune.AxleSize/2+aOff[3])
				else
					sf1.Position = Vector3.new(fDistX-fSLX+aOff[1],-fDistY+fSLY+aOff[2],_Tune.AxleSize/2-aOff[3])
					sf2.Position = Vector3.new(fDistX+aOff[1],-fDistY+aOff[2],-_Tune.AxleSize/2-aOff[3])
				end
			elseif v.Name == "RL" or v.Name=="RR" or v.Name == "R" then
				local aOff = _Tune.RSpringOffset
				if v.Name == "RL" then
					sf1.Position = Vector3.new(rDistX-rSLX+aOff[1],-rDistY+rSLY+aOff[2],_Tune.AxleSize/2+aOff[3])
					sf2.Position = Vector3.new(rDistX+aOff[1],-rDistY+aOff[2],-_Tune.AxleSize/2+aOff[3])
				else
					sf1.Position = Vector3.new(rDistX-rSLX+aOff[1],-rDistY+rSLY+aOff[2],_Tune.AxleSize/2-aOff[3])
					sf2.Position = Vector3.new(rDistX+aOff[1],-rDistY+aOff[2],-_Tune.AxleSize/2-aOff[3])
				end
			end
			sb:MakeJoints()
			local sp = Instance.new("SpringConstraint",v)
			sp.Name = "Spring"
			sp.Attachment0 = sf1
			sp.Attachment1 = sf2
			sp.LimitsEnabled = true
			sp.Visible=_Tune.SusVisible
			sp.Radius=_Tune.SusRadius
			sp.Thickness=_Tune.SusThickness
			sp.Color=BrickColor.new(_Tune.SusColor)
			sp.Coils=_Tune.SusCoilCount
			if v.Name == "FL" or v.Name=="FR" or v.Name =="F" then
				g.D = _Tune.FGyroDampening
				sp.Damping = _Tune.FSusDamping
				sp.Stiffness = _Tune.FSusStiffness
				sp.FreeLength = _Tune.FSusLength+_Tune.FPreCompress
				sp.MaxLength = _Tune.FSusLength+_Tune.FExtensionLim
				sp.MinLength = _Tune.FSusLength-_Tune.FCompressLim
			else
				g.D = _Tune.RGyroDampening
				sp.Damping = _Tune.RSusDamping
				sp.Stiffness = _Tune.RSusStiffness
				sp.FreeLength = _Tune.RSusLength+_Tune.RPreCompress
				sp.MaxLength = _Tune.RSusLength+_Tune.RExtensionLim
				sp.MinLength = _Tune.RSusLength-_Tune.RCompressLim
			end
			MakeWeld(car.DriveSeat,sa)
			MakeWeld(sb,base)
		end
	else
		MakeWeld(car.DriveSeat,base)
	end
	if _Tune.FWSteer=='Static' or _Tune.FWSteer=='Speed' or _Tune.FWSteer=='Both' then
	else
		if v.Name == "RL" or v.Name == "RR" or v.Name=="R" then
			MakeWeld(base,axle)
		end
	end
	if v.Parent.Name == "RL" or v.Parent.Name == "RR" or v.Name=="R" then
		MakeWeld(car.DriveSeat,arm)
	end
	MakeWeld(arm,axle)
	arm:MakeJoints()
	if v:FindFirstChild("SuspensionFixed")~=nil then
		ModelWeld(v.SuspensionFixed,car.DriveSeat)
	end
	if v:FindFirstChild("WheelFixed")~=nil then
		ModelWeld(v.WheelFixed,axle)
	end
	if v:FindFirstChild("Fixed")~=nil then
		ModelWeld(v.Fixed,arm)
	end
	if v:FindFirstChild("Parts")~=nil then
		ModelWeld(v.Parts,v)
	end
	if v:FindFirstChild("Steer") then
		v:FindFirstChild("Steer"):Destroy()
	end
	if v.Name=='FR' or v.Name=='FL' or v.Name=='F' then
		local steer=Instance.new("BodyGyro",arm)
		steer.Name="Steer"
		steer.P=_Tune.SteerP
		steer.D=_Tune.SteerD
		steer.MaxTorque=Vector3.new(0,_Tune.SteerMaxTorque,0)
		steer.CFrame=v.CFrame*CFrame.Angles(0,-math.pi/2,0)
	else
		if (_Tune.FWSteer=='Static' or _Tune.FWSteer=='Speed' or _Tune.FWSteer=='Both') then
			local steer=Instance.new("BodyGyro",arm)
			steer.Name="Steer"
			if _Tune.RSteerP~=nil and _Tune.RSteerD~=nil and _Tune.RSteerMaxTorque~=nil then
				steer.P=_Tune.RSteerP
				steer.D=_Tune.RSteerD
				steer.MaxTorque=Vector3.new(0,_Tune.RSteerMaxTorque,0)
			else
				steer.P=_Tune.SteerP
				steer.D=_Tune.SteerD
				steer.MaxTorque=Vector3.new(0,_Tune.SteerMaxTorque,0)
			end
			steer.CFrame=v.CFrame*CFrame.Angles(0,-math.pi/2,0)
		end
	end
	local gyro=Instance.new("BodyGyro",v)
	gyro.Name="Stabilizer"
	gyro.MaxTorque=Vector3.new(1,0,1)
	gyro.P=0
	if v.Name=="FL" or v.Name=="FR" or v.Name=="F" then
		gyro.D=_Tune.FGyroDamp
	else
		gyro.D=_Tune.RGyroDamp
	end
	local AV=Instance.new("HingeConstraint",v)
	AV.ActuatorType='Motor'
	AV.Attachment0=Instance.new("Attachment",v.AxleP)
	v.AxleP.Attachment.Name='AA'
	AV.Attachment1=Instance.new("Attachment",v)
	v.Attachment.Name='AB'
	AV.Name="#AV"
	AV.AngularVelocity=0
	AV.MotorMaxTorque=0
	local BV=Instance.new("HingeConstraint",v)
	BV.ActuatorType='Motor'
	BV.Attachment0=Instance.new("Attachment",v.AxleP)
	v.AxleP.Attachment.Name='BA'
	BV.Attachment1=Instance.new("Attachment",v)
	v.Attachment.Name='BB'
	BV.Name="#BV"
	BV.AngularVelocity=0
	BV.MotorMaxTorque=_Tune.PBrakeForce
	for _,c in pairs(v:GetDescendants()) do
		if c.ClassName=='Attachment' and c.Name~='SAtt' then
			if c.Parent.Name=='FL' or c.Parent.Name=='RL' or c.Parent.Parent.Name=='FL' or c.Parent.Parent.Name=='RL' then c.Orientation=Vector3.new(0,0,90) end
			if c.Parent.Name=='F' or c.Parent.Name=='R' or c.Parent.Parent.Name=='F' or c.Parent.Parent.Name=='R' 
				or c.Parent.Name=='FR' or c.Parent.Name=='RR' or c.Parent.Parent.Name=='FR' or c.Parent.Parent.Name=='RR' then c.Orientation=Vector3.new(180,0,90) end
		end
	end
end

local mass = 0

function getMass(p)
	local children = p:GetChildren()
	for i = 1, #children do
		local v = children[i]
		if v:IsA("BasePart") and not v.Massless then
			mass = mass + v:GetMass()
		end
		getMass(v)
	end	
end
getMass(car)

local targetWeight = _Tune.Weight / 2.205 / 8
if mass < targetWeight then
	local centerF, centerR = Vector3.new(), Vector3.new()
	local countF, countR = 0, 0
	for _, v in pairs(Drive) do
		if v.Name == "FL" or v.Name == "FR" or v.Name == "F" then
			centerF = centerF + v.CFrame.p
			countF = countF + 1
		else
			centerR = centerR + v.CFrame.p
			countR = countR + 1
		end
	end
	if countF > 0 then centerF = centerF / countF end
	if countR > 0 then centerR = centerR / countR end
	local center = centerR:Lerp(centerF, _Tune.WeightDist / 100)  
	local weightB = Instance.new("Part", car.Body)
	weightB.Name = "#Weight"
	weightB.Anchored = true
	weightB.CanCollide = false
	weightB.BrickColor = BrickColor.new("Really black")
	weightB.TopSurface = Enum.SurfaceType.Smooth
	weightB.BottomSurface = Enum.SurfaceType.Smooth
	weightB.Transparency = _Tune.WBVisible and 0.75 or 1
	local wbSize = _Tune.WeightBSize
	weightB.Size = Vector3.new(wbSize[1], wbSize[2], wbSize[3])
	local volumeFactor = weightB.Size.x * weightB.Size.y * weightB.Size.z * 1000 / 61024
	local tdensity = (_Tune.Weight / 2.205 - mass / 8) / volumeFactor / 1000
	weightB.CustomPhysicalProperties = PhysicalProperties.new(tdensity, 0, 0, 0, 0)
	weightB.CFrame = (car.DriveSeat.CFrame - car.DriveSeat.Position + center) * CFrame.new(0, _Tune.CGHeight, 0)
end

local flipG = Instance.new("BodyGyro", car.DriveSeat)
flipG.Name = "Flip"
flipG.D = 0
flipG.MaxTorque = Vector3.new(0, 0, 0)
flipG.P = 0

task.wait()

local da = require(game.ServerScriptService.Core.Modules.MiscWeld)
da.setupCar(car)

task.wait()
ModelWeld(car.Body,car.DriveSeat)
task.wait()	
UnAnchor(car)

script.Parent["A-Chassis Interface"].Car.Value=car
for i,v in pairs(script.Parent.Plugins:GetChildren()) do
	for _,a in pairs(v:GetChildren()) do
		if a:IsA("RemoteEvent") or a:IsA("RemoteFunction") then 
			a.Parent=car
			for _,b in pairs(a:GetChildren()) do
				if b:IsA("Script") then b.Disabled=false end
			end	
		end
	end
	v.Parent = script.Parent["A-Chassis Interface"]
end
script.Parent.Plugins:Destroy()

local Seats = {}
function getSeats(p)
	local children = p:GetChildren()
	for i = 1, #children do
		local v = children[i]
		if v:IsA("VehicleSeat") or v:IsA("Seat") then
			table.insert(Seats, {Seat = v, Parts = {}})
		end
		getSeats(v)
	end	
end
getSeats(car)

function getPProperties(mod, t)
	local children = mod:GetChildren()
	for i = 1, #children do
		local v = children[i]
		if v:IsA("BasePart") then
			if not v.CustomPhysicalProperties then
				v.CustomPhysicalProperties = PhysicalProperties.new(v.Material)
			end
			local props = v.CustomPhysicalProperties
			table.insert(t, {v, props})
			v.CustomPhysicalProperties = PhysicalProperties.new(
				0.0001,
				props.Friction,
				props.Elasticity,
				props.FrictionWeight,
				props.ElasticityWeight
			)
		end
		getPProperties(v, t)
	end			
end

local seats_locked = false

for _, seatInfo in ipairs(Seats) do
	local seat = seatInfo.Seat
	seat.ChildAdded:connect(function(child)
		if child.Name == "SeatWeld" and child:IsA("Weld") and 
			child.Part1 and child.Part1.Parent ~= workspace and 
			not child.Part1.Parent:IsDescendantOf(car) then
			seatInfo.Parts = {}
			getPProperties(child.Part1.Parent, seatInfo.Parts)
		end
	end)
	seat.ChildRemoved:connect(function(child)
		if child.Name == "SeatWeld" and child:IsA("Weld") then
			for _, partInfo in ipairs(seatInfo.Parts) do
				local part, props = partInfo[1], partInfo[2]
				if part and props and part:IsDescendantOf(workspace) then
					part.CustomPhysicalProperties = props
				end
			end
			seatInfo.Parts = {}
		end
	end)
end

local core = game.ReplicatedStorage.CoreClient
local events = core.Events
local events_cars = events.CarController

local connections = {} 

car.Values.Locked.Changed:Connect(function()
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	connections = {}
	local isLocked = car.Values.Locked.Value
	for _, seatInfo in ipairs(Seats) do
		local seatPart = seatInfo.Seat
		if seatPart.Occupant then
			if not isLocked then continue end
			connections[seatPart] = seatPart:GetPropertyChangedSignal("Occupant"):Once(function()
				seatPart.Disabled = isLocked
			end)
			continue	
		end
		seatPart.Disabled = isLocked
	end
end)

car.DriveSeat.ChildAdded:connect(function(child)
	if child.Name ~= "SeatWeld" or not child:IsA("Weld") then return end

	local character = child.Part1 and child.Part1.Parent
	local player = character and game.Players:GetPlayerFromCharacter(character)

	if not player then return end

	--if car.Name ~= tostring(player.UserId) and 
	--	not events_cars.HasAccess:Invoke(player, car.Name) then
	--	child:Destroy()
	--	return
	--end

	car.DriveSeat:SetNetworkOwner(player)
	local interface = script.Parent["A-Chassis Interface"]:Clone()
	interface.Parent = player.PlayerGui
end)

car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name ~= "SeatWeld" or not child:IsA("Weld") then return end

	local flip = car.DriveSeat:FindFirstChild("Flip")
	if flip then
		flip.MaxTorque = Vector3.new()
	end

	car.DriveSeat:SetNetworkOwner()
	
	for _, wheel in pairs(car.Wheels:GetChildren()) do
		local av = wheel:FindFirstChild("#AV")
		if not av then continue end

		if av:IsA("BodyAngularVelocity") then
			if av.AngularVelocity.Magnitude > 0 then
				av.AngularVelocity = Vector3.new()
				av.MaxTorque = Vector3.new()
			end
		else
			if av.AngularVelocity > 0 then
				av.AngularVelocity = 0
				av.MotorMaxTorque = 0
			end
		end
	end
end)
