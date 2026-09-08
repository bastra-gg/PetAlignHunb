-- BGS Legacy Hub v0.4.7 version-only patch
-- Changes only visible/runtime version labels. No farm/TP logic changes.

return function(S)
    if type(S) ~= "table" then return S end

    S.version = "0.4.7"

    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    local gui = playerGui and playerGui:FindFirstChild("BGSLegacyHub")

    if gui then
        for _,obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local text = tostring(obj.Text or "")
                if text == "v0.4 · чистая сортировка / hitbox fix" then
                    obj.Text = "v0.4.7 · current island / TP fix"
                elseif text == "BGS Legacy Hub 0.4.0" then
                    obj.Text = "BGS Legacy Hub 0.4.7"
                elseif text:find("0.4.0",1,true) then
                    obj.Text = text:gsub("0%.4%.0","0.4.7")
                elseif text:find("v0.4 ",1,true) then
                    obj.Text = text:gsub("v0%.4 ","v0.4.7 ",1)
                end
            end
        end
    end

    S.status = "BGS Legacy Hub v0.4.7"
    return S
end
