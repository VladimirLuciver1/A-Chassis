export type WeldTypes = "Weld" | "Motor" | "Snap"
export type WeldObject = {
	Part0: BasePart,
	Part1: BasePart,
	C0: CFrame,
	C1: CFrame,
	Parent: Instance,
	Name: string?,
	MaxVelocity: number?
}

export type BasePart = {
	CFrame: CFrame,
	Parent: Instance?
} & Instance

export type CarConfig = {
	wheelVelocity: number,
	seatOffset: Vector3,
	seatRotation: Vector3,
	seatTilt: number
}

local DEFAULT_CONFIG: CarConfig = {
	wheelVelocity = 0.5,
	seatOffset = Vector3.new(0, -0.5, 0),
	seatRotation = Vector3.new(-(math.pi/2), 0, 0),
	seatTilt = math.rad(13)
}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local function createCFrameFromConfig(config: CarConfig): CFrame
	return CFrame.new(config.seatOffset) * 
		CFrame.fromEulerAnglesXYZ(config.seatRotation.X, config.seatRotation.Y, config.seatRotation.Z) * 
		CFrame.Angles(config.seatTilt, 0, 0)
end

local MiscWeld = {}
MiscWeld.__index = MiscWeld

local function _createWeld(part0: BasePart, part1: BasePart, weldType: WeldTypes, maxVelocity: number?): WeldObject
	assert(part0, "Part0 must not be nil")
	assert(part1, "Part1 must not be nil")

	local weld = Instance.new(weldType)
	weld.Part0 = part0
	weld.Part1 = part1

	local inverseCFrame = part0.CFrame:Inverse()
	weld.C0 = inverseCFrame * part0.CFrame
	weld.C1 = inverseCFrame * part1.CFrame

	weld.Parent = part0

	if weldType == "Motor" and maxVelocity then
		weld.MaxVelocity = maxVelocity
	end

	return weld
end

local function _processModelWeld(model: Instance, basePart: BasePart): ()
	if model:IsA("BasePart") then
		_createWeld(basePart, model, "Weld")
	elseif model:IsA("Model") then
		for _, child in ipairs(model:GetChildren()) do
			_processModelWeld(child, basePart)
		end
	end
end

function MiscWeld.setupCar(car: Model, config: CarConfig?)
	local finalConfig: CarConfig = if config
		then table.clone(config)
		else table.clone(DEFAULT_CONFIG)

	local misc = car.Misc
	local wheel = misc.Wheel
	local driveSeat = car.DriveSeat

	local wheelWeld = _createWeld(wheel.A, driveSeat, "Motor", finalConfig.wheelVelocity)
	wheelWeld.Name = "W"

	_processModelWeld(wheel.Parts, wheel.A)

	local seatCFrame = createCFrameFromConfig(finalConfig)

	local connection
	connection = driveSeat.ChildAdded:Connect(function(child)
		if child.Name == "SeatWeld" and child:IsA("Weld") then
			local character = child.Part1.Parent
			if Players:GetPlayerFromCharacter(character) then
				child.C0 = seatCFrame
				connection:Disconnect()
			end
		end
	end)

	car.Destroying:Connect(function()
		if connection then
			connection:Disconnect()
		end
	end)

	return wheelWeld
end

return MiscWeld
