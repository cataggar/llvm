; RUN: llc < %s -mtriple=i386-unknown-linux -relocation-model=pic -frame-pointer=all -verify-machineinstrs | FileCheck %s --check-prefix=X86
; RUN: llc < %s -mtriple=i386-unknown-linux -relocation-model=pic -frame-pointer=none -verify-machineinstrs | FileCheck %s --check-prefix=X86
; RUN: llc < %s -mtriple=x86_64-unknown-linux -relocation-model=pic -frame-pointer=all -verify-machineinstrs | FileCheck %s --check-prefix=X64
; RUN: llc < %s -mtriple=x86_64-unknown-linux -relocation-model=pic -frame-pointer=none -verify-machineinstrs | FileCheck %s --check-prefix=X64

; A large displacement must not be folded into a frame index, even when the
; displacement is matched before the frame index. Resolving the frame index
; would then overflow the signed 32-bit displacement. On i386, these GEPs can
; describe an access within the small stack object: the variable index cancels
; the constant offset using the target's 32-bit address arithmetic.

declare void @initialize(ptr)

define i32 @negative_displacement(i32 %index) {
; X86-LABEL: negative_displacement:
; X86:       movl {{.*}}-2147483648(
; X86:       retl
; X64-LABEL: negative_displacement:
; X64:       movl {{.*}}-2147483648(
; X64:       retq
  %stack = alloca [16 x i32], align 16
  call void @initialize(ptr %stack)
  %base = getelementptr i32, ptr %stack, i32 %index
  %address = getelementptr i8, ptr %base, i32 -2147483648
  %value = load i32, ptr %address, align 4
  ret i32 %value
}

define i32 @positive_displacement(i32 %index) {
; X86-LABEL: positive_displacement:
; X86:       movl {{.*}}2147483647(
; X86:       retl
; X64-LABEL: positive_displacement:
; X64:       movl {{.*}}2147483647(
; X64:       retq
  %stack = alloca [16 x i32], align 16
  call void @initialize(ptr %stack)
  %base = getelementptr i8, ptr %stack, i32 %index
  %address = getelementptr i8, ptr %base, i32 2147483647
  %value = load i32, ptr %address, align 4
  ret i32 %value
}
