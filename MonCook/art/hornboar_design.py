"""Redesigned elongated boar proportions in Roblox stud coordinates, not sphere blockout."""
from model_spec import BROWN, WARM, BEIGE, IVORY, GOLD, MAGIC
RIG = {
 'Root': {'parent':None,'position':(0,0,0)},
 'Spine': {'parent':'Root','position':(0,2.8,0)},
 'Neck': {'parent':'Spine','position':(0,3.0,-2.6)},
 'Head': {'parent':'Neck','position':(0,3.0,-3.5)},
 'FrontLeg_L': {'parent':'Spine','position':(-1.85,2.6,-1.75)},
 'FrontLeg_R': {'parent':'Spine','position':(1.85,2.6,-1.75)},
 'BackLeg_L': {'parent':'Spine','position':(-1.7,2.25,2.55)},
 'BackLeg_R': {'parent':'Spine','position':(1.7,2.25,2.55)},
 'FrontShin_L': {'parent':'FrontLeg_L','position':(-1.85,1.15,-1.9)},
 'FrontShin_R': {'parent':'FrontLeg_R','position':(1.85,1.15,-1.9)},
 'BackShin_L': {'parent':'BackLeg_L','position':(-1.7,1.05,2.7)},
 'BackShin_R': {'parent':'BackLeg_R','position':(1.7,1.05,2.7)},
 'Horn': {'parent':'Head','position':(0,4.05,-3.65)},
 'Tail': {'parent':'Spine','position':(0,2.8,3.6)},
}
ACTIONS = ('Idle','Walk','Run','Alert','ChargeWindup','Charge','Headbutt','LightHit','HeavyHit','HornHit','HornBreak','Stagger','Death')
