class_name VisitorFrame
extends RefCounted

var head_transform: Transform3D = Transform3D.IDENTITY
var left_hand_transform: Transform3D = Transform3D.IDENTITY
var right_hand_transform: Transform3D = Transform3D.IDENTITY
var head_valid: bool = true
var left_hand_valid: bool = false
var right_hand_valid: bool = false
var left_hand_active: bool = false
var right_hand_active: bool = false
var motion_discontinuity: bool = false
