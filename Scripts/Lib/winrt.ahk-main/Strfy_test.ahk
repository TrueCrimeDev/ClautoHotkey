#Include Object.Stringify.ahk
#Include Object.Parse.ahk


class StrfyObject {
    static Get(TestID) {
        switch TestID {
            case 1: return StrfyObject.A_Object
        }
    }

    static A_Array := [
        [['AAA' Chr('0xFFC')], Map('AAM', 'AAM' Chr('0xFFC')), {AAO: 'AAO' Chr('0xFFC')}]
      , Map('AM1', ['AMA'], 'AM2', Map('AMM', 'AMM'), 'AM3', {AMO: 'AMO'})
      , {AO1: ['AOA', true], AO2: Map('AOM1', 'AOM', 'AOM2', false), AO3: {AOO1: 'AOO', AOO2: ''}}
    ]
    
    static M_Map := Map(
        'M1', [['MAA'], Map('MAM', 'MAM'), {MAO: 'MAO'}]
      , 'M2', Map('MM1', ['MMA'], 'MM2', Map('MMM', 'MMM'), 'MM3', {MMO: 'MMO'})
      , 'M3', {MO1: ['MOA'], MO2: Map('MOM', 'MOM'), MO3: {MOO: 'MOO'}}
    )

    static O_Object := {
        O1: [['OAA'], Map('OAM', 'OAM'), {OAO: 'OAO'}]
      , O2: Map('OM1', ['OMA'], 'OM2', Map('OMM', 'OMM'), 'OM3', {OMO: 'OMO'})
      , O3: {OO1: ['OOA'], OO2: Map('OOM', 'OOM'), OO3: {OOO: 'OOO'}}
    }

    static __ErrorProp := 0
    static ErrorProp {
        Get {
            return this.__ErrorProp
        }
    }
}
StrfyObject.M_Map['M2'].TestProp := 'Value'

O := {
    PrintTypeTags: true
  , Indent: '`s`s`s`s'
  , Newline: '`r`n'
  , MaxDepth: 4
  , IgnoreProps: 'i)^(?:Base|Prototype)$'
  , DynamicPropAction: 0
}
StrfyObject.Stringify(&Str, O.PrintTypeTags, O.Indent, O.Newline, O.MaxDepth, O.IgnoreProps
, O.DynamicPropAction)
A_Clipboard := Str
; outputdebug(str)
Props := []
For Prop in StrfyObject.OwnProps() {
    Props.Push(Prop)
}
for Prop in Props
    StrfyObject.DeleteProp(Prop)
Obj := ParseJson(Str)

sleep 1