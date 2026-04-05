-- StarterPlayerScripts/CombatVFXHandler.client.lua
-- Xử lý toàn bộ Hiệu ứng hình ảnh (VFX) và Âm thanh (SFX) khi có va chạm

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- 1. Tìm đường dẫn Remotes
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("Combat")
local VFXEvent = CombatRemotes:WaitForChild("VFXEvent")

-- 2. Tìm "Kho hàng" Assets (Dựa theo ảnh đệ chụp)
-- Lưu ý: Đảm bảo thư mục VFXAssets nằm trong Shared nhé!
local VFXAssets = ReplicatedStorage:WaitForChild("VFXAssets") 
local VFXFolder = VFXAssets:WaitForChild("VFX")
local SoundsFolder = VFXAssets:WaitForChild("Sounds") -- Tí đệ nhớ tạo folder này và cho âm thanh vào nhé

----------------------------------------------------------------
-- HÀM TRUNG TÂM: Tạo Hiệu ứng & Âm thanh tại vị trí chém
----------------------------------------------------------------
local function spawnVFXAtPosition(hitType, position)
    if not position then return end

    -- A. Tạo một Part neo tạm thời vô hình tại vị trí chém trúng
    local anchor = Instance.new("Part")
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CFrame = CFrame.new(position)
    anchor.Parent = workspace

    -- B. Lấy cái Attachment "siêu phẩm" của đệ ra (chứa Lightning, Flare...)
    local originalAttachment = VFXFolder:FindFirstChild("Attachment")
    if originalAttachment then
        local attachmentClone = originalAttachment:Clone()
        attachmentClone.Parent = anchor
        
        -- Kích hoạt toàn bộ Particle bên trong Attachment đó
        for _, particle in ipairs(attachmentClone:GetChildren()) do
            if particle:IsA("ParticleEmitter") then
                -- Phát ra 10 hạt (đệ có thể chỉnh số lượng tùy ý)
                particle:Emit(10) 
            end
        end
    else
        warn("[VFXHandler] Không tìm thấy Attachment trong VFXAssets/VFX")
    end

    -- C. PHẦN SOUND: Tìm và phát âm thanh tương ứng
    local soundName = ""
    if hitType == "NormalHit" then soundName = "NormalHit"
    elseif hitType == "Blocked" then soundName = "BlockHit"
    elseif hitType == "SuperArmor" then soundName = "SuperArmorHit"
    elseif hitType == "FinisherHit" then soundName = "FinisherHit"
    end

    local soundEffect = SoundsFolder:FindFirstChild(soundName)
    if soundEffect then
        local soundClone = soundEffect:Clone()
        soundClone.Parent = anchor
        soundClone:Play()
    else
        warn("[VFXHandler] Chưa có âm thanh này trong kho:", soundName)
    end

    -- D. Dọn rác sau 2 giây (để tránh lag game)
    Debris:AddItem(anchor, 2)
end

----------------------------------------------------------------
-- Các hàm phân loại đòn đánh
----------------------------------------------------------------

local function playNormalHit(targetChar, hitPosition)
    print("[VFX] 🩸 Normal Hit phát động tại:", hitPosition)
    spawnVFXAtPosition("NormalHit", hitPosition)
end

local function playBlockedHit(targetChar, hitPosition)
    print("[VFX] 🛡️ Blocked! KENG KENG tại:", hitPosition)
    spawnVFXAtPosition("Blocked", hitPosition)
end

local function playSuperArmorHit(targetChar, hitPosition)
    print("[VFX] 🗿 Super Armor Hit! Boss không xi nhê tại:", hitPosition)
    spawnVFXAtPosition("SuperArmor", hitPosition)
end

local function playFinisherHit(targetChar, hitPosition)
    print("[VFX] 💥 FINISHER HIT! Sát thương chí mạng tại:", hitPosition)
    spawnVFXAtPosition("FinisherHit", hitPosition)
end

----------------------------------------------------------------
-- Lắng nghe tín hiệu từ Server
----------------------------------------------------------------

VFXEvent.OnClientEvent:Connect(function(hitType, targetChar, hitPosition)
    if not targetChar or not hitPosition then return end

    if hitType == "NormalHit" then
        playNormalHit(targetChar, hitPosition)
    elseif hitType == "Blocked" then
        playBlockedHit(targetChar, hitPosition)
    elseif hitType == "SuperArmor" then
        playSuperArmorHit(targetChar, hitPosition)
    elseif hitType == "FinisherHit" then
        playFinisherHit(targetChar, hitPosition)
    else
        warn("[VFXHandler] Nhận được hitType không xác định:", hitType)
    end
end)

print("[CombatVFXHandler] Đã sẵn sàng nổ hiệu ứng và âm thanh!")