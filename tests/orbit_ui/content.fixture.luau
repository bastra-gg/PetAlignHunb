
do(function()
local content={Pages={bug=nT,farm=nU,train=nV,reb=nW,kill=nX,crystal=nY,boss=q.layoutUI.bossPage,egg=q.layoutUI.eggPage,teleport=q.layoutUI.teleportPage,quest=q.layoutUI.questPage,system=q.layoutUI.systemPage,interface=q.layoutUI.interfacePage}}
function content:HideLegacy()
 n7.Visible=false;n_.Visible=false;q.uiRoot.Enabled=false
end
function content:Style(root)
 for _,node in ipairs(root:GetDescendants())do
  if node:IsA("UIGradient")then node.Enabled=false
  elseif node:IsA("UIStroke")then node.Transparency=1
  elseif node:IsA("TextLabel")or node:IsA("TextButton")or node:IsA("TextBox")then
   node.TextSize=math.max(node.TextSize,node:IsA("TextLabel")and 11 or 13)
   node.TextTruncate=Enum.TextTruncate.AtEnd
   if node:IsA("TextButton")then
    node.AutoButtonColor=true
    if node.Text~=""and node.Size.Y.Scale==0 and node.Size.Y.Offset>0 and node.Size.Y.Offset<36 then
     node.Size=UDim2.new(node.Size.X.Scale,node.Size.X.Offset,0,36)
     local parent=node.Parent
     if parent:IsA("Frame")and parent.Size.Y.Scale==0 and parent.Size.Y.Offset>=26 and parent.Size.Y.Offset<=40 then
      parent.Size=UDim2.new(parent.Size.X.Scale,parent.Size.X.Offset,0,44)
     end
    end
   end
  end
 end
end
function content:Layout()
 if not self.Active then return end
 for _,page in pairs(self.Pages)do
  page.Position=UDim2.fromOffset(0,0);page.Size=UDim2.fromScale(1,1);page.ClipsDescendants=true
 end
 nL.Position=UDim2.fromOffset(0,0);nL.Size=UDim2.new(1,0,0,132);nL.LayoutOrder=-20
 local index=0
 for _,button in ipairs(nL:GetChildren())do if button:IsA("GuiButton")then
  button.Position=UDim2.new(index%2/2,index%2==1 and 3 or 0,0,math.floor(index/2)*44)
  button.Size=UDim2.new(0.5,-3,0,38);index+=1
 end end
 nG.Position=UDim2.fromOffset(0,0);nG.Size=UDim2.new(1,0,0,34);nG.TextSize=13
 nM.Position=UDim2.fromOffset(0,0);nM.Size=UDim2.fromScale(1,1)
 self:HideLegacy()
end
function content:Attach(tab,body,overlays,quick,footer)
 if not self.Pages[tab] then return false end
 if q.closePicker then q.closePicker()end
 if q.closeDeleteConfirmation then q.closeDeleteConfirmation()end
 self.Active=tab
 for id,page in pairs(self.Pages)do page.Parent=body;page.Visible=id==tab end
 p0.Parent=overlays
 if q.layoutUI.hologramDeleteOverlay then q.layoutUI.hologramDeleteOverlay.Parent=overlays end
 nL.Parent=self.Pages.system;nG.Parent=quick;nM.Parent=footer
 self:Style(self.Pages[tab]);self:Style(nL);self:Style(nM)
 if q.layoutUI.drawerFooter then q.layoutUI.drawerFooter()end
 sL=false;sR(tab);self:Layout()
 return true
end
function content:StopModes()jT()end
function content:Close()
 self.Active=nil
 if q.closePicker then q.closePicker()end
 if q.closeDeleteConfirmation then q.closeDeleteConfirmation()end
 for _,page in pairs(self.Pages)do page.Visible=false end
 self:HideLegacy()
end
q.hologramContent=content
end)()end

