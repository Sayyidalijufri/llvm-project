; RUN: opt < %s -globaldce -S | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

declare { i8*, i1 } @llvm.type.checked.load(i8*, i32, metadata)

; A vtable that contains a non-nfunc entry, @regular_non_virtual_funcA, but
; without the !vtable_strict_types attribute, so GlobalDCE will treat the
; @regular_non_virtual_funcA slot as eligible for VFE, and remove it.
@vtableA = internal unnamed_addr constant { [3 x i8*] } { [3 x i8*] [
  i8* bitcast (void ()* @vfunc1_live to i8*),
  i8* bitcast (void ()* @vfunc2_dead to i8*),
  i8* bitcast (void ()* @regular_non_virtual_funcA to i8*)
]}, align 8, !type !0, !type !1, !vcall_visibility !{i64 2}
!0 = !{i64 0, !"vfunc1.type"}
!1 = !{i64 8, !"vfunc2.type"}

; CHECK:      @vtableA = internal unnamed_addr constant { [3 x i8*] } { [3 x i8*] [
; CHECK-SAME:   i8* bitcast (void ()* @vfunc1_live to i8*),
; CHECK-SAME:   i8* null,
; CHECK-SAME:   i8* null
; CHECK-SAME: ] }, align 8, !type !0, !type !1, !vcall_visibility !2


; A vtable that contains a non-nfunc entry, @regular_non_virtual_funcB, with a
; !vtable_strict_types marker which means anything that does not have a matching
; !type offset should not participate in VFE. GlobalDCE should keep
; @regular_non_virtual_funcB in the vtable.
@vtableB = internal unnamed_addr constant { [3 x i8*] } { [3 x i8*] [
  i8* bitcast (void ()* @vfunc1_live to i8*),
  i8* bitcast (void ()* @vfunc2_dead to i8*),
  i8* bitcast (void ()* @regular_non_virtual_funcB to i8*)
]}, align 8, !type !2, !type !3, !vcall_visibility !{i64 2}, !vtable_strict_types !998
!2 = !{i64 0, !"vfunc1.type"}
!3 = !{i64 8, !"vfunc2.type"}

; CHECK:      @vtableB = internal unnamed_addr constant { [3 x i8*] } { [3 x i8*] [
; CHECK-SAME:   i8* bitcast (void ()* @vfunc1_live to i8*),
; CHECK-SAME:   i8* null,
; CHECK-SAME:   i8* bitcast (void ()* @regular_non_virtual_funcB to i8*)
; CHECK-SAME: ] }, align 8, !type !0, !type !1, !vcall_visibility !2

; (1) vfunc1_live is referenced from @main, stays alive
define internal void @vfunc1_live() {
  ; CHECK: define internal void @vfunc1_live(
  ret void
}

; (2) vfunc2_dead is never referenced, gets removed and vtable slot is null'd
define internal void @vfunc2_dead() {
  ; CHECK-NOT: define internal void @vfunc2_dead(
  ret void
}

; (3) regular, non-virtual function that just happens to be referenced from the
; vtable data structure, but vtable is not marked with !vtable_strict_types, is
; removed
define internal void @regular_non_virtual_funcA() {
  ; CHECK-NOT: define internal void @regular_non_virtual_funcA(
  ret void
}

; (4) regular, non-virtual function that just happens to be referenced from the
; vtable data structure, marked with !vtable_strict_types, should stay alive
define internal void @regular_non_virtual_funcB() {
  ; CHECK: define internal void @regular_non_virtual_funcB(
  ret void
}

define void @main() {
  %1 = ptrtoint { [3 x i8*] }* @vtableA to i64 ; to keep @vtableA alive
  %2 = ptrtoint { [3 x i8*] }* @vtableB to i64 ; to keep @vtableB alive
  %3 = tail call { i8*, i1 } @llvm.type.checked.load(i8* null, i32 0, metadata !"vfunc1.type")
  ret void
}

!998 = !{}
!999 = !{i32 1, !"Virtual Function Elim", i32 1}
!llvm.module.flags = !{!999}
