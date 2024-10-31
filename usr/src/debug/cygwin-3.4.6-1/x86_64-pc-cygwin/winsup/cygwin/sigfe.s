	.include "tlsoffsets"
	.text

	.seh_proc _sigfe_maybe
_sigfe_maybe:					# stack is aligned on entry!
	.seh_endprologue
	movq	%gs:8,%r10			# location of bottom of stack
	leaq	_cygtls.initialized(%r10),%r11	# where we will be looking
	cmpq	%r11,%rsp			# stack loc > than tls
	jge	0f				# yep.  we don't have a tls.
	movl	_cygtls.initialized(%r10),%r11d
	cmpl	$0xc763173f,%r11d		# initialized?
	je	1f
0:	ret
	.seh_endproc

	.seh_proc _sigfe
_sigfe:						# stack is aligned on entry!
	.seh_endprologue
	movq	%gs:8,%r10			# location of bottom of stack
1:	movl	$1,%r11d			# potential lock value
	xchgl	%r11d,_cygtls.stacklock(%r10)	# see if we can grab it
	movl	%r11d,_cygtls.spinning(%r10)	# flag if we are waiting for lock
	testl	%r11d,%r11d			# it will be zero
	jz	2f				#  if so
	pause
	jmp	1b				# loop
2:	movq	$8,%rax			# have the lock, now increment the
	xaddq	%rax,_cygtls.stackptr(%r10)	#  stack pointer and get pointer
	leaq	_sigbe(%rip),%r11		# new place to return to
	xchgq	%r11,8(%rsp)			# exchange with real return value
	movq	%r11,(%rax)			# store real return value on alt stack
	incl	_cygtls.incyg(%r10)
	decl	_cygtls.stacklock(%r10)		# remove lock
	popq	%rax				# pop real function address from stack
	jmp	*%rax				# and jmp to it
	.seh_endproc

	.global _sigbe
	.seh_proc _sigbe
_sigbe:						# return here after cygwin syscall
						# stack is aligned on entry!
	.seh_endprologue
	movq	%gs:8,%r10			# address of bottom of tls
1:	movl	$1,%r11d			# potential lock value
	xchgl	%r11d,_cygtls.stacklock(%r10)	# see if we can grab it
	movl	%r11d,_cygtls.spinning(%r10)	# flag if we are waiting for lock
	testl	%r11d,%r11d			# it will be zero
	jz	2f				#  if so
	pause
	jmp	1b				#  and loop
2:	movq	$-8,%r11			# now decrement aux stack
	xaddq	%r11,_cygtls.stackptr(%r10)	#  and get pointer
	movq	-8(%r11),%r11			# get return address from signal stack
	decl	_cygtls.incyg(%r10)
	decl	_cygtls.stacklock(%r10)		# release lock
	jmp	*%r11				# "return" to caller
	.seh_endproc

	.global	sigdelayed
	.seh_proc sigdelayed
sigdelayed:
	pushq	%r10				# used for return address injection
	.seh_pushreg %r10
	pushq	%rbp
	.seh_pushreg %rbp
	movq	%rsp,%rbp
	pushf
	.seh_pushreg %rax			# fake, there's no .seh_pushreg for the flags
	# stack is aligned or unaligned on entry!
	# make sure it is aligned from here on
	# We could be called from an interrupted thread which doesn't know
	# about his fate, so save and restore everything and the kitchen sink.
	andq	$0xfffffffffffffff0,%rsp
	.seh_setframe %rbp,0
	pushq	%r15
	.seh_pushreg %r15
	pushq	%r14
	.seh_pushreg %r14
	pushq	%r13
	.seh_pushreg %r13
	pushq	%r12
	.seh_pushreg %r12
	pushq	%r11
	.seh_pushreg %r11
	pushq	%r9
	.seh_pushreg %r9
	pushq	%r8
	.seh_pushreg %r8
	pushq	%rsi
	.seh_pushreg %rsi
	pushq	%rdi
	.seh_pushreg %rdi
	pushq	%rdx
	.seh_pushreg %rdx
	pushq	%rcx
	.seh_pushreg %rcx
	pushq	%rbx
	.seh_pushreg %rbx
	pushq	%rax
	.seh_pushreg %rax
	subq	$0x128,%rsp
	.seh_stackalloc 0x128
	stmxcsr	0x124(%rsp)
	fnstcw	0x120(%rsp)
	movdqa	%xmm15,0x110(%rsp)
	movdqa	%xmm14,0x100(%rsp)
	movdqa	%xmm13,0xf0(%rsp)
	movdqa	%xmm12,0xe0(%rsp)
	movdqa	%xmm11,0xd0(%rsp)
	movdqa	%xmm10,0xc0(%rsp)
	movdqa	%xmm9,0xb0(%rsp)
	movdqa	%xmm8,0xa0(%rsp)
	movdqa	%xmm7,0x90(%rsp)
	movdqa	%xmm6,0x80(%rsp)
	movdqa	%xmm5,0x70(%rsp)
	movdqa	%xmm4,0x60(%rsp)
	movdqa	%xmm3,0x50(%rsp)
	movdqa	%xmm2,0x40(%rsp)
	movdqa	%xmm1,0x30(%rsp)
	movdqa	%xmm0,0x20(%rsp)
	.seh_endprologue

	movq	%gs:8,%r12			# get tls
	movl	_cygtls.saved_errno(%r12),%r15d	# temporarily save saved_errno
	movq	$_cygtls.start_offset,%rcx	# point to beginning of tls block
	addq	%r12,%rcx			#  and store as first arg to method
	call	_ZN7_cygtls19call_signal_handlerEv	# call handler

1:	movl	$1,%r11d			# potential lock value
	xchgl	%r11d,_cygtls.stacklock(%r12)	# see if we can grab it
	movl	%r11d,_cygtls.spinning(%r12)	# flag if we are waiting for lock
	testl	%r11d,%r11d			# it will be zero
	jz	2f				#  if so
	pause
	jmp	1b				#  and loop
2:	testl	%r15d,%r15d			# was saved_errno < 0
	jl	3f				# yup.  ignore it
	movq	_cygtls.errno_addr(%r12),%r11
	movl	%r15d,(%r11)
3:	movq	$-8,%r11			# now decrement aux stack
	xaddq	%r11,_cygtls.stackptr(%r12)	#  and get pointer
	xorq	%r10,%r10
	xchgq	%r10,-8(%r11)			# get return address from signal stack
	xorl	%r11d,%r11d
	movl	%r11d,_cygtls.incyg(%r12)
	movl	%r11d,_cygtls.stacklock(%r12)	# unlock
	movdqa	0x20(%rsp),%xmm0
	movdqa	0x30(%rsp),%xmm1
	movdqa	0x40(%rsp),%xmm2
	movdqa	0x50(%rsp),%xmm3
	movdqa	0x60(%rsp),%xmm4
	movdqa	0x70(%rsp),%xmm5
	movdqa	0x80(%rsp),%xmm6
	movdqa	0x90(%rsp),%xmm7
	movdqa	0xa0(%rsp),%xmm8
	movdqa	0xb0(%rsp),%xmm9
	movdqa	0xc0(%rsp),%xmm10
	movdqa	0xd0(%rsp),%xmm11
	movdqa	0xe0(%rsp),%xmm12
	movdqa	0xf0(%rsp),%xmm13
	movdqa	0x100(%rsp),%xmm14
	movdqa	0x110(%rsp),%xmm15
	fninit
	fldcw	0x120(%rsp)
	ldmxcsr	0x124(%rsp)
	addq	$0x128,%rsp
	popq	%rax
	popq	%rbx
	popq	%rcx
	popq	%rdx
	popq	%rdi
	popq	%rsi
	popq	%r8
	popq	%r9
	popq	%r11
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	movq	%rbp,%rsp
	subq	$8, %rsp
	popf
	popq	%rbp
	xchgq	%r10,(%rsp)
	ret
	.seh_endproc
_sigdelayed_end:
	.global _sigdelayed_end

# _cygtls::pop
	.global _ZN7_cygtls3popEv
	.seh_proc _ZN7_cygtls3popEv
_ZN7_cygtls3popEv:
	.seh_endprologue
	movq	$-8,%r11
	xaddq	%r11,_cygtls.stackptr_p(%rcx)
	movq	-8(%r11),%rax
	ret
	.seh_endproc

# _cygtls::lock
	.global _ZN7_cygtls4lockEv
	.seh_proc _ZN7_cygtls4lockEv
_ZN7_cygtls4lockEv:
	pushq	%r12
	.seh_pushreg %r12
	.seh_endprologue
	movq	%rcx,%r12
1:	movl	$1,%r11d
	xchgl	%r11d,_cygtls.stacklock_p(%r12)
	testl   %r11d,%r11d
	jz	2f
	pause
	jmp	1b
2:	popq	%r12
	ret
	.seh_endproc

# _cygtls::unlock
	.global _ZN7_cygtls6unlockEv
	.seh_proc _ZN7_cygtls6unlockEv
_ZN7_cygtls6unlockEv:
	.seh_endprologue
	decl	_cygtls.stacklock_p(%rcx)
	ret
	.seh_endproc

# _cygtls::locked
	.global _ZN7_cygtls6lockedEv
	.seh_proc _ZN7_cygtls6lockedEv
_ZN7_cygtls6lockedEv:
	.seh_endprologue
	movl	_cygtls.stacklock_p(%rcx),%eax
	ret
	.seh_endproc

	.seh_proc stabilize_sig_stack
stabilize_sig_stack:
	pushq	%r12
	.seh_pushreg %r12
	subq	$0x20,%rsp
	.seh_stackalloc 32
	.seh_endprologue
	movq	%gs:8,%r12
1:	movl	$1,%r10d
	xchgl	%r10d,_cygtls.stacklock(%r12)
	movl	%r10d,_cygtls.spinning(%r12)	# flag if we are waiting for lock
	testl	%r10d,%r10d
	jz	2f
	pause
	jmp	1b
2:	incl	_cygtls.incyg(%r12)
	cmpl	$0,_cygtls.sig(%r12)
	jz	3f
	decl	_cygtls.stacklock(%r12)		# unlock
	movq	$_cygtls.start_offset,%rcx	# point to beginning
	addq	%r12,%rcx			#  of tls block
	call	_ZN7_cygtls19call_signal_handlerEv
	jmp	1b
3:	decl	_cygtls.incyg(%r12)
	addq	$0x20,%rsp
	movq	%r12,%r11			# return tls addr in r11
	popq	%r12
	ret
	.seh_endproc

	.globl	sigsetjmp
	.seh_proc sigsetjmp
sigsetjmp:
	.seh_endprologue
	movl	%edx,0x100(%rcx)		# store savemask
	testl	%edx,%edx			# savemask != 0?
	je	setjmp				# no, skip fetching sigmask
	pushq	%rcx
	subq	$0x20,%rsp
	leaq	0x108(%rcx),%r8			# &sigjmp_buf.sigmask
	xorq	%rdx,%rdx			# NULL
	xorl	%ecx,%ecx			# SIG_SETMASK
	call	pthread_sigmask
	addq	$0x20,%rsp
	popq	%rcx
	jmp	setjmp
	.seh_endproc

	.globl  setjmp
	.seh_proc setjmp
setjmp:
	.seh_endprologue
	# We use the Windows jmp_buf layout with two small twists.
	# - we store the tls stackptr in Frame, MSVCRT stores a second copy
	#   of %rbp in Frame (twice? why?)
	# - we just store %rsp as is, MSVCRT stores %rsp of the caller in Rsp
	movq	%rbx,0x8(%rcx)
	movq	%rsp,0x10(%rcx)
	movq	%rbp,0x18(%rcx)
	movq	%rsi,0x20(%rcx)
	movq	%rdi,0x28(%rcx)
	movq	%r12,0x30(%rcx)
	movq	%r13,0x38(%rcx)
	movq	%r14,0x40(%rcx)
	movq	%r15,0x48(%rcx)
	movq	(%rsp),%r10
	movq	%r10,0x50(%rcx)
	stmxcsr	0x58(%rcx)
	fnstcw	0x5c(%rcx)
	# jmp_buf is potentially unaligned!
	movdqu	%xmm6,0x60(%rcx)
	movdqu	%xmm7,0x70(%rcx)
	movdqu	%xmm8,0x80(%rcx)
	movdqu	%xmm9,0x90(%rcx)
	movdqu	%xmm10,0xa0(%rcx)
	movdqu	%xmm11,0xb0(%rcx)
	movdqu	%xmm12,0xc0(%rcx)
	movdqu	%xmm13,0xd0(%rcx)
	movdqu	%xmm14,0xe0(%rcx)
	movdqu	%xmm15,0xf0(%rcx)
	pushq	%rcx
	.seh_pushreg %rcx
	call	stabilize_sig_stack		# returns tls in r11
	popq	%rcx
	movq	_cygtls.stackptr(%r11),%r10
	movq	%r10,(%rcx)
	decl	_cygtls.stacklock(%r11)
	xorl	%eax,%eax
	ret
	.seh_endproc

	.globl	siglongjmp
	.seh_proc siglongjmp
siglongjmp:
	pushq	%rcx
	.seh_pushreg %rcx
	.seh_endprologue
	movl	%edx, %r12d
	movl	0x100(%rcx),%r8d		# savemask
	testl	%r8d,%r8d			# savemask != 0?
	je	1f				# no, jmp to longjmp
	xorq	%r8,%r8				# NULL
	leaq    0x108(%rcx),%rdx		# &sigjmp_buf.sigmask
	xorl	%ecx,%ecx			# SIG_SETMASK
	subq	$0x20,%rsp
	call	pthread_sigmask
	addq	$0x20,%rsp
	jmp	1f
	.seh_endproc

	.globl  longjmp
	.seh_proc longjmp
longjmp:
	pushq	%rcx
	.seh_pushreg %rcx
	.seh_endprologue
	movl	%edx,%r12d			# save return value
1:
	call	stabilize_sig_stack		# returns tls in r11
	popq	%rcx
	movl	%r12d,%eax			# restore return value
	movq	(%rcx),%r10			# get old signal stack
	movq	%r10,_cygtls.stackptr(%r11)	# restore
	decl	_cygtls.stacklock(%r11)		# relinquish lock
	xorl	%r10d,%r10d
	movl	%r10d,_cygtls.incyg(%r11)		# we're not in cygwin anymore
	movq	0x8(%rcx),%rbx
	movq	0x10(%rcx),%rsp
	movq	0x18(%rcx),%rbp
	movq	0x20(%rcx),%rsi
	movq	0x28(%rcx),%rdi
	movq	0x30(%rcx),%r12
	movq	0x38(%rcx),%r13
	movq	0x40(%rcx),%r14
	movq	0x48(%rcx),%r15
	movq	0x50(%rcx),%r10
	movq	%r10,(%rsp)
	ldmxcsr	0x58(%rcx)
	fnclex
	fldcw	0x5c(%rcx)
	# jmp_buf is potentially unaligned!
	movdqu	0x60(%rcx),%xmm6
	movdqu	0x70(%rcx),%xmm7
	movdqu	0x80(%rcx),%xmm8
	movdqu	0x90(%rcx),%xmm9
	movdqu	0xa0(%rcx),%xmm10
	movdqu	0xb0(%rcx),%xmm11
	movdqu	0xc0(%rcx),%xmm12
	movdqu	0xd0(%rcx),%xmm13
	movdqu	0xe0(%rcx),%xmm14
	movdqu	0xf0(%rcx),%xmm15
	testl	%eax,%eax
	jne	0f
	incl	%eax
0:	ret
	.seh_endproc
	.extern	_Exit
	.global	_sigfe__Exit
	.seh_proc _sigfe__Exit
_sigfe__Exit:
	leaq	_Exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__chk_fail
	.global	_sigfe___chk_fail
	.seh_proc _sigfe___chk_fail
_sigfe___chk_fail:
	leaq	__chk_fail(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__cxa_finalize
	.global	_sigfe___cxa_finalize
	.seh_proc _sigfe___cxa_finalize
_sigfe___cxa_finalize:
	leaq	__cxa_finalize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__dn_comp
	.global	_sigfe___dn_comp
	.seh_proc _sigfe___dn_comp
_sigfe___dn_comp:
	leaq	__dn_comp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__dn_expand
	.global	_sigfe___dn_expand
	.seh_proc _sigfe___dn_expand
_sigfe___dn_expand:
	leaq	__dn_expand(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__dn_skipname
	.global	_sigfe___dn_skipname
	.seh_proc _sigfe___dn_skipname
_sigfe___dn_skipname:
	leaq	__dn_skipname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__eprintf
	.global	_sigfe___eprintf
	.seh_proc _sigfe___eprintf
_sigfe___eprintf:
	leaq	__eprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__fpurge
	.global	_sigfe___fpurge
	.seh_proc _sigfe___fpurge
_sigfe___fpurge:
	leaq	__fpurge(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__fsetlocking
	.global	_sigfe___fsetlocking
	.seh_proc _sigfe___fsetlocking
_sigfe___fsetlocking:
	leaq	__fsetlocking(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__getdelim
	.global	_sigfe___getdelim
	.seh_proc _sigfe___getdelim
_sigfe___getdelim:
	leaq	__getdelim(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__getline
	.global	_sigfe___getline
	.seh_proc _sigfe___getline
_sigfe___getline:
	leaq	__getline(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__gets_chk
	.global	_sigfe___gets_chk
	.seh_proc _sigfe___gets_chk
_sigfe___gets_chk:
	leaq	__gets_chk(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__opendir_with_d_ino
	.global	_sigfe___opendir_with_d_ino
	.seh_proc _sigfe___opendir_with_d_ino
_sigfe___opendir_with_d_ino:
	leaq	__opendir_with_d_ino(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_close
	.global	_sigfe___res_close
	.seh_proc _sigfe___res_close
_sigfe___res_close:
	leaq	__res_close(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_init
	.global	_sigfe___res_init
	.seh_proc _sigfe___res_init
_sigfe___res_init:
	leaq	__res_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_mkquery
	.global	_sigfe___res_mkquery
	.seh_proc _sigfe___res_mkquery
_sigfe___res_mkquery:
	leaq	__res_mkquery(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_nclose
	.global	_sigfe___res_nclose
	.seh_proc _sigfe___res_nclose
_sigfe___res_nclose:
	leaq	__res_nclose(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_ninit
	.global	_sigfe___res_ninit
	.seh_proc _sigfe___res_ninit
_sigfe___res_ninit:
	leaq	__res_ninit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_nmkquery
	.global	_sigfe___res_nmkquery
	.seh_proc _sigfe___res_nmkquery
_sigfe___res_nmkquery:
	leaq	__res_nmkquery(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_nquery
	.global	_sigfe___res_nquery
	.seh_proc _sigfe___res_nquery
_sigfe___res_nquery:
	leaq	__res_nquery(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_nquerydomain
	.global	_sigfe___res_nquerydomain
	.seh_proc _sigfe___res_nquerydomain
_sigfe___res_nquerydomain:
	leaq	__res_nquerydomain(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_nsearch
	.global	_sigfe___res_nsearch
	.seh_proc _sigfe___res_nsearch
_sigfe___res_nsearch:
	leaq	__res_nsearch(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_nsend
	.global	_sigfe___res_nsend
	.seh_proc _sigfe___res_nsend
_sigfe___res_nsend:
	leaq	__res_nsend(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_query
	.global	_sigfe___res_query
	.seh_proc _sigfe___res_query
_sigfe___res_query:
	leaq	__res_query(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_querydomain
	.global	_sigfe___res_querydomain
	.seh_proc _sigfe___res_querydomain
_sigfe___res_querydomain:
	leaq	__res_querydomain(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_search
	.global	_sigfe___res_search
	.seh_proc _sigfe___res_search
_sigfe___res_search:
	leaq	__res_search(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_send
	.global	_sigfe___res_send
	.seh_proc _sigfe___res_send
_sigfe___res_send:
	leaq	__res_send(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__res_state
	.global	_sigfe___res_state
	.seh_proc _sigfe___res_state
_sigfe___res_state:
	leaq	__res_state(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__sched_getaffinity_sys
	.global	_sigfe___sched_getaffinity_sys
	.seh_proc _sigfe___sched_getaffinity_sys
_sigfe___sched_getaffinity_sys:
	leaq	__sched_getaffinity_sys(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__snprintf_chk
	.global	_sigfe___snprintf_chk
	.seh_proc _sigfe___snprintf_chk
_sigfe___snprintf_chk:
	leaq	__snprintf_chk(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__sprintf_chk
	.global	_sigfe___sprintf_chk
	.seh_proc _sigfe___sprintf_chk
_sigfe___sprintf_chk:
	leaq	__sprintf_chk(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__srget
	.global	_sigfe___srget
	.seh_proc _sigfe___srget
_sigfe___srget:
	leaq	__srget(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__srget_r
	.global	_sigfe___srget_r
	.seh_proc _sigfe___srget_r
_sigfe___srget_r:
	leaq	__srget_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__stack_chk_fail
	.global	_sigfe___stack_chk_fail
	.seh_proc _sigfe___stack_chk_fail
_sigfe___stack_chk_fail:
	leaq	__stack_chk_fail(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__swbuf
	.global	_sigfe___swbuf
	.seh_proc _sigfe___swbuf
_sigfe___swbuf:
	leaq	__swbuf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__swbuf_r
	.global	_sigfe___swbuf_r
	.seh_proc _sigfe___swbuf_r
_sigfe___swbuf_r:
	leaq	__swbuf_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__vsnprintf_chk
	.global	_sigfe___vsnprintf_chk
	.seh_proc _sigfe___vsnprintf_chk
_sigfe___vsnprintf_chk:
	leaq	__vsnprintf_chk(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__vsprintf_chk
	.global	_sigfe___vsprintf_chk
	.seh_proc _sigfe___vsprintf_chk
_sigfe___vsprintf_chk:
	leaq	__vsprintf_chk(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__xdrrec_getrec
	.global	_sigfe___xdrrec_getrec
	.seh_proc _sigfe___xdrrec_getrec
_sigfe___xdrrec_getrec:
	leaq	__xdrrec_getrec(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__xdrrec_setnonblock
	.global	_sigfe___xdrrec_setnonblock
	.seh_proc _sigfe___xdrrec_setnonblock
_sigfe___xdrrec_setnonblock:
	leaq	__xdrrec_setnonblock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__xpg_sigpause
	.global	_sigfe___xpg_sigpause
	.seh_proc _sigfe___xpg_sigpause
_sigfe___xpg_sigpause:
	leaq	__xpg_sigpause(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	__xpg_strerror_r
	.global	_sigfe___xpg_strerror_r
	.seh_proc _sigfe___xpg_strerror_r
_sigfe___xpg_strerror_r:
	leaq	__xpg_strerror_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	_exit
	.global	_sigfe__exit
	.seh_proc _sigfe__exit
_sigfe__exit:
	leaq	_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	_fscanf_r
	.global	_sigfe__fscanf_r
	.seh_proc _sigfe__fscanf_r
_sigfe__fscanf_r:
	leaq	_fscanf_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	_get_osfhandle
	.global	_sigfe__get_osfhandle
	.seh_proc _sigfe__get_osfhandle
_sigfe__get_osfhandle:
	leaq	_get_osfhandle(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	_pipe
	.global	_sigfe__pipe
	.seh_proc _sigfe__pipe
_sigfe__pipe:
	leaq	_pipe(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	_pthread_cleanup_pop
	.global	_sigfe__pthread_cleanup_pop
	.seh_proc _sigfe__pthread_cleanup_pop
_sigfe__pthread_cleanup_pop:
	leaq	_pthread_cleanup_pop(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	_pthread_cleanup_push
	.global	_sigfe__pthread_cleanup_push
	.seh_proc _sigfe__pthread_cleanup_push
_sigfe__pthread_cleanup_push:
	leaq	_pthread_cleanup_push(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	accept4
	.global	_sigfe_accept4
	.seh_proc _sigfe_accept4
_sigfe_accept4:
	leaq	accept4(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	access
	.global	_sigfe_access
	.seh_proc _sigfe_access
_sigfe_access:
	leaq	access(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl
	.global	_sigfe_acl
	.seh_proc _sigfe_acl
_sigfe_acl:
	leaq	acl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_calc_mask
	.global	_sigfe_acl_calc_mask
	.seh_proc _sigfe_acl_calc_mask
_sigfe_acl_calc_mask:
	leaq	acl_calc_mask(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_cmp
	.global	_sigfe_acl_cmp
	.seh_proc _sigfe_acl_cmp
_sigfe_acl_cmp:
	leaq	acl_cmp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_create_entry
	.global	_sigfe_acl_create_entry
	.seh_proc _sigfe_acl_create_entry
_sigfe_acl_create_entry:
	leaq	acl_create_entry(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_delete_def_file
	.global	_sigfe_acl_delete_def_file
	.seh_proc _sigfe_acl_delete_def_file
_sigfe_acl_delete_def_file:
	leaq	acl_delete_def_file(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_dup
	.global	_sigfe_acl_dup
	.seh_proc _sigfe_acl_dup
_sigfe_acl_dup:
	leaq	acl_dup(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_equiv_mode
	.global	_sigfe_acl_equiv_mode
	.seh_proc _sigfe_acl_equiv_mode
_sigfe_acl_equiv_mode:
	leaq	acl_equiv_mode(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_extended_fd
	.global	_sigfe_acl_extended_fd
	.seh_proc _sigfe_acl_extended_fd
_sigfe_acl_extended_fd:
	leaq	acl_extended_fd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_extended_file
	.global	_sigfe_acl_extended_file
	.seh_proc _sigfe_acl_extended_file
_sigfe_acl_extended_file:
	leaq	acl_extended_file(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_extended_file_nofollow
	.global	_sigfe_acl_extended_file_nofollow
	.seh_proc _sigfe_acl_extended_file_nofollow
_sigfe_acl_extended_file_nofollow:
	leaq	acl_extended_file_nofollow(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_free
	.global	_sigfe_acl_free
	.seh_proc _sigfe_acl_free
_sigfe_acl_free:
	leaq	acl_free(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_from_text
	.global	_sigfe_acl_from_text
	.seh_proc _sigfe_acl_from_text
_sigfe_acl_from_text:
	leaq	acl_from_text(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_get_fd
	.global	_sigfe_acl_get_fd
	.seh_proc _sigfe_acl_get_fd
_sigfe_acl_get_fd:
	leaq	acl_get_fd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_get_file
	.global	_sigfe_acl_get_file
	.seh_proc _sigfe_acl_get_file
_sigfe_acl_get_file:
	leaq	acl_get_file(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_get_qualifier
	.global	_sigfe_acl_get_qualifier
	.seh_proc _sigfe_acl_get_qualifier
_sigfe_acl_get_qualifier:
	leaq	acl_get_qualifier(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_init
	.global	_sigfe_acl_init
	.seh_proc _sigfe_acl_init
_sigfe_acl_init:
	leaq	acl_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_set_fd
	.global	_sigfe_acl_set_fd
	.seh_proc _sigfe_acl_set_fd
_sigfe_acl_set_fd:
	leaq	acl_set_fd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_set_file
	.global	_sigfe_acl_set_file
	.seh_proc _sigfe_acl_set_file
_sigfe_acl_set_file:
	leaq	acl_set_file(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_to_any_text
	.global	_sigfe_acl_to_any_text
	.seh_proc _sigfe_acl_to_any_text
_sigfe_acl_to_any_text:
	leaq	acl_to_any_text(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acl_to_text
	.global	_sigfe_acl_to_text
	.seh_proc _sigfe_acl_to_text
_sigfe_acl_to_text:
	leaq	acl_to_text(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aclfrommode
	.global	_sigfe_aclfrommode
	.seh_proc _sigfe_aclfrommode
_sigfe_aclfrommode:
	leaq	aclfrommode(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aclfrompbits
	.global	_sigfe_aclfrompbits
	.seh_proc _sigfe_aclfrompbits
_sigfe_aclfrompbits:
	leaq	aclfrompbits(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aclfromtext
	.global	_sigfe_aclfromtext
	.seh_proc _sigfe_aclfromtext
_sigfe_aclfromtext:
	leaq	aclfromtext(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aclsort
	.global	_sigfe_aclsort
	.seh_proc _sigfe_aclsort
_sigfe_aclsort:
	leaq	aclsort(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acltomode
	.global	_sigfe_acltomode
	.seh_proc _sigfe_acltomode
_sigfe_acltomode:
	leaq	acltomode(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acltopbits
	.global	_sigfe_acltopbits
	.seh_proc _sigfe_acltopbits
_sigfe_acltopbits:
	leaq	acltopbits(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	acltotext
	.global	_sigfe_acltotext
	.seh_proc _sigfe_acltotext
_sigfe_acltotext:
	leaq	acltotext(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aio_cancel
	.global	_sigfe_aio_cancel
	.seh_proc _sigfe_aio_cancel
_sigfe_aio_cancel:
	leaq	aio_cancel(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aio_fsync
	.global	_sigfe_aio_fsync
	.seh_proc _sigfe_aio_fsync
_sigfe_aio_fsync:
	leaq	aio_fsync(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aio_read
	.global	_sigfe_aio_read
	.seh_proc _sigfe_aio_read
_sigfe_aio_read:
	leaq	aio_read(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aio_suspend
	.global	_sigfe_aio_suspend
	.seh_proc _sigfe_aio_suspend
_sigfe_aio_suspend:
	leaq	aio_suspend(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aio_write
	.global	_sigfe_aio_write
	.seh_proc _sigfe_aio_write
_sigfe_aio_write:
	leaq	aio_write(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	alarm
	.global	_sigfe_alarm
	.seh_proc _sigfe_alarm
_sigfe_alarm:
	leaq	alarm(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	aligned_alloc
	.global	_sigfe_aligned_alloc
	.seh_proc _sigfe_aligned_alloc
_sigfe_aligned_alloc:
	leaq	aligned_alloc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_add
	.global	_sigfe_argz_add
	.seh_proc _sigfe_argz_add
_sigfe_argz_add:
	leaq	argz_add(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_add_sep
	.global	_sigfe_argz_add_sep
	.seh_proc _sigfe_argz_add_sep
_sigfe_argz_add_sep:
	leaq	argz_add_sep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_append
	.global	_sigfe_argz_append
	.seh_proc _sigfe_argz_append
_sigfe_argz_append:
	leaq	argz_append(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_create
	.global	_sigfe_argz_create
	.seh_proc _sigfe_argz_create
_sigfe_argz_create:
	leaq	argz_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_create_sep
	.global	_sigfe_argz_create_sep
	.seh_proc _sigfe_argz_create_sep
_sigfe_argz_create_sep:
	leaq	argz_create_sep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_delete
	.global	_sigfe_argz_delete
	.seh_proc _sigfe_argz_delete
_sigfe_argz_delete:
	leaq	argz_delete(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_insert
	.global	_sigfe_argz_insert
	.seh_proc _sigfe_argz_insert
_sigfe_argz_insert:
	leaq	argz_insert(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	argz_replace
	.global	_sigfe_argz_replace
	.seh_proc _sigfe_argz_replace
_sigfe_argz_replace:
	leaq	argz_replace(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	asctime
	.global	_sigfe_asctime
	.seh_proc _sigfe_asctime
_sigfe_asctime:
	leaq	asctime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	asctime_r
	.global	_sigfe_asctime_r
	.seh_proc _sigfe_asctime_r
_sigfe_asctime_r:
	leaq	asctime_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	asnprintf
	.global	_sigfe_asnprintf
	.seh_proc _sigfe_asnprintf
_sigfe_asnprintf:
	leaq	asnprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	asprintf
	.global	_sigfe_asprintf
	.seh_proc _sigfe_asprintf
_sigfe_asprintf:
	leaq	asprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	at_quick_exit
	.global	_sigfe_at_quick_exit
	.seh_proc _sigfe_at_quick_exit
_sigfe_at_quick_exit:
	leaq	at_quick_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	atof
	.global	_sigfe_atof
	.seh_proc _sigfe_atof
_sigfe_atof:
	leaq	atof(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	atoff
	.global	_sigfe_atoff
	.seh_proc _sigfe_atoff
_sigfe_atoff:
	leaq	atoff(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	call_once
	.global	_sigfe_call_once
	.seh_proc _sigfe_call_once
_sigfe_call_once:
	leaq	call_once(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	calloc
	.global	_sigfe_calloc
	.seh_proc _sigfe_calloc
_sigfe_calloc:
	leaq	calloc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	canonicalize_file_name
	.global	_sigfe_canonicalize_file_name
	.seh_proc _sigfe_canonicalize_file_name
_sigfe_canonicalize_file_name:
	leaq	canonicalize_file_name(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	catclose
	.global	_sigfe_catclose
	.seh_proc _sigfe_catclose
_sigfe_catclose:
	leaq	catclose(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	catgets
	.global	_sigfe_catgets
	.seh_proc _sigfe_catgets
_sigfe_catgets:
	leaq	catgets(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	catopen
	.global	_sigfe_catopen
	.seh_proc _sigfe_catopen
_sigfe_catopen:
	leaq	catopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cfsetispeed
	.global	_sigfe_cfsetispeed
	.seh_proc _sigfe_cfsetispeed
_sigfe_cfsetispeed:
	leaq	cfsetispeed(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cfsetospeed
	.global	_sigfe_cfsetospeed
	.seh_proc _sigfe_cfsetospeed
_sigfe_cfsetospeed:
	leaq	cfsetospeed(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cfsetspeed
	.global	_sigfe_cfsetspeed
	.seh_proc _sigfe_cfsetspeed
_sigfe_cfsetspeed:
	leaq	cfsetspeed(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	chdir
	.global	_sigfe_chdir
	.seh_proc _sigfe_chdir
_sigfe_chdir:
	leaq	chdir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	chmod
	.global	_sigfe_chmod
	.seh_proc _sigfe_chmod
_sigfe_chmod:
	leaq	chmod(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	chown
	.global	_sigfe_chown
	.seh_proc _sigfe_chown
_sigfe_chown:
	leaq	chown(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	chroot
	.global	_sigfe_chroot
	.seh_proc _sigfe_chroot
_sigfe_chroot:
	leaq	chroot(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clearenv
	.global	_sigfe_clearenv
	.seh_proc _sigfe_clearenv
_sigfe_clearenv:
	leaq	clearenv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clearerr
	.global	_sigfe_clearerr
	.seh_proc _sigfe_clearerr
_sigfe_clearerr:
	leaq	clearerr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clearerr_unlocked
	.global	_sigfe_clearerr_unlocked
	.seh_proc _sigfe_clearerr_unlocked
_sigfe_clearerr_unlocked:
	leaq	clearerr_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock
	.global	_sigfe_clock
	.seh_proc _sigfe_clock
_sigfe_clock:
	leaq	clock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock_getcpuclockid
	.global	_sigfe_clock_getcpuclockid
	.seh_proc _sigfe_clock_getcpuclockid
_sigfe_clock_getcpuclockid:
	leaq	clock_getcpuclockid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock_getres
	.global	_sigfe_clock_getres
	.seh_proc _sigfe_clock_getres
_sigfe_clock_getres:
	leaq	clock_getres(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock_gettime
	.global	_sigfe_clock_gettime
	.seh_proc _sigfe_clock_gettime
_sigfe_clock_gettime:
	leaq	clock_gettime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock_nanosleep
	.global	_sigfe_clock_nanosleep
	.seh_proc _sigfe_clock_nanosleep
_sigfe_clock_nanosleep:
	leaq	clock_nanosleep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock_setres
	.global	_sigfe_clock_setres
	.seh_proc _sigfe_clock_setres
_sigfe_clock_setres:
	leaq	clock_setres(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	clock_settime
	.global	_sigfe_clock_settime
	.seh_proc _sigfe_clock_settime
_sigfe_clock_settime:
	leaq	clock_settime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	close
	.global	_sigfe_close
	.seh_proc _sigfe_close
_sigfe_close:
	leaq	close(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	closedir
	.global	_sigfe_closedir
	.seh_proc _sigfe_closedir
_sigfe_closedir:
	leaq	closedir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	closelog
	.global	_sigfe_closelog
	.seh_proc _sigfe_closelog
_sigfe_closelog:
	leaq	closelog(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cnd_broadcast
	.global	_sigfe_cnd_broadcast
	.seh_proc _sigfe_cnd_broadcast
_sigfe_cnd_broadcast:
	leaq	cnd_broadcast(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cnd_destroy
	.global	_sigfe_cnd_destroy
	.seh_proc _sigfe_cnd_destroy
_sigfe_cnd_destroy:
	leaq	cnd_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cnd_init
	.global	_sigfe_cnd_init
	.seh_proc _sigfe_cnd_init
_sigfe_cnd_init:
	leaq	cnd_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cnd_signal
	.global	_sigfe_cnd_signal
	.seh_proc _sigfe_cnd_signal
_sigfe_cnd_signal:
	leaq	cnd_signal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cnd_timedwait
	.global	_sigfe_cnd_timedwait
	.seh_proc _sigfe_cnd_timedwait
_sigfe_cnd_timedwait:
	leaq	cnd_timedwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cnd_wait
	.global	_sigfe_cnd_wait
	.seh_proc _sigfe_cnd_wait
_sigfe_cnd_wait:
	leaq	cnd_wait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	creat
	.global	_sigfe_creat
	.seh_proc _sigfe_creat
_sigfe_creat:
	leaq	creat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ctermid
	.global	_sigfe_ctermid
	.seh_proc _sigfe_ctermid
_sigfe_ctermid:
	leaq	ctermid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ctime
	.global	_sigfe_ctime
	.seh_proc _sigfe_ctime
_sigfe_ctime:
	leaq	ctime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ctime_r
	.global	_sigfe_ctime_r
	.seh_proc _sigfe_ctime_r
_sigfe_ctime_r:
	leaq	ctime_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cwait
	.global	_sigfe_cwait
	.seh_proc _sigfe_cwait
_sigfe_cwait:
	leaq	cwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin__cxa_atexit
	.global	_sigfe_cygwin__cxa_atexit
	.seh_proc _sigfe_cygwin__cxa_atexit
_sigfe_cygwin__cxa_atexit:
	leaq	cygwin__cxa_atexit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_accept
	.global	_sigfe_cygwin_accept
	.seh_proc _sigfe_cygwin_accept
_sigfe_cygwin_accept:
	leaq	cygwin_accept(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_atexit
	.global	_sigfe_cygwin_atexit
	.seh_proc _sigfe_cygwin_atexit
_sigfe_cygwin_atexit:
	leaq	cygwin_atexit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_attach_handle_to_fd
	.global	_sigfe_cygwin_attach_handle_to_fd
	.seh_proc _sigfe_cygwin_attach_handle_to_fd
_sigfe_cygwin_attach_handle_to_fd:
	leaq	cygwin_attach_handle_to_fd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_bind
	.global	_sigfe_cygwin_bind
	.seh_proc _sigfe_cygwin_bind
_sigfe_cygwin_bind:
	leaq	cygwin_bind(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_bindresvport
	.global	_sigfe_cygwin_bindresvport
	.seh_proc _sigfe_cygwin_bindresvport
_sigfe_cygwin_bindresvport:
	leaq	cygwin_bindresvport(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_bindresvport_sa
	.global	_sigfe_cygwin_bindresvport_sa
	.seh_proc _sigfe_cygwin_bindresvport_sa
_sigfe_cygwin_bindresvport_sa:
	leaq	cygwin_bindresvport_sa(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_connect
	.global	_sigfe_cygwin_connect
	.seh_proc _sigfe_cygwin_connect
_sigfe_cygwin_connect:
	leaq	cygwin_connect(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_conv_path
	.global	_sigfe_cygwin_conv_path
	.seh_proc _sigfe_cygwin_conv_path
_sigfe_cygwin_conv_path:
	leaq	cygwin_conv_path(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_conv_path_list
	.global	_sigfe_cygwin_conv_path_list
	.seh_proc _sigfe_cygwin_conv_path_list
_sigfe_cygwin_conv_path_list:
	leaq	cygwin_conv_path_list(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_create_path
	.global	_sigfe_cygwin_create_path
	.seh_proc _sigfe_cygwin_create_path
_sigfe_cygwin_create_path:
	leaq	cygwin_create_path(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_detach_dll
	.global	_sigfe_maybe_cygwin_detach_dll
	.seh_proc _sigfe_maybe_cygwin_detach_dll
_sigfe_maybe_cygwin_detach_dll:
	leaq	cygwin_detach_dll(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe_maybe
	.seh_endproc

	.extern	cygwin_endprotoent
	.global	_sigfe_cygwin_endprotoent
	.seh_proc _sigfe_cygwin_endprotoent
_sigfe_cygwin_endprotoent:
	leaq	cygwin_endprotoent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_endservent
	.global	_sigfe_cygwin_endservent
	.seh_proc _sigfe_cygwin_endservent
_sigfe_cygwin_endservent:
	leaq	cygwin_endservent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_exit
	.global	_sigfe_cygwin_exit
	.seh_proc _sigfe_cygwin_exit
_sigfe_cygwin_exit:
	leaq	cygwin_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_freeaddrinfo
	.global	_sigfe_cygwin_freeaddrinfo
	.seh_proc _sigfe_cygwin_freeaddrinfo
_sigfe_cygwin_freeaddrinfo:
	leaq	cygwin_freeaddrinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getaddrinfo
	.global	_sigfe_cygwin_getaddrinfo
	.seh_proc _sigfe_cygwin_getaddrinfo
_sigfe_cygwin_getaddrinfo:
	leaq	cygwin_getaddrinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_gethostbyaddr
	.global	_sigfe_cygwin_gethostbyaddr
	.seh_proc _sigfe_cygwin_gethostbyaddr
_sigfe_cygwin_gethostbyaddr:
	leaq	cygwin_gethostbyaddr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_gethostbyname
	.global	_sigfe_cygwin_gethostbyname
	.seh_proc _sigfe_cygwin_gethostbyname
_sigfe_cygwin_gethostbyname:
	leaq	cygwin_gethostbyname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_gethostname
	.global	_sigfe_cygwin_gethostname
	.seh_proc _sigfe_cygwin_gethostname
_sigfe_cygwin_gethostname:
	leaq	cygwin_gethostname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getnameinfo
	.global	_sigfe_cygwin_getnameinfo
	.seh_proc _sigfe_cygwin_getnameinfo
_sigfe_cygwin_getnameinfo:
	leaq	cygwin_getnameinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getpeername
	.global	_sigfe_cygwin_getpeername
	.seh_proc _sigfe_cygwin_getpeername
_sigfe_cygwin_getpeername:
	leaq	cygwin_getpeername(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getprotobyname
	.global	_sigfe_cygwin_getprotobyname
	.seh_proc _sigfe_cygwin_getprotobyname
_sigfe_cygwin_getprotobyname:
	leaq	cygwin_getprotobyname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getprotobynumber
	.global	_sigfe_cygwin_getprotobynumber
	.seh_proc _sigfe_cygwin_getprotobynumber
_sigfe_cygwin_getprotobynumber:
	leaq	cygwin_getprotobynumber(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getprotoent
	.global	_sigfe_cygwin_getprotoent
	.seh_proc _sigfe_cygwin_getprotoent
_sigfe_cygwin_getprotoent:
	leaq	cygwin_getprotoent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getservbyname
	.global	_sigfe_cygwin_getservbyname
	.seh_proc _sigfe_cygwin_getservbyname
_sigfe_cygwin_getservbyname:
	leaq	cygwin_getservbyname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getservbyport
	.global	_sigfe_cygwin_getservbyport
	.seh_proc _sigfe_cygwin_getservbyport
_sigfe_cygwin_getservbyport:
	leaq	cygwin_getservbyport(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getservent
	.global	_sigfe_cygwin_getservent
	.seh_proc _sigfe_cygwin_getservent
_sigfe_cygwin_getservent:
	leaq	cygwin_getservent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getsockname
	.global	_sigfe_cygwin_getsockname
	.seh_proc _sigfe_cygwin_getsockname
_sigfe_cygwin_getsockname:
	leaq	cygwin_getsockname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_getsockopt
	.global	_sigfe_cygwin_getsockopt
	.seh_proc _sigfe_cygwin_getsockopt
_sigfe_cygwin_getsockopt:
	leaq	cygwin_getsockopt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_herror
	.global	_sigfe_cygwin_herror
	.seh_proc _sigfe_cygwin_herror
_sigfe_cygwin_herror:
	leaq	cygwin_herror(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_if_indextoname
	.global	_sigfe_cygwin_if_indextoname
	.seh_proc _sigfe_cygwin_if_indextoname
_sigfe_cygwin_if_indextoname:
	leaq	cygwin_if_indextoname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_if_nametoindex
	.global	_sigfe_cygwin_if_nametoindex
	.seh_proc _sigfe_cygwin_if_nametoindex
_sigfe_cygwin_if_nametoindex:
	leaq	cygwin_if_nametoindex(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_inet_addr
	.global	_sigfe_cygwin_inet_addr
	.seh_proc _sigfe_cygwin_inet_addr
_sigfe_cygwin_inet_addr:
	leaq	cygwin_inet_addr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_inet_aton
	.global	_sigfe_cygwin_inet_aton
	.seh_proc _sigfe_cygwin_inet_aton
_sigfe_cygwin_inet_aton:
	leaq	cygwin_inet_aton(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_inet_network
	.global	_sigfe_cygwin_inet_network
	.seh_proc _sigfe_cygwin_inet_network
_sigfe_cygwin_inet_network:
	leaq	cygwin_inet_network(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_inet_ntoa
	.global	_sigfe_cygwin_inet_ntoa
	.seh_proc _sigfe_cygwin_inet_ntoa
_sigfe_cygwin_inet_ntoa:
	leaq	cygwin_inet_ntoa(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_inet_ntop
	.global	_sigfe_cygwin_inet_ntop
	.seh_proc _sigfe_cygwin_inet_ntop
_sigfe_cygwin_inet_ntop:
	leaq	cygwin_inet_ntop(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_inet_pton
	.global	_sigfe_cygwin_inet_pton
	.seh_proc _sigfe_cygwin_inet_pton
_sigfe_cygwin_inet_pton:
	leaq	cygwin_inet_pton(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_listen
	.global	_sigfe_cygwin_listen
	.seh_proc _sigfe_cygwin_listen
_sigfe_cygwin_listen:
	leaq	cygwin_listen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_logon_user
	.global	_sigfe_cygwin_logon_user
	.seh_proc _sigfe_cygwin_logon_user
_sigfe_cygwin_logon_user:
	leaq	cygwin_logon_user(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_rcmd
	.global	_sigfe_cygwin_rcmd
	.seh_proc _sigfe_cygwin_rcmd
_sigfe_cygwin_rcmd:
	leaq	cygwin_rcmd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_rcmd_af
	.global	_sigfe_cygwin_rcmd_af
	.seh_proc _sigfe_cygwin_rcmd_af
_sigfe_cygwin_rcmd_af:
	leaq	cygwin_rcmd_af(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_recv
	.global	_sigfe_cygwin_recv
	.seh_proc _sigfe_cygwin_recv
_sigfe_cygwin_recv:
	leaq	cygwin_recv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_recvfrom
	.global	_sigfe_cygwin_recvfrom
	.seh_proc _sigfe_cygwin_recvfrom
_sigfe_cygwin_recvfrom:
	leaq	cygwin_recvfrom(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_recvmsg
	.global	_sigfe_cygwin_recvmsg
	.seh_proc _sigfe_cygwin_recvmsg
_sigfe_cygwin_recvmsg:
	leaq	cygwin_recvmsg(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_rexec
	.global	_sigfe_cygwin_rexec
	.seh_proc _sigfe_cygwin_rexec
_sigfe_cygwin_rexec:
	leaq	cygwin_rexec(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_rresvport
	.global	_sigfe_cygwin_rresvport
	.seh_proc _sigfe_cygwin_rresvport
_sigfe_cygwin_rresvport:
	leaq	cygwin_rresvport(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_rresvport_af
	.global	_sigfe_cygwin_rresvport_af
	.seh_proc _sigfe_cygwin_rresvport_af
_sigfe_cygwin_rresvport_af:
	leaq	cygwin_rresvport_af(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_select
	.global	_sigfe_cygwin_select
	.seh_proc _sigfe_cygwin_select
_sigfe_cygwin_select:
	leaq	cygwin_select(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_send
	.global	_sigfe_cygwin_send
	.seh_proc _sigfe_cygwin_send
_sigfe_cygwin_send:
	leaq	cygwin_send(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_sendmsg
	.global	_sigfe_cygwin_sendmsg
	.seh_proc _sigfe_cygwin_sendmsg
_sigfe_cygwin_sendmsg:
	leaq	cygwin_sendmsg(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_sendto
	.global	_sigfe_cygwin_sendto
	.seh_proc _sigfe_cygwin_sendto
_sigfe_cygwin_sendto:
	leaq	cygwin_sendto(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_set_impersonation_token
	.global	_sigfe_cygwin_set_impersonation_token
	.seh_proc _sigfe_cygwin_set_impersonation_token
_sigfe_cygwin_set_impersonation_token:
	leaq	cygwin_set_impersonation_token(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_setmode
	.global	_sigfe_cygwin_setmode
	.seh_proc _sigfe_cygwin_setmode
_sigfe_cygwin_setmode:
	leaq	cygwin_setmode(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_setprotoent
	.global	_sigfe_cygwin_setprotoent
	.seh_proc _sigfe_cygwin_setprotoent
_sigfe_cygwin_setprotoent:
	leaq	cygwin_setprotoent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_setservent
	.global	_sigfe_cygwin_setservent
	.seh_proc _sigfe_cygwin_setservent
_sigfe_cygwin_setservent:
	leaq	cygwin_setservent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_setsockopt
	.global	_sigfe_cygwin_setsockopt
	.seh_proc _sigfe_cygwin_setsockopt
_sigfe_cygwin_setsockopt:
	leaq	cygwin_setsockopt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_shutdown
	.global	_sigfe_cygwin_shutdown
	.seh_proc _sigfe_cygwin_shutdown
_sigfe_cygwin_shutdown:
	leaq	cygwin_shutdown(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_socket
	.global	_sigfe_cygwin_socket
	.seh_proc _sigfe_cygwin_socket
_sigfe_cygwin_socket:
	leaq	cygwin_socket(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_stackdump
	.global	_sigfe_cygwin_stackdump
	.seh_proc _sigfe_cygwin_stackdump
_sigfe_cygwin_stackdump:
	leaq	cygwin_stackdump(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_umount
	.global	_sigfe_cygwin_umount
	.seh_proc _sigfe_cygwin_umount
_sigfe_cygwin_umount:
	leaq	cygwin_umount(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	cygwin_winpid_to_pid
	.global	_sigfe_cygwin_winpid_to_pid
	.seh_proc _sigfe_cygwin_winpid_to_pid
_sigfe_cygwin_winpid_to_pid:
	leaq	cygwin_winpid_to_pid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	daemon
	.global	_sigfe_daemon
	.seh_proc _sigfe_daemon
_sigfe_daemon:
	leaq	daemon(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_clearerr
	.global	_sigfe_dbm_clearerr
	.seh_proc _sigfe_dbm_clearerr
_sigfe_dbm_clearerr:
	leaq	dbm_clearerr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_close
	.global	_sigfe_dbm_close
	.seh_proc _sigfe_dbm_close
_sigfe_dbm_close:
	leaq	dbm_close(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_delete
	.global	_sigfe_dbm_delete
	.seh_proc _sigfe_dbm_delete
_sigfe_dbm_delete:
	leaq	dbm_delete(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_dirfno
	.global	_sigfe_dbm_dirfno
	.seh_proc _sigfe_dbm_dirfno
_sigfe_dbm_dirfno:
	leaq	dbm_dirfno(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_error
	.global	_sigfe_dbm_error
	.seh_proc _sigfe_dbm_error
_sigfe_dbm_error:
	leaq	dbm_error(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_fetch
	.global	_sigfe_dbm_fetch
	.seh_proc _sigfe_dbm_fetch
_sigfe_dbm_fetch:
	leaq	dbm_fetch(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_firstkey
	.global	_sigfe_dbm_firstkey
	.seh_proc _sigfe_dbm_firstkey
_sigfe_dbm_firstkey:
	leaq	dbm_firstkey(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_nextkey
	.global	_sigfe_dbm_nextkey
	.seh_proc _sigfe_dbm_nextkey
_sigfe_dbm_nextkey:
	leaq	dbm_nextkey(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_open
	.global	_sigfe_dbm_open
	.seh_proc _sigfe_dbm_open
_sigfe_dbm_open:
	leaq	dbm_open(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dbm_store
	.global	_sigfe_dbm_store
	.seh_proc _sigfe_dbm_store
_sigfe_dbm_store:
	leaq	dbm_store(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dirfd
	.global	_sigfe_dirfd
	.seh_proc _sigfe_dirfd
_sigfe_dirfd:
	leaq	dirfd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dladdr
	.global	_sigfe_dladdr
	.seh_proc _sigfe_dladdr
_sigfe_dladdr:
	leaq	dladdr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dlclose
	.global	_sigfe_dlclose
	.seh_proc _sigfe_dlclose
_sigfe_dlclose:
	leaq	dlclose(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dlopen
	.global	_sigfe_dlopen
	.seh_proc _sigfe_dlopen
_sigfe_dlopen:
	leaq	dlopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dlsym
	.global	_sigfe_dlsym
	.seh_proc _sigfe_dlsym
_sigfe_dlsym:
	leaq	dlsym(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dprintf
	.global	_sigfe_dprintf
	.seh_proc _sigfe_dprintf
_sigfe_dprintf:
	leaq	dprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dup
	.global	_sigfe_dup
	.seh_proc _sigfe_dup
_sigfe_dup:
	leaq	dup(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dup2
	.global	_sigfe_dup2
	.seh_proc _sigfe_dup2
_sigfe_dup2:
	leaq	dup2(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	dup3
	.global	_sigfe_dup3
	.seh_proc _sigfe_dup3
_sigfe_dup3:
	leaq	dup3(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	duplocale
	.global	_sigfe_duplocale
	.seh_proc _sigfe_duplocale
_sigfe_duplocale:
	leaq	duplocale(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ecvt
	.global	_sigfe_ecvt
	.seh_proc _sigfe_ecvt
_sigfe_ecvt:
	leaq	ecvt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ecvtbuf
	.global	_sigfe_ecvtbuf
	.seh_proc _sigfe_ecvtbuf
_sigfe_ecvtbuf:
	leaq	ecvtbuf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ecvtf
	.global	_sigfe_ecvtf
	.seh_proc _sigfe_ecvtf
_sigfe_ecvtf:
	leaq	ecvtf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	endusershell
	.global	_sigfe_endusershell
	.seh_proc _sigfe_endusershell
_sigfe_endusershell:
	leaq	endusershell(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	endutent
	.global	_sigfe_endutent
	.seh_proc _sigfe_endutent
_sigfe_endutent:
	leaq	endutent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	endutxent
	.global	_sigfe_endutxent
	.seh_proc _sigfe_endutxent
_sigfe_endutxent:
	leaq	endutxent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	envz_add
	.global	_sigfe_envz_add
	.seh_proc _sigfe_envz_add
_sigfe_envz_add:
	leaq	envz_add(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	envz_merge
	.global	_sigfe_envz_merge
	.seh_proc _sigfe_envz_merge
_sigfe_envz_merge:
	leaq	envz_merge(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	envz_remove
	.global	_sigfe_envz_remove
	.seh_proc _sigfe_envz_remove
_sigfe_envz_remove:
	leaq	envz_remove(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	envz_strip
	.global	_sigfe_envz_strip
	.seh_proc _sigfe_envz_strip
_sigfe_envz_strip:
	leaq	envz_strip(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	err
	.global	_sigfe_err
	.seh_proc _sigfe_err
_sigfe_err:
	leaq	err(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	error
	.global	_sigfe_error
	.seh_proc _sigfe_error
_sigfe_error:
	leaq	error(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	error_at_line
	.global	_sigfe_error_at_line
	.seh_proc _sigfe_error_at_line
_sigfe_error_at_line:
	leaq	error_at_line(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	errx
	.global	_sigfe_errx
	.seh_proc _sigfe_errx
_sigfe_errx:
	leaq	errx(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	euidaccess
	.global	_sigfe_euidaccess
	.seh_proc _sigfe_euidaccess
_sigfe_euidaccess:
	leaq	euidaccess(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execl
	.global	_sigfe_execl
	.seh_proc _sigfe_execl
_sigfe_execl:
	leaq	execl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execle
	.global	_sigfe_execle
	.seh_proc _sigfe_execle
_sigfe_execle:
	leaq	execle(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execlp
	.global	_sigfe_execlp
	.seh_proc _sigfe_execlp
_sigfe_execlp:
	leaq	execlp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execv
	.global	_sigfe_execv
	.seh_proc _sigfe_execv
_sigfe_execv:
	leaq	execv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execve
	.global	_sigfe_execve
	.seh_proc _sigfe_execve
_sigfe_execve:
	leaq	execve(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execvp
	.global	_sigfe_execvp
	.seh_proc _sigfe_execvp
_sigfe_execvp:
	leaq	execvp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	execvpe
	.global	_sigfe_execvpe
	.seh_proc _sigfe_execvpe
_sigfe_execvpe:
	leaq	execvpe(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	faccessat
	.global	_sigfe_faccessat
	.seh_proc _sigfe_faccessat
_sigfe_faccessat:
	leaq	faccessat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	facl
	.global	_sigfe_facl
	.seh_proc _sigfe_facl
_sigfe_facl:
	leaq	facl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fchdir
	.global	_sigfe_fchdir
	.seh_proc _sigfe_fchdir
_sigfe_fchdir:
	leaq	fchdir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fchmod
	.global	_sigfe_fchmod
	.seh_proc _sigfe_fchmod
_sigfe_fchmod:
	leaq	fchmod(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fchmodat
	.global	_sigfe_fchmodat
	.seh_proc _sigfe_fchmodat
_sigfe_fchmodat:
	leaq	fchmodat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fchown
	.global	_sigfe_fchown
	.seh_proc _sigfe_fchown
_sigfe_fchown:
	leaq	fchown(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fchownat
	.global	_sigfe_fchownat
	.seh_proc _sigfe_fchownat
_sigfe_fchownat:
	leaq	fchownat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fclose
	.global	_sigfe_fclose
	.seh_proc _sigfe_fclose
_sigfe_fclose:
	leaq	fclose(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fcloseall
	.global	_sigfe_fcloseall
	.seh_proc _sigfe_fcloseall
_sigfe_fcloseall:
	leaq	fcloseall(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fcntl
	.global	_sigfe_fcntl
	.seh_proc _sigfe_fcntl
_sigfe_fcntl:
	leaq	fcntl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fcvt
	.global	_sigfe_fcvt
	.seh_proc _sigfe_fcvt
_sigfe_fcvt:
	leaq	fcvt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fcvtbuf
	.global	_sigfe_fcvtbuf
	.seh_proc _sigfe_fcvtbuf
_sigfe_fcvtbuf:
	leaq	fcvtbuf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fcvtf
	.global	_sigfe_fcvtf
	.seh_proc _sigfe_fcvtf
_sigfe_fcvtf:
	leaq	fcvtf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fdatasync
	.global	_sigfe_fdatasync
	.seh_proc _sigfe_fdatasync
_sigfe_fdatasync:
	leaq	fdatasync(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fdopen
	.global	_sigfe_fdopen
	.seh_proc _sigfe_fdopen
_sigfe_fdopen:
	leaq	fdopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fdopendir
	.global	_sigfe_fdopendir
	.seh_proc _sigfe_fdopendir
_sigfe_fdopendir:
	leaq	fdopendir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	feenableexcept
	.global	_sigfe_feenableexcept
	.seh_proc _sigfe_feenableexcept
_sigfe_feenableexcept:
	leaq	feenableexcept(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	feholdexcept
	.global	_sigfe_feholdexcept
	.seh_proc _sigfe_feholdexcept
_sigfe_feholdexcept:
	leaq	feholdexcept(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	feof
	.global	_sigfe_feof
	.seh_proc _sigfe_feof
_sigfe_feof:
	leaq	feof(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	feof_unlocked
	.global	_sigfe_feof_unlocked
	.seh_proc _sigfe_feof_unlocked
_sigfe_feof_unlocked:
	leaq	feof_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	feraiseexcept
	.global	_sigfe_feraiseexcept
	.seh_proc _sigfe_feraiseexcept
_sigfe_feraiseexcept:
	leaq	feraiseexcept(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ferror
	.global	_sigfe_ferror
	.seh_proc _sigfe_ferror
_sigfe_ferror:
	leaq	ferror(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ferror_unlocked
	.global	_sigfe_ferror_unlocked
	.seh_proc _sigfe_ferror_unlocked
_sigfe_ferror_unlocked:
	leaq	ferror_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fesetenv
	.global	_sigfe_fesetenv
	.seh_proc _sigfe_fesetenv
_sigfe_fesetenv:
	leaq	fesetenv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fesetexceptflag
	.global	_sigfe_fesetexceptflag
	.seh_proc _sigfe_fesetexceptflag
_sigfe_fesetexceptflag:
	leaq	fesetexceptflag(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	feupdateenv
	.global	_sigfe_feupdateenv
	.seh_proc _sigfe_feupdateenv
_sigfe_feupdateenv:
	leaq	feupdateenv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fexecve
	.global	_sigfe_fexecve
	.seh_proc _sigfe_fexecve
_sigfe_fexecve:
	leaq	fexecve(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fflush
	.global	_sigfe_fflush
	.seh_proc _sigfe_fflush
_sigfe_fflush:
	leaq	fflush(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fflush_unlocked
	.global	_sigfe_fflush_unlocked
	.seh_proc _sigfe_fflush_unlocked
_sigfe_fflush_unlocked:
	leaq	fflush_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetc
	.global	_sigfe_fgetc
	.seh_proc _sigfe_fgetc
_sigfe_fgetc:
	leaq	fgetc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetc_unlocked
	.global	_sigfe_fgetc_unlocked
	.seh_proc _sigfe_fgetc_unlocked
_sigfe_fgetc_unlocked:
	leaq	fgetc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetpos
	.global	_sigfe_fgetpos
	.seh_proc _sigfe_fgetpos
_sigfe_fgetpos:
	leaq	fgetpos(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgets
	.global	_sigfe_fgets
	.seh_proc _sigfe_fgets
_sigfe_fgets:
	leaq	fgets(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgets_unlocked
	.global	_sigfe_fgets_unlocked
	.seh_proc _sigfe_fgets_unlocked
_sigfe_fgets_unlocked:
	leaq	fgets_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetwc
	.global	_sigfe_fgetwc
	.seh_proc _sigfe_fgetwc
_sigfe_fgetwc:
	leaq	fgetwc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetwc_unlocked
	.global	_sigfe_fgetwc_unlocked
	.seh_proc _sigfe_fgetwc_unlocked
_sigfe_fgetwc_unlocked:
	leaq	fgetwc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetws
	.global	_sigfe_fgetws
	.seh_proc _sigfe_fgetws
_sigfe_fgetws:
	leaq	fgetws(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetws_unlocked
	.global	_sigfe_fgetws_unlocked
	.seh_proc _sigfe_fgetws_unlocked
_sigfe_fgetws_unlocked:
	leaq	fgetws_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fgetxattr
	.global	_sigfe_fgetxattr
	.seh_proc _sigfe_fgetxattr
_sigfe_fgetxattr:
	leaq	fgetxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fileno
	.global	_sigfe_fileno
	.seh_proc _sigfe_fileno
_sigfe_fileno:
	leaq	fileno(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fileno_unlocked
	.global	_sigfe_fileno_unlocked
	.seh_proc _sigfe_fileno_unlocked
_sigfe_fileno_unlocked:
	leaq	fileno_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fiprintf
	.global	_sigfe_fiprintf
	.seh_proc _sigfe_fiprintf
_sigfe_fiprintf:
	leaq	fiprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	flistxattr
	.global	_sigfe_flistxattr
	.seh_proc _sigfe_flistxattr
_sigfe_flistxattr:
	leaq	flistxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	flock
	.global	_sigfe_flock
	.seh_proc _sigfe_flock
_sigfe_flock:
	leaq	flock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	flockfile
	.global	_sigfe_flockfile
	.seh_proc _sigfe_flockfile
_sigfe_flockfile:
	leaq	flockfile(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fmemopen
	.global	_sigfe_fmemopen
	.seh_proc _sigfe_fmemopen
_sigfe_fmemopen:
	leaq	fmemopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fopen
	.global	_sigfe_fopen
	.seh_proc _sigfe_fopen
_sigfe_fopen:
	leaq	fopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fopencookie
	.global	_sigfe_fopencookie
	.seh_proc _sigfe_fopencookie
_sigfe_fopencookie:
	leaq	fopencookie(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fork
	.global	_sigfe_fork
	.seh_proc _sigfe_fork
_sigfe_fork:
	leaq	fork(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	forkpty
	.global	_sigfe_forkpty
	.seh_proc _sigfe_forkpty
_sigfe_forkpty:
	leaq	forkpty(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fpathconf
	.global	_sigfe_fpathconf
	.seh_proc _sigfe_fpathconf
_sigfe_fpathconf:
	leaq	fpathconf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fprintf
	.global	_sigfe_fprintf
	.seh_proc _sigfe_fprintf
_sigfe_fprintf:
	leaq	fprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fpurge
	.global	_sigfe_fpurge
	.seh_proc _sigfe_fpurge
_sigfe_fpurge:
	leaq	fpurge(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputc
	.global	_sigfe_fputc
	.seh_proc _sigfe_fputc
_sigfe_fputc:
	leaq	fputc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputc_unlocked
	.global	_sigfe_fputc_unlocked
	.seh_proc _sigfe_fputc_unlocked
_sigfe_fputc_unlocked:
	leaq	fputc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputs
	.global	_sigfe_fputs
	.seh_proc _sigfe_fputs
_sigfe_fputs:
	leaq	fputs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputs_unlocked
	.global	_sigfe_fputs_unlocked
	.seh_proc _sigfe_fputs_unlocked
_sigfe_fputs_unlocked:
	leaq	fputs_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputwc
	.global	_sigfe_fputwc
	.seh_proc _sigfe_fputwc
_sigfe_fputwc:
	leaq	fputwc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputwc_unlocked
	.global	_sigfe_fputwc_unlocked
	.seh_proc _sigfe_fputwc_unlocked
_sigfe_fputwc_unlocked:
	leaq	fputwc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputws
	.global	_sigfe_fputws
	.seh_proc _sigfe_fputws
_sigfe_fputws:
	leaq	fputws(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fputws_unlocked
	.global	_sigfe_fputws_unlocked
	.seh_proc _sigfe_fputws_unlocked
_sigfe_fputws_unlocked:
	leaq	fputws_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fread
	.global	_sigfe_fread
	.seh_proc _sigfe_fread
_sigfe_fread:
	leaq	fread(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fread_unlocked
	.global	_sigfe_fread_unlocked
	.seh_proc _sigfe_fread_unlocked
_sigfe_fread_unlocked:
	leaq	fread_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	free
	.global	_sigfe_free
	.seh_proc _sigfe_free
_sigfe_free:
	leaq	free(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	freeifaddrs
	.global	_sigfe_freeifaddrs
	.seh_proc _sigfe_freeifaddrs
_sigfe_freeifaddrs:
	leaq	freeifaddrs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	freelocale
	.global	_sigfe_freelocale
	.seh_proc _sigfe_freelocale
_sigfe_freelocale:
	leaq	freelocale(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fremovexattr
	.global	_sigfe_fremovexattr
	.seh_proc _sigfe_fremovexattr
_sigfe_fremovexattr:
	leaq	fremovexattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	freopen
	.global	_sigfe_freopen
	.seh_proc _sigfe_freopen
_sigfe_freopen:
	leaq	freopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fscanf
	.global	_sigfe_fscanf
	.seh_proc _sigfe_fscanf
_sigfe_fscanf:
	leaq	fscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fseek
	.global	_sigfe_fseek
	.seh_proc _sigfe_fseek
_sigfe_fseek:
	leaq	fseek(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fseeko
	.global	_sigfe_fseeko
	.seh_proc _sigfe_fseeko
_sigfe_fseeko:
	leaq	fseeko(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fsetpos
	.global	_sigfe_fsetpos
	.seh_proc _sigfe_fsetpos
_sigfe_fsetpos:
	leaq	fsetpos(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fsetxattr
	.global	_sigfe_fsetxattr
	.seh_proc _sigfe_fsetxattr
_sigfe_fsetxattr:
	leaq	fsetxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fstat
	.global	_sigfe_fstat
	.seh_proc _sigfe_fstat
_sigfe_fstat:
	leaq	fstat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fstatat
	.global	_sigfe_fstatat
	.seh_proc _sigfe_fstatat
_sigfe_fstatat:
	leaq	fstatat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fstatfs
	.global	_sigfe_fstatfs
	.seh_proc _sigfe_fstatfs
_sigfe_fstatfs:
	leaq	fstatfs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fstatvfs
	.global	_sigfe_fstatvfs
	.seh_proc _sigfe_fstatvfs
_sigfe_fstatvfs:
	leaq	fstatvfs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fsync
	.global	_sigfe_fsync
	.seh_proc _sigfe_fsync
_sigfe_fsync:
	leaq	fsync(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftell
	.global	_sigfe_ftell
	.seh_proc _sigfe_ftell
_sigfe_ftell:
	leaq	ftell(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftello
	.global	_sigfe_ftello
	.seh_proc _sigfe_ftello
_sigfe_ftello:
	leaq	ftello(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftime
	.global	_sigfe_ftime
	.seh_proc _sigfe_ftime
_sigfe_ftime:
	leaq	ftime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftok
	.global	_sigfe_ftok
	.seh_proc _sigfe_ftok
_sigfe_ftok:
	leaq	ftok(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftruncate
	.global	_sigfe_ftruncate
	.seh_proc _sigfe_ftruncate
_sigfe_ftruncate:
	leaq	ftruncate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftrylockfile
	.global	_sigfe_ftrylockfile
	.seh_proc _sigfe_ftrylockfile
_sigfe_ftrylockfile:
	leaq	ftrylockfile(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fts_children
	.global	_sigfe_fts_children
	.seh_proc _sigfe_fts_children
_sigfe_fts_children:
	leaq	fts_children(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fts_close
	.global	_sigfe_fts_close
	.seh_proc _sigfe_fts_close
_sigfe_fts_close:
	leaq	fts_close(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fts_open
	.global	_sigfe_fts_open
	.seh_proc _sigfe_fts_open
_sigfe_fts_open:
	leaq	fts_open(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fts_read
	.global	_sigfe_fts_read
	.seh_proc _sigfe_fts_read
_sigfe_fts_read:
	leaq	fts_read(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ftw
	.global	_sigfe_ftw
	.seh_proc _sigfe_ftw
_sigfe_ftw:
	leaq	ftw(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	funlockfile
	.global	_sigfe_funlockfile
	.seh_proc _sigfe_funlockfile
_sigfe_funlockfile:
	leaq	funlockfile(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	funopen
	.global	_sigfe_funopen
	.seh_proc _sigfe_funopen
_sigfe_funopen:
	leaq	funopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	futimens
	.global	_sigfe_futimens
	.seh_proc _sigfe_futimens
_sigfe_futimens:
	leaq	futimens(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	futimes
	.global	_sigfe_futimes
	.seh_proc _sigfe_futimes
_sigfe_futimes:
	leaq	futimes(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	futimesat
	.global	_sigfe_futimesat
	.seh_proc _sigfe_futimesat
_sigfe_futimesat:
	leaq	futimesat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fwide
	.global	_sigfe_fwide
	.seh_proc _sigfe_fwide
_sigfe_fwide:
	leaq	fwide(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fwprintf
	.global	_sigfe_fwprintf
	.seh_proc _sigfe_fwprintf
_sigfe_fwprintf:
	leaq	fwprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fwrite
	.global	_sigfe_fwrite
	.seh_proc _sigfe_fwrite
_sigfe_fwrite:
	leaq	fwrite(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fwrite_unlocked
	.global	_sigfe_fwrite_unlocked
	.seh_proc _sigfe_fwrite_unlocked
_sigfe_fwrite_unlocked:
	leaq	fwrite_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	fwscanf
	.global	_sigfe_fwscanf
	.seh_proc _sigfe_fwscanf
_sigfe_fwscanf:
	leaq	fwscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gcvt
	.global	_sigfe_gcvt
	.seh_proc _sigfe_gcvt
_sigfe_gcvt:
	leaq	gcvt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gcvtf
	.global	_sigfe_gcvtf
	.seh_proc _sigfe_gcvtf
_sigfe_gcvtf:
	leaq	gcvtf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	get_avphys_pages
	.global	_sigfe_get_avphys_pages
	.seh_proc _sigfe_get_avphys_pages
_sigfe_get_avphys_pages:
	leaq	get_avphys_pages(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	get_current_dir_name
	.global	_sigfe_get_current_dir_name
	.seh_proc _sigfe_get_current_dir_name
_sigfe_get_current_dir_name:
	leaq	get_current_dir_name(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	get_nprocs
	.global	_sigfe_get_nprocs
	.seh_proc _sigfe_get_nprocs
_sigfe_get_nprocs:
	leaq	get_nprocs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	get_nprocs_conf
	.global	_sigfe_get_nprocs_conf
	.seh_proc _sigfe_get_nprocs_conf
_sigfe_get_nprocs_conf:
	leaq	get_nprocs_conf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	get_phys_pages
	.global	_sigfe_get_phys_pages
	.seh_proc _sigfe_get_phys_pages
_sigfe_get_phys_pages:
	leaq	get_phys_pages(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getc
	.global	_sigfe_getc
	.seh_proc _sigfe_getc
_sigfe_getc:
	leaq	getc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getc_unlocked
	.global	_sigfe_getc_unlocked
	.seh_proc _sigfe_getc_unlocked
_sigfe_getc_unlocked:
	leaq	getc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getchar
	.global	_sigfe_getchar
	.seh_proc _sigfe_getchar
_sigfe_getchar:
	leaq	getchar(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getchar_unlocked
	.global	_sigfe_getchar_unlocked
	.seh_proc _sigfe_getchar_unlocked
_sigfe_getchar_unlocked:
	leaq	getchar_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getcwd
	.global	_sigfe_getcwd
	.seh_proc _sigfe_getcwd
_sigfe_getcwd:
	leaq	getcwd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getdomainname
	.global	_sigfe_getdomainname
	.seh_proc _sigfe_getdomainname
_sigfe_getdomainname:
	leaq	getdomainname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getentropy
	.global	_sigfe_getentropy
	.seh_proc _sigfe_getentropy
_sigfe_getentropy:
	leaq	getentropy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgrent
	.global	_sigfe_getgrent
	.seh_proc _sigfe_getgrent
_sigfe_getgrent:
	leaq	getgrent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgrgid
	.global	_sigfe_getgrgid
	.seh_proc _sigfe_getgrgid
_sigfe_getgrgid:
	leaq	getgrgid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgrgid_r
	.global	_sigfe_getgrgid_r
	.seh_proc _sigfe_getgrgid_r
_sigfe_getgrgid_r:
	leaq	getgrgid_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgrnam
	.global	_sigfe_getgrnam
	.seh_proc _sigfe_getgrnam
_sigfe_getgrnam:
	leaq	getgrnam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgrnam_r
	.global	_sigfe_getgrnam_r
	.seh_proc _sigfe_getgrnam_r
_sigfe_getgrnam_r:
	leaq	getgrnam_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgrouplist
	.global	_sigfe_getgrouplist
	.seh_proc _sigfe_getgrouplist
_sigfe_getgrouplist:
	leaq	getgrouplist(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getgroups
	.global	_sigfe_getgroups
	.seh_proc _sigfe_getgroups
_sigfe_getgroups:
	leaq	getgroups(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gethostbyname2
	.global	_sigfe_gethostbyname2
	.seh_proc _sigfe_gethostbyname2
_sigfe_gethostbyname2:
	leaq	gethostbyname2(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gethostid
	.global	_sigfe_gethostid
	.seh_proc _sigfe_gethostid
_sigfe_gethostid:
	leaq	gethostid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getifaddrs
	.global	_sigfe_getifaddrs
	.seh_proc _sigfe_getifaddrs
_sigfe_getifaddrs:
	leaq	getifaddrs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getitimer
	.global	_sigfe_getitimer
	.seh_proc _sigfe_getitimer
_sigfe_getitimer:
	leaq	getitimer(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getloadavg
	.global	_sigfe_getloadavg
	.seh_proc _sigfe_getloadavg
_sigfe_getloadavg:
	leaq	getloadavg(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getmntent
	.global	_sigfe_getmntent
	.seh_proc _sigfe_getmntent
_sigfe_getmntent:
	leaq	getmntent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getmntent_r
	.global	_sigfe_getmntent_r
	.seh_proc _sigfe_getmntent_r
_sigfe_getmntent_r:
	leaq	getmntent_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getmode
	.global	_sigfe_getmode
	.seh_proc _sigfe_getmode
_sigfe_getmode:
	leaq	getmode(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getopt
	.global	_sigfe_getopt
	.seh_proc _sigfe_getopt
_sigfe_getopt:
	leaq	getopt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getopt_long
	.global	_sigfe_getopt_long
	.seh_proc _sigfe_getopt_long
_sigfe_getopt_long:
	leaq	getopt_long(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getopt_long_only
	.global	_sigfe_getopt_long_only
	.seh_proc _sigfe_getopt_long_only
_sigfe_getopt_long_only:
	leaq	getopt_long_only(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpagesize
	.global	_sigfe_getpagesize
	.seh_proc _sigfe_getpagesize
_sigfe_getpagesize:
	leaq	getpagesize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpass
	.global	_sigfe_getpass
	.seh_proc _sigfe_getpass
_sigfe_getpass:
	leaq	getpass(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpeereid
	.global	_sigfe_getpeereid
	.seh_proc _sigfe_getpeereid
_sigfe_getpeereid:
	leaq	getpeereid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpgid
	.global	_sigfe_getpgid
	.seh_proc _sigfe_getpgid
_sigfe_getpgid:
	leaq	getpgid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpgrp
	.global	_sigfe_getpgrp
	.seh_proc _sigfe_getpgrp
_sigfe_getpgrp:
	leaq	getpgrp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpriority
	.global	_sigfe_getpriority
	.seh_proc _sigfe_getpriority
_sigfe_getpriority:
	leaq	getpriority(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpt
	.global	_sigfe_getpt
	.seh_proc _sigfe_getpt
_sigfe_getpt:
	leaq	getpt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpwent
	.global	_sigfe_getpwent
	.seh_proc _sigfe_getpwent
_sigfe_getpwent:
	leaq	getpwent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpwnam
	.global	_sigfe_getpwnam
	.seh_proc _sigfe_getpwnam
_sigfe_getpwnam:
	leaq	getpwnam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpwnam_r
	.global	_sigfe_getpwnam_r
	.seh_proc _sigfe_getpwnam_r
_sigfe_getpwnam_r:
	leaq	getpwnam_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpwuid
	.global	_sigfe_getpwuid
	.seh_proc _sigfe_getpwuid
_sigfe_getpwuid:
	leaq	getpwuid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getpwuid_r
	.global	_sigfe_getpwuid_r
	.seh_proc _sigfe_getpwuid_r
_sigfe_getpwuid_r:
	leaq	getpwuid_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getrandom
	.global	_sigfe_getrandom
	.seh_proc _sigfe_getrandom
_sigfe_getrandom:
	leaq	getrandom(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getrlimit
	.global	_sigfe_getrlimit
	.seh_proc _sigfe_getrlimit
_sigfe_getrlimit:
	leaq	getrlimit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getrusage
	.global	_sigfe_getrusage
	.seh_proc _sigfe_getrusage
_sigfe_getrusage:
	leaq	getrusage(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gets
	.global	_sigfe_gets
	.seh_proc _sigfe_gets
_sigfe_gets:
	leaq	gets(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getsid
	.global	_sigfe_getsid
	.seh_proc _sigfe_getsid
_sigfe_getsid:
	leaq	getsid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gettimeofday
	.global	_sigfe_gettimeofday
	.seh_proc _sigfe_gettimeofday
_sigfe_gettimeofday:
	leaq	gettimeofday(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getusershell
	.global	_sigfe_getusershell
	.seh_proc _sigfe_getusershell
_sigfe_getusershell:
	leaq	getusershell(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getutent
	.global	_sigfe_getutent
	.seh_proc _sigfe_getutent
_sigfe_getutent:
	leaq	getutent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getutid
	.global	_sigfe_getutid
	.seh_proc _sigfe_getutid
_sigfe_getutid:
	leaq	getutid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getutline
	.global	_sigfe_getutline
	.seh_proc _sigfe_getutline
_sigfe_getutline:
	leaq	getutline(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getutxent
	.global	_sigfe_getutxent
	.seh_proc _sigfe_getutxent
_sigfe_getutxent:
	leaq	getutxent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getutxid
	.global	_sigfe_getutxid
	.seh_proc _sigfe_getutxid
_sigfe_getutxid:
	leaq	getutxid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getutxline
	.global	_sigfe_getutxline
	.seh_proc _sigfe_getutxline
_sigfe_getutxline:
	leaq	getutxline(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getw
	.global	_sigfe_getw
	.seh_proc _sigfe_getw
_sigfe_getw:
	leaq	getw(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getwc
	.global	_sigfe_getwc
	.seh_proc _sigfe_getwc
_sigfe_getwc:
	leaq	getwc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getwc_unlocked
	.global	_sigfe_getwc_unlocked
	.seh_proc _sigfe_getwc_unlocked
_sigfe_getwc_unlocked:
	leaq	getwc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getwchar
	.global	_sigfe_getwchar
	.seh_proc _sigfe_getwchar
_sigfe_getwchar:
	leaq	getwchar(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getwchar_unlocked
	.global	_sigfe_getwchar_unlocked
	.seh_proc _sigfe_getwchar_unlocked
_sigfe_getwchar_unlocked:
	leaq	getwchar_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getwd
	.global	_sigfe_getwd
	.seh_proc _sigfe_getwd
_sigfe_getwd:
	leaq	getwd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	getxattr
	.global	_sigfe_getxattr
	.seh_proc _sigfe_getxattr
_sigfe_getxattr:
	leaq	getxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	glob
	.global	_sigfe_glob
	.seh_proc _sigfe_glob
_sigfe_glob:
	leaq	glob(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	glob_pattern_p
	.global	_sigfe_glob_pattern_p
	.seh_proc _sigfe_glob_pattern_p
_sigfe_glob_pattern_p:
	leaq	glob_pattern_p(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	globfree
	.global	_sigfe_globfree
	.seh_proc _sigfe_globfree
_sigfe_globfree:
	leaq	globfree(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gmtime
	.global	_sigfe_gmtime
	.seh_proc _sigfe_gmtime
_sigfe_gmtime:
	leaq	gmtime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	gmtime_r
	.global	_sigfe_gmtime_r
	.seh_proc _sigfe_gmtime_r
_sigfe_gmtime_r:
	leaq	gmtime_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	hcreate
	.global	_sigfe_hcreate
	.seh_proc _sigfe_hcreate
_sigfe_hcreate:
	leaq	hcreate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	hcreate_r
	.global	_sigfe_hcreate_r
	.seh_proc _sigfe_hcreate_r
_sigfe_hcreate_r:
	leaq	hcreate_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	hdestroy
	.global	_sigfe_hdestroy
	.seh_proc _sigfe_hdestroy
_sigfe_hdestroy:
	leaq	hdestroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	hdestroy_r
	.global	_sigfe_hdestroy_r
	.seh_proc _sigfe_hdestroy_r
_sigfe_hdestroy_r:
	leaq	hdestroy_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	hsearch
	.global	_sigfe_hsearch
	.seh_proc _sigfe_hsearch
_sigfe_hsearch:
	leaq	hsearch(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	hsearch_r
	.global	_sigfe_hsearch_r
	.seh_proc _sigfe_hsearch_r
_sigfe_hsearch_r:
	leaq	hsearch_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	if_freenameindex
	.global	_sigfe_if_freenameindex
	.seh_proc _sigfe_if_freenameindex
_sigfe_if_freenameindex:
	leaq	if_freenameindex(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	if_nameindex
	.global	_sigfe_if_nameindex
	.seh_proc _sigfe_if_nameindex
_sigfe_if_nameindex:
	leaq	if_nameindex(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	initgroups
	.global	_sigfe_initgroups
	.seh_proc _sigfe_initgroups
_sigfe_initgroups:
	leaq	initgroups(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ioctl
	.global	_sigfe_ioctl
	.seh_proc _sigfe_ioctl
_sigfe_ioctl:
	leaq	ioctl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	iprintf
	.global	_sigfe_iprintf
	.seh_proc _sigfe_iprintf
_sigfe_iprintf:
	leaq	iprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	iruserok
	.global	_sigfe_iruserok
	.seh_proc _sigfe_iruserok
_sigfe_iruserok:
	leaq	iruserok(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	iruserok_sa
	.global	_sigfe_iruserok_sa
	.seh_proc _sigfe_iruserok_sa
_sigfe_iruserok_sa:
	leaq	iruserok_sa(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	isatty
	.global	_sigfe_isatty
	.seh_proc _sigfe_isatty
_sigfe_isatty:
	leaq	isatty(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	kill
	.global	_sigfe_kill
	.seh_proc _sigfe_kill
_sigfe_kill:
	leaq	kill(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	killpg
	.global	_sigfe_killpg
	.seh_proc _sigfe_killpg
_sigfe_killpg:
	leaq	killpg(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lchown
	.global	_sigfe_lchown
	.seh_proc _sigfe_lchown
_sigfe_lchown:
	leaq	lchown(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lgetxattr
	.global	_sigfe_lgetxattr
	.seh_proc _sigfe_lgetxattr
_sigfe_lgetxattr:
	leaq	lgetxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	link
	.global	_sigfe_link
	.seh_proc _sigfe_link
_sigfe_link:
	leaq	link(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	linkat
	.global	_sigfe_linkat
	.seh_proc _sigfe_linkat
_sigfe_linkat:
	leaq	linkat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lio_listio
	.global	_sigfe_lio_listio
	.seh_proc _sigfe_lio_listio
_sigfe_lio_listio:
	leaq	lio_listio(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	listxattr
	.global	_sigfe_listxattr
	.seh_proc _sigfe_listxattr
_sigfe_listxattr:
	leaq	listxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	llistxattr
	.global	_sigfe_llistxattr
	.seh_proc _sigfe_llistxattr
_sigfe_llistxattr:
	leaq	llistxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	localtime
	.global	_sigfe_localtime
	.seh_proc _sigfe_localtime
_sigfe_localtime:
	leaq	localtime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	localtime_r
	.global	_sigfe_localtime_r
	.seh_proc _sigfe_localtime_r
_sigfe_localtime_r:
	leaq	localtime_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lockf
	.global	_sigfe_lockf
	.seh_proc _sigfe_lockf
_sigfe_lockf:
	leaq	lockf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	login
	.global	_sigfe_login
	.seh_proc _sigfe_login
_sigfe_login:
	leaq	login(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	login_tty
	.global	_sigfe_login_tty
	.seh_proc _sigfe_login_tty
_sigfe_login_tty:
	leaq	login_tty(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	logout
	.global	_sigfe_logout
	.seh_proc _sigfe_logout
_sigfe_logout:
	leaq	logout(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	logwtmp
	.global	_sigfe_logwtmp
	.seh_proc _sigfe_logwtmp
_sigfe_logwtmp:
	leaq	logwtmp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lremovexattr
	.global	_sigfe_lremovexattr
	.seh_proc _sigfe_lremovexattr
_sigfe_lremovexattr:
	leaq	lremovexattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lseek
	.global	_sigfe_lseek
	.seh_proc _sigfe_lseek
_sigfe_lseek:
	leaq	lseek(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lsetxattr
	.global	_sigfe_lsetxattr
	.seh_proc _sigfe_lsetxattr
_sigfe_lsetxattr:
	leaq	lsetxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lstat
	.global	_sigfe_lstat
	.seh_proc _sigfe_lstat
_sigfe_lstat:
	leaq	lstat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	lutimes
	.global	_sigfe_lutimes
	.seh_proc _sigfe_lutimes
_sigfe_lutimes:
	leaq	lutimes(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mallinfo
	.global	_sigfe_mallinfo
	.seh_proc _sigfe_mallinfo
_sigfe_mallinfo:
	leaq	mallinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	malloc
	.global	_sigfe_malloc
	.seh_proc _sigfe_malloc
_sigfe_malloc:
	leaq	malloc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	malloc_stats
	.global	_sigfe_malloc_stats
	.seh_proc _sigfe_malloc_stats
_sigfe_malloc_stats:
	leaq	malloc_stats(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	malloc_trim
	.global	_sigfe_malloc_trim
	.seh_proc _sigfe_malloc_trim
_sigfe_malloc_trim:
	leaq	malloc_trim(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	malloc_usable_size
	.global	_sigfe_malloc_usable_size
	.seh_proc _sigfe_malloc_usable_size
_sigfe_malloc_usable_size:
	leaq	malloc_usable_size(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mallopt
	.global	_sigfe_mallopt
	.seh_proc _sigfe_mallopt
_sigfe_mallopt:
	leaq	mallopt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	memalign
	.global	_sigfe_memalign
	.seh_proc _sigfe_memalign
_sigfe_memalign:
	leaq	memalign(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkdir
	.global	_sigfe_mkdir
	.seh_proc _sigfe_mkdir
_sigfe_mkdir:
	leaq	mkdir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkdirat
	.global	_sigfe_mkdirat
	.seh_proc _sigfe_mkdirat
_sigfe_mkdirat:
	leaq	mkdirat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkdtemp
	.global	_sigfe_mkdtemp
	.seh_proc _sigfe_mkdtemp
_sigfe_mkdtemp:
	leaq	mkdtemp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkfifo
	.global	_sigfe_mkfifo
	.seh_proc _sigfe_mkfifo
_sigfe_mkfifo:
	leaq	mkfifo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkfifoat
	.global	_sigfe_mkfifoat
	.seh_proc _sigfe_mkfifoat
_sigfe_mkfifoat:
	leaq	mkfifoat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mknod
	.global	_sigfe_mknod
	.seh_proc _sigfe_mknod
_sigfe_mknod:
	leaq	mknod(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mknodat
	.global	_sigfe_mknodat
	.seh_proc _sigfe_mknodat
_sigfe_mknodat:
	leaq	mknodat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkostemp
	.global	_sigfe_mkostemp
	.seh_proc _sigfe_mkostemp
_sigfe_mkostemp:
	leaq	mkostemp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkostemps
	.global	_sigfe_mkostemps
	.seh_proc _sigfe_mkostemps
_sigfe_mkostemps:
	leaq	mkostemps(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkstemp
	.global	_sigfe_mkstemp
	.seh_proc _sigfe_mkstemp
_sigfe_mkstemp:
	leaq	mkstemp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mkstemps
	.global	_sigfe_mkstemps
	.seh_proc _sigfe_mkstemps
_sigfe_mkstemps:
	leaq	mkstemps(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mktemp
	.global	_sigfe_mktemp
	.seh_proc _sigfe_mktemp
_sigfe_mktemp:
	leaq	mktemp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mktime
	.global	_sigfe_mktime
	.seh_proc _sigfe_mktime
_sigfe_mktime:
	leaq	mktime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mlock
	.global	_sigfe_mlock
	.seh_proc _sigfe_mlock
_sigfe_mlock:
	leaq	mlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mmap
	.global	_sigfe_mmap
	.seh_proc _sigfe_mmap
_sigfe_mmap:
	leaq	mmap(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mount
	.global	_sigfe_mount
	.seh_proc _sigfe_mount
_sigfe_mount:
	leaq	mount(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mprotect
	.global	_sigfe_mprotect
	.seh_proc _sigfe_mprotect
_sigfe_mprotect:
	leaq	mprotect(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_close
	.global	_sigfe_mq_close
	.seh_proc _sigfe_mq_close
_sigfe_mq_close:
	leaq	mq_close(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_getattr
	.global	_sigfe_mq_getattr
	.seh_proc _sigfe_mq_getattr
_sigfe_mq_getattr:
	leaq	mq_getattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_notify
	.global	_sigfe_mq_notify
	.seh_proc _sigfe_mq_notify
_sigfe_mq_notify:
	leaq	mq_notify(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_open
	.global	_sigfe_mq_open
	.seh_proc _sigfe_mq_open
_sigfe_mq_open:
	leaq	mq_open(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_receive
	.global	_sigfe_mq_receive
	.seh_proc _sigfe_mq_receive
_sigfe_mq_receive:
	leaq	mq_receive(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_send
	.global	_sigfe_mq_send
	.seh_proc _sigfe_mq_send
_sigfe_mq_send:
	leaq	mq_send(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_setattr
	.global	_sigfe_mq_setattr
	.seh_proc _sigfe_mq_setattr
_sigfe_mq_setattr:
	leaq	mq_setattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_timedreceive
	.global	_sigfe_mq_timedreceive
	.seh_proc _sigfe_mq_timedreceive
_sigfe_mq_timedreceive:
	leaq	mq_timedreceive(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_timedsend
	.global	_sigfe_mq_timedsend
	.seh_proc _sigfe_mq_timedsend
_sigfe_mq_timedsend:
	leaq	mq_timedsend(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mq_unlink
	.global	_sigfe_mq_unlink
	.seh_proc _sigfe_mq_unlink
_sigfe_mq_unlink:
	leaq	mq_unlink(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	msgctl
	.global	_sigfe_msgctl
	.seh_proc _sigfe_msgctl
_sigfe_msgctl:
	leaq	msgctl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	msgget
	.global	_sigfe_msgget
	.seh_proc _sigfe_msgget
_sigfe_msgget:
	leaq	msgget(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	msgrcv
	.global	_sigfe_msgrcv
	.seh_proc _sigfe_msgrcv
_sigfe_msgrcv:
	leaq	msgrcv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	msgsnd
	.global	_sigfe_msgsnd
	.seh_proc _sigfe_msgsnd
_sigfe_msgsnd:
	leaq	msgsnd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	msync
	.global	_sigfe_msync
	.seh_proc _sigfe_msync
_sigfe_msync:
	leaq	msync(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mtx_destroy
	.global	_sigfe_mtx_destroy
	.seh_proc _sigfe_mtx_destroy
_sigfe_mtx_destroy:
	leaq	mtx_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mtx_init
	.global	_sigfe_mtx_init
	.seh_proc _sigfe_mtx_init
_sigfe_mtx_init:
	leaq	mtx_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mtx_lock
	.global	_sigfe_mtx_lock
	.seh_proc _sigfe_mtx_lock
_sigfe_mtx_lock:
	leaq	mtx_lock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mtx_timedlock
	.global	_sigfe_mtx_timedlock
	.seh_proc _sigfe_mtx_timedlock
_sigfe_mtx_timedlock:
	leaq	mtx_timedlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mtx_trylock
	.global	_sigfe_mtx_trylock
	.seh_proc _sigfe_mtx_trylock
_sigfe_mtx_trylock:
	leaq	mtx_trylock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	mtx_unlock
	.global	_sigfe_mtx_unlock
	.seh_proc _sigfe_mtx_unlock
_sigfe_mtx_unlock:
	leaq	mtx_unlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	munlock
	.global	_sigfe_munlock
	.seh_proc _sigfe_munlock
_sigfe_munlock:
	leaq	munlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	munmap
	.global	_sigfe_munmap
	.seh_proc _sigfe_munmap
_sigfe_munmap:
	leaq	munmap(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	nanosleep
	.global	_sigfe_nanosleep
	.seh_proc _sigfe_nanosleep
_sigfe_nanosleep:
	leaq	nanosleep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	newlocale
	.global	_sigfe_newlocale
	.seh_proc _sigfe_newlocale
_sigfe_newlocale:
	leaq	newlocale(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	nftw
	.global	_sigfe_nftw
	.seh_proc _sigfe_nftw
_sigfe_nftw:
	leaq	nftw(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	nice
	.global	_sigfe_nice
	.seh_proc _sigfe_nice
_sigfe_nice:
	leaq	nice(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	nl_langinfo
	.global	_sigfe_nl_langinfo
	.seh_proc _sigfe_nl_langinfo
_sigfe_nl_langinfo:
	leaq	nl_langinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	nl_langinfo_l
	.global	_sigfe_nl_langinfo_l
	.seh_proc _sigfe_nl_langinfo_l
_sigfe_nl_langinfo_l:
	leaq	nl_langinfo_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	on_exit
	.global	_sigfe_on_exit
	.seh_proc _sigfe_on_exit
_sigfe_on_exit:
	leaq	on_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	open
	.global	_sigfe_open
	.seh_proc _sigfe_open
_sigfe_open:
	leaq	open(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	open_memstream
	.global	_sigfe_open_memstream
	.seh_proc _sigfe_open_memstream
_sigfe_open_memstream:
	leaq	open_memstream(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	open_wmemstream
	.global	_sigfe_open_wmemstream
	.seh_proc _sigfe_open_wmemstream
_sigfe_open_wmemstream:
	leaq	open_wmemstream(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	openat
	.global	_sigfe_openat
	.seh_proc _sigfe_openat
_sigfe_openat:
	leaq	openat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	opendir
	.global	_sigfe_opendir
	.seh_proc _sigfe_opendir
_sigfe_opendir:
	leaq	opendir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	openlog
	.global	_sigfe_openlog
	.seh_proc _sigfe_openlog
_sigfe_openlog:
	leaq	openlog(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	openpty
	.global	_sigfe_openpty
	.seh_proc _sigfe_openpty
_sigfe_openpty:
	leaq	openpty(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pathconf
	.global	_sigfe_pathconf
	.seh_proc _sigfe_pathconf
_sigfe_pathconf:
	leaq	pathconf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pause
	.global	_sigfe_pause
	.seh_proc _sigfe_pause
_sigfe_pause:
	leaq	pause(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pclose
	.global	_sigfe_pclose
	.seh_proc _sigfe_pclose
_sigfe_pclose:
	leaq	pclose(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	perror
	.global	_sigfe_perror
	.seh_proc _sigfe_perror
_sigfe_perror:
	leaq	perror(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pipe
	.global	_sigfe_pipe
	.seh_proc _sigfe_pipe
_sigfe_pipe:
	leaq	pipe(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pipe2
	.global	_sigfe_pipe2
	.seh_proc _sigfe_pipe2
_sigfe_pipe2:
	leaq	pipe2(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	poll
	.global	_sigfe_poll
	.seh_proc _sigfe_poll
_sigfe_poll:
	leaq	poll(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	popen
	.global	_sigfe_popen
	.seh_proc _sigfe_popen
_sigfe_popen:
	leaq	popen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_fadvise
	.global	_sigfe_posix_fadvise
	.seh_proc _sigfe_posix_fadvise
_sigfe_posix_fadvise:
	leaq	posix_fadvise(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_fallocate
	.global	_sigfe_posix_fallocate
	.seh_proc _sigfe_posix_fallocate
_sigfe_posix_fallocate:
	leaq	posix_fallocate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_madvise
	.global	_sigfe_posix_madvise
	.seh_proc _sigfe_posix_madvise
_sigfe_posix_madvise:
	leaq	posix_madvise(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_memalign
	.global	_sigfe_posix_memalign
	.seh_proc _sigfe_posix_memalign
_sigfe_posix_memalign:
	leaq	posix_memalign(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_openpt
	.global	_sigfe_posix_openpt
	.seh_proc _sigfe_posix_openpt
_sigfe_posix_openpt:
	leaq	posix_openpt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawn
	.global	_sigfe_posix_spawn
	.seh_proc _sigfe_posix_spawn
_sigfe_posix_spawn:
	leaq	posix_spawn(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawn_file_actions_addclose
	.global	_sigfe_posix_spawn_file_actions_addclose
	.seh_proc _sigfe_posix_spawn_file_actions_addclose
_sigfe_posix_spawn_file_actions_addclose:
	leaq	posix_spawn_file_actions_addclose(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawn_file_actions_adddup2
	.global	_sigfe_posix_spawn_file_actions_adddup2
	.seh_proc _sigfe_posix_spawn_file_actions_adddup2
_sigfe_posix_spawn_file_actions_adddup2:
	leaq	posix_spawn_file_actions_adddup2(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawn_file_actions_addopen
	.global	_sigfe_posix_spawn_file_actions_addopen
	.seh_proc _sigfe_posix_spawn_file_actions_addopen
_sigfe_posix_spawn_file_actions_addopen:
	leaq	posix_spawn_file_actions_addopen(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawn_file_actions_destroy
	.global	_sigfe_posix_spawn_file_actions_destroy
	.seh_proc _sigfe_posix_spawn_file_actions_destroy
_sigfe_posix_spawn_file_actions_destroy:
	leaq	posix_spawn_file_actions_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawn_file_actions_init
	.global	_sigfe_posix_spawn_file_actions_init
	.seh_proc _sigfe_posix_spawn_file_actions_init
_sigfe_posix_spawn_file_actions_init:
	leaq	posix_spawn_file_actions_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawnattr_destroy
	.global	_sigfe_posix_spawnattr_destroy
	.seh_proc _sigfe_posix_spawnattr_destroy
_sigfe_posix_spawnattr_destroy:
	leaq	posix_spawnattr_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawnattr_init
	.global	_sigfe_posix_spawnattr_init
	.seh_proc _sigfe_posix_spawnattr_init
_sigfe_posix_spawnattr_init:
	leaq	posix_spawnattr_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	posix_spawnp
	.global	_sigfe_posix_spawnp
	.seh_proc _sigfe_posix_spawnp
_sigfe_posix_spawnp:
	leaq	posix_spawnp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ppoll
	.global	_sigfe_ppoll
	.seh_proc _sigfe_ppoll
_sigfe_ppoll:
	leaq	ppoll(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pread
	.global	_sigfe_pread
	.seh_proc _sigfe_pread
_sigfe_pread:
	leaq	pread(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	printf
	.global	_sigfe_printf
	.seh_proc _sigfe_printf
_sigfe_printf:
	leaq	printf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pselect
	.global	_sigfe_pselect
	.seh_proc _sigfe_pselect
_sigfe_pselect:
	leaq	pselect(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	psiginfo
	.global	_sigfe_psiginfo
	.seh_proc _sigfe_psiginfo
_sigfe_psiginfo:
	leaq	psiginfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	psignal
	.global	_sigfe_psignal
	.seh_proc _sigfe_psignal
_sigfe_psignal:
	leaq	psignal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_atfork
	.global	_sigfe_pthread_atfork
	.seh_proc _sigfe_pthread_atfork
_sigfe_pthread_atfork:
	leaq	pthread_atfork(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_destroy
	.global	_sigfe_pthread_attr_destroy
	.seh_proc _sigfe_pthread_attr_destroy
_sigfe_pthread_attr_destroy:
	leaq	pthread_attr_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getdetachstate
	.global	_sigfe_pthread_attr_getdetachstate
	.seh_proc _sigfe_pthread_attr_getdetachstate
_sigfe_pthread_attr_getdetachstate:
	leaq	pthread_attr_getdetachstate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getguardsize
	.global	_sigfe_pthread_attr_getguardsize
	.seh_proc _sigfe_pthread_attr_getguardsize
_sigfe_pthread_attr_getguardsize:
	leaq	pthread_attr_getguardsize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getinheritsched
	.global	_sigfe_pthread_attr_getinheritsched
	.seh_proc _sigfe_pthread_attr_getinheritsched
_sigfe_pthread_attr_getinheritsched:
	leaq	pthread_attr_getinheritsched(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getschedparam
	.global	_sigfe_pthread_attr_getschedparam
	.seh_proc _sigfe_pthread_attr_getschedparam
_sigfe_pthread_attr_getschedparam:
	leaq	pthread_attr_getschedparam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getschedpolicy
	.global	_sigfe_pthread_attr_getschedpolicy
	.seh_proc _sigfe_pthread_attr_getschedpolicy
_sigfe_pthread_attr_getschedpolicy:
	leaq	pthread_attr_getschedpolicy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getscope
	.global	_sigfe_pthread_attr_getscope
	.seh_proc _sigfe_pthread_attr_getscope
_sigfe_pthread_attr_getscope:
	leaq	pthread_attr_getscope(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getstack
	.global	_sigfe_pthread_attr_getstack
	.seh_proc _sigfe_pthread_attr_getstack
_sigfe_pthread_attr_getstack:
	leaq	pthread_attr_getstack(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getstackaddr
	.global	_sigfe_pthread_attr_getstackaddr
	.seh_proc _sigfe_pthread_attr_getstackaddr
_sigfe_pthread_attr_getstackaddr:
	leaq	pthread_attr_getstackaddr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_getstacksize
	.global	_sigfe_pthread_attr_getstacksize
	.seh_proc _sigfe_pthread_attr_getstacksize
_sigfe_pthread_attr_getstacksize:
	leaq	pthread_attr_getstacksize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_init
	.global	_sigfe_pthread_attr_init
	.seh_proc _sigfe_pthread_attr_init
_sigfe_pthread_attr_init:
	leaq	pthread_attr_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setdetachstate
	.global	_sigfe_pthread_attr_setdetachstate
	.seh_proc _sigfe_pthread_attr_setdetachstate
_sigfe_pthread_attr_setdetachstate:
	leaq	pthread_attr_setdetachstate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setguardsize
	.global	_sigfe_pthread_attr_setguardsize
	.seh_proc _sigfe_pthread_attr_setguardsize
_sigfe_pthread_attr_setguardsize:
	leaq	pthread_attr_setguardsize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setinheritsched
	.global	_sigfe_pthread_attr_setinheritsched
	.seh_proc _sigfe_pthread_attr_setinheritsched
_sigfe_pthread_attr_setinheritsched:
	leaq	pthread_attr_setinheritsched(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setschedparam
	.global	_sigfe_pthread_attr_setschedparam
	.seh_proc _sigfe_pthread_attr_setschedparam
_sigfe_pthread_attr_setschedparam:
	leaq	pthread_attr_setschedparam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setschedpolicy
	.global	_sigfe_pthread_attr_setschedpolicy
	.seh_proc _sigfe_pthread_attr_setschedpolicy
_sigfe_pthread_attr_setschedpolicy:
	leaq	pthread_attr_setschedpolicy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setscope
	.global	_sigfe_pthread_attr_setscope
	.seh_proc _sigfe_pthread_attr_setscope
_sigfe_pthread_attr_setscope:
	leaq	pthread_attr_setscope(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setstack
	.global	_sigfe_pthread_attr_setstack
	.seh_proc _sigfe_pthread_attr_setstack
_sigfe_pthread_attr_setstack:
	leaq	pthread_attr_setstack(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setstackaddr
	.global	_sigfe_pthread_attr_setstackaddr
	.seh_proc _sigfe_pthread_attr_setstackaddr
_sigfe_pthread_attr_setstackaddr:
	leaq	pthread_attr_setstackaddr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_attr_setstacksize
	.global	_sigfe_pthread_attr_setstacksize
	.seh_proc _sigfe_pthread_attr_setstacksize
_sigfe_pthread_attr_setstacksize:
	leaq	pthread_attr_setstacksize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrier_destroy
	.global	_sigfe_pthread_barrier_destroy
	.seh_proc _sigfe_pthread_barrier_destroy
_sigfe_pthread_barrier_destroy:
	leaq	pthread_barrier_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrier_init
	.global	_sigfe_pthread_barrier_init
	.seh_proc _sigfe_pthread_barrier_init
_sigfe_pthread_barrier_init:
	leaq	pthread_barrier_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrier_wait
	.global	_sigfe_pthread_barrier_wait
	.seh_proc _sigfe_pthread_barrier_wait
_sigfe_pthread_barrier_wait:
	leaq	pthread_barrier_wait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrierattr_destroy
	.global	_sigfe_pthread_barrierattr_destroy
	.seh_proc _sigfe_pthread_barrierattr_destroy
_sigfe_pthread_barrierattr_destroy:
	leaq	pthread_barrierattr_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrierattr_getpshared
	.global	_sigfe_pthread_barrierattr_getpshared
	.seh_proc _sigfe_pthread_barrierattr_getpshared
_sigfe_pthread_barrierattr_getpshared:
	leaq	pthread_barrierattr_getpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrierattr_init
	.global	_sigfe_pthread_barrierattr_init
	.seh_proc _sigfe_pthread_barrierattr_init
_sigfe_pthread_barrierattr_init:
	leaq	pthread_barrierattr_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_barrierattr_setpshared
	.global	_sigfe_pthread_barrierattr_setpshared
	.seh_proc _sigfe_pthread_barrierattr_setpshared
_sigfe_pthread_barrierattr_setpshared:
	leaq	pthread_barrierattr_setpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cancel
	.global	_sigfe_pthread_cancel
	.seh_proc _sigfe_pthread_cancel
_sigfe_pthread_cancel:
	leaq	pthread_cancel(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_broadcast
	.global	_sigfe_pthread_cond_broadcast
	.seh_proc _sigfe_pthread_cond_broadcast
_sigfe_pthread_cond_broadcast:
	leaq	pthread_cond_broadcast(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_clockwait
	.global	_sigfe_pthread_cond_clockwait
	.seh_proc _sigfe_pthread_cond_clockwait
_sigfe_pthread_cond_clockwait:
	leaq	pthread_cond_clockwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_destroy
	.global	_sigfe_pthread_cond_destroy
	.seh_proc _sigfe_pthread_cond_destroy
_sigfe_pthread_cond_destroy:
	leaq	pthread_cond_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_init
	.global	_sigfe_pthread_cond_init
	.seh_proc _sigfe_pthread_cond_init
_sigfe_pthread_cond_init:
	leaq	pthread_cond_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_signal
	.global	_sigfe_pthread_cond_signal
	.seh_proc _sigfe_pthread_cond_signal
_sigfe_pthread_cond_signal:
	leaq	pthread_cond_signal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_timedwait
	.global	_sigfe_pthread_cond_timedwait
	.seh_proc _sigfe_pthread_cond_timedwait
_sigfe_pthread_cond_timedwait:
	leaq	pthread_cond_timedwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_cond_wait
	.global	_sigfe_pthread_cond_wait
	.seh_proc _sigfe_pthread_cond_wait
_sigfe_pthread_cond_wait:
	leaq	pthread_cond_wait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_condattr_destroy
	.global	_sigfe_pthread_condattr_destroy
	.seh_proc _sigfe_pthread_condattr_destroy
_sigfe_pthread_condattr_destroy:
	leaq	pthread_condattr_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_condattr_getclock
	.global	_sigfe_pthread_condattr_getclock
	.seh_proc _sigfe_pthread_condattr_getclock
_sigfe_pthread_condattr_getclock:
	leaq	pthread_condattr_getclock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_condattr_getpshared
	.global	_sigfe_pthread_condattr_getpshared
	.seh_proc _sigfe_pthread_condattr_getpshared
_sigfe_pthread_condattr_getpshared:
	leaq	pthread_condattr_getpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_condattr_init
	.global	_sigfe_pthread_condattr_init
	.seh_proc _sigfe_pthread_condattr_init
_sigfe_pthread_condattr_init:
	leaq	pthread_condattr_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_condattr_setclock
	.global	_sigfe_pthread_condattr_setclock
	.seh_proc _sigfe_pthread_condattr_setclock
_sigfe_pthread_condattr_setclock:
	leaq	pthread_condattr_setclock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_condattr_setpshared
	.global	_sigfe_pthread_condattr_setpshared
	.seh_proc _sigfe_pthread_condattr_setpshared
_sigfe_pthread_condattr_setpshared:
	leaq	pthread_condattr_setpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_continue
	.global	_sigfe_pthread_continue
	.seh_proc _sigfe_pthread_continue
_sigfe_pthread_continue:
	leaq	pthread_continue(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_create
	.global	_sigfe_pthread_create
	.seh_proc _sigfe_pthread_create
_sigfe_pthread_create:
	leaq	pthread_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_detach
	.global	_sigfe_pthread_detach
	.seh_proc _sigfe_pthread_detach
_sigfe_pthread_detach:
	leaq	pthread_detach(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_equal
	.global	_sigfe_pthread_equal
	.seh_proc _sigfe_pthread_equal
_sigfe_pthread_equal:
	leaq	pthread_equal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_exit
	.global	_sigfe_pthread_exit
	.seh_proc _sigfe_pthread_exit
_sigfe_pthread_exit:
	leaq	pthread_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getaffinity_np
	.global	_sigfe_pthread_getaffinity_np
	.seh_proc _sigfe_pthread_getaffinity_np
_sigfe_pthread_getaffinity_np:
	leaq	pthread_getaffinity_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getattr_np
	.global	_sigfe_pthread_getattr_np
	.seh_proc _sigfe_pthread_getattr_np
_sigfe_pthread_getattr_np:
	leaq	pthread_getattr_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getconcurrency
	.global	_sigfe_pthread_getconcurrency
	.seh_proc _sigfe_pthread_getconcurrency
_sigfe_pthread_getconcurrency:
	leaq	pthread_getconcurrency(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getcpuclockid
	.global	_sigfe_pthread_getcpuclockid
	.seh_proc _sigfe_pthread_getcpuclockid
_sigfe_pthread_getcpuclockid:
	leaq	pthread_getcpuclockid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getname_np
	.global	_sigfe_pthread_getname_np
	.seh_proc _sigfe_pthread_getname_np
_sigfe_pthread_getname_np:
	leaq	pthread_getname_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getschedparam
	.global	_sigfe_pthread_getschedparam
	.seh_proc _sigfe_pthread_getschedparam
_sigfe_pthread_getschedparam:
	leaq	pthread_getschedparam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getsequence_np
	.global	_sigfe_pthread_getsequence_np
	.seh_proc _sigfe_pthread_getsequence_np
_sigfe_pthread_getsequence_np:
	leaq	pthread_getsequence_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_getspecific
	.global	_sigfe_pthread_getspecific
	.seh_proc _sigfe_pthread_getspecific
_sigfe_pthread_getspecific:
	leaq	pthread_getspecific(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_join
	.global	_sigfe_pthread_join
	.seh_proc _sigfe_pthread_join
_sigfe_pthread_join:
	leaq	pthread_join(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_key_create
	.global	_sigfe_pthread_key_create
	.seh_proc _sigfe_pthread_key_create
_sigfe_pthread_key_create:
	leaq	pthread_key_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_key_delete
	.global	_sigfe_pthread_key_delete
	.seh_proc _sigfe_pthread_key_delete
_sigfe_pthread_key_delete:
	leaq	pthread_key_delete(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_kill
	.global	_sigfe_pthread_kill
	.seh_proc _sigfe_pthread_kill
_sigfe_pthread_kill:
	leaq	pthread_kill(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_clocklock
	.global	_sigfe_pthread_mutex_clocklock
	.seh_proc _sigfe_pthread_mutex_clocklock
_sigfe_pthread_mutex_clocklock:
	leaq	pthread_mutex_clocklock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_destroy
	.global	_sigfe_pthread_mutex_destroy
	.seh_proc _sigfe_pthread_mutex_destroy
_sigfe_pthread_mutex_destroy:
	leaq	pthread_mutex_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_getprioceiling
	.global	_sigfe_pthread_mutex_getprioceiling
	.seh_proc _sigfe_pthread_mutex_getprioceiling
_sigfe_pthread_mutex_getprioceiling:
	leaq	pthread_mutex_getprioceiling(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_init
	.global	_sigfe_pthread_mutex_init
	.seh_proc _sigfe_pthread_mutex_init
_sigfe_pthread_mutex_init:
	leaq	pthread_mutex_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_lock
	.global	_sigfe_pthread_mutex_lock
	.seh_proc _sigfe_pthread_mutex_lock
_sigfe_pthread_mutex_lock:
	leaq	pthread_mutex_lock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_setprioceiling
	.global	_sigfe_pthread_mutex_setprioceiling
	.seh_proc _sigfe_pthread_mutex_setprioceiling
_sigfe_pthread_mutex_setprioceiling:
	leaq	pthread_mutex_setprioceiling(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_timedlock
	.global	_sigfe_pthread_mutex_timedlock
	.seh_proc _sigfe_pthread_mutex_timedlock
_sigfe_pthread_mutex_timedlock:
	leaq	pthread_mutex_timedlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_trylock
	.global	_sigfe_pthread_mutex_trylock
	.seh_proc _sigfe_pthread_mutex_trylock
_sigfe_pthread_mutex_trylock:
	leaq	pthread_mutex_trylock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutex_unlock
	.global	_sigfe_pthread_mutex_unlock
	.seh_proc _sigfe_pthread_mutex_unlock
_sigfe_pthread_mutex_unlock:
	leaq	pthread_mutex_unlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_destroy
	.global	_sigfe_pthread_mutexattr_destroy
	.seh_proc _sigfe_pthread_mutexattr_destroy
_sigfe_pthread_mutexattr_destroy:
	leaq	pthread_mutexattr_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_getprioceiling
	.global	_sigfe_pthread_mutexattr_getprioceiling
	.seh_proc _sigfe_pthread_mutexattr_getprioceiling
_sigfe_pthread_mutexattr_getprioceiling:
	leaq	pthread_mutexattr_getprioceiling(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_getprotocol
	.global	_sigfe_pthread_mutexattr_getprotocol
	.seh_proc _sigfe_pthread_mutexattr_getprotocol
_sigfe_pthread_mutexattr_getprotocol:
	leaq	pthread_mutexattr_getprotocol(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_getpshared
	.global	_sigfe_pthread_mutexattr_getpshared
	.seh_proc _sigfe_pthread_mutexattr_getpshared
_sigfe_pthread_mutexattr_getpshared:
	leaq	pthread_mutexattr_getpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_gettype
	.global	_sigfe_pthread_mutexattr_gettype
	.seh_proc _sigfe_pthread_mutexattr_gettype
_sigfe_pthread_mutexattr_gettype:
	leaq	pthread_mutexattr_gettype(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_init
	.global	_sigfe_pthread_mutexattr_init
	.seh_proc _sigfe_pthread_mutexattr_init
_sigfe_pthread_mutexattr_init:
	leaq	pthread_mutexattr_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_setprioceiling
	.global	_sigfe_pthread_mutexattr_setprioceiling
	.seh_proc _sigfe_pthread_mutexattr_setprioceiling
_sigfe_pthread_mutexattr_setprioceiling:
	leaq	pthread_mutexattr_setprioceiling(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_setprotocol
	.global	_sigfe_pthread_mutexattr_setprotocol
	.seh_proc _sigfe_pthread_mutexattr_setprotocol
_sigfe_pthread_mutexattr_setprotocol:
	leaq	pthread_mutexattr_setprotocol(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_setpshared
	.global	_sigfe_pthread_mutexattr_setpshared
	.seh_proc _sigfe_pthread_mutexattr_setpshared
_sigfe_pthread_mutexattr_setpshared:
	leaq	pthread_mutexattr_setpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_mutexattr_settype
	.global	_sigfe_pthread_mutexattr_settype
	.seh_proc _sigfe_pthread_mutexattr_settype
_sigfe_pthread_mutexattr_settype:
	leaq	pthread_mutexattr_settype(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_once
	.global	_sigfe_pthread_once
	.seh_proc _sigfe_pthread_once
_sigfe_pthread_once:
	leaq	pthread_once(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_clockrdlock
	.global	_sigfe_pthread_rwlock_clockrdlock
	.seh_proc _sigfe_pthread_rwlock_clockrdlock
_sigfe_pthread_rwlock_clockrdlock:
	leaq	pthread_rwlock_clockrdlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_clockwrlock
	.global	_sigfe_pthread_rwlock_clockwrlock
	.seh_proc _sigfe_pthread_rwlock_clockwrlock
_sigfe_pthread_rwlock_clockwrlock:
	leaq	pthread_rwlock_clockwrlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_destroy
	.global	_sigfe_pthread_rwlock_destroy
	.seh_proc _sigfe_pthread_rwlock_destroy
_sigfe_pthread_rwlock_destroy:
	leaq	pthread_rwlock_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_init
	.global	_sigfe_pthread_rwlock_init
	.seh_proc _sigfe_pthread_rwlock_init
_sigfe_pthread_rwlock_init:
	leaq	pthread_rwlock_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_rdlock
	.global	_sigfe_pthread_rwlock_rdlock
	.seh_proc _sigfe_pthread_rwlock_rdlock
_sigfe_pthread_rwlock_rdlock:
	leaq	pthread_rwlock_rdlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_timedrdlock
	.global	_sigfe_pthread_rwlock_timedrdlock
	.seh_proc _sigfe_pthread_rwlock_timedrdlock
_sigfe_pthread_rwlock_timedrdlock:
	leaq	pthread_rwlock_timedrdlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_timedwrlock
	.global	_sigfe_pthread_rwlock_timedwrlock
	.seh_proc _sigfe_pthread_rwlock_timedwrlock
_sigfe_pthread_rwlock_timedwrlock:
	leaq	pthread_rwlock_timedwrlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_tryrdlock
	.global	_sigfe_pthread_rwlock_tryrdlock
	.seh_proc _sigfe_pthread_rwlock_tryrdlock
_sigfe_pthread_rwlock_tryrdlock:
	leaq	pthread_rwlock_tryrdlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_trywrlock
	.global	_sigfe_pthread_rwlock_trywrlock
	.seh_proc _sigfe_pthread_rwlock_trywrlock
_sigfe_pthread_rwlock_trywrlock:
	leaq	pthread_rwlock_trywrlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_unlock
	.global	_sigfe_pthread_rwlock_unlock
	.seh_proc _sigfe_pthread_rwlock_unlock
_sigfe_pthread_rwlock_unlock:
	leaq	pthread_rwlock_unlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlock_wrlock
	.global	_sigfe_pthread_rwlock_wrlock
	.seh_proc _sigfe_pthread_rwlock_wrlock
_sigfe_pthread_rwlock_wrlock:
	leaq	pthread_rwlock_wrlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlockattr_destroy
	.global	_sigfe_pthread_rwlockattr_destroy
	.seh_proc _sigfe_pthread_rwlockattr_destroy
_sigfe_pthread_rwlockattr_destroy:
	leaq	pthread_rwlockattr_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlockattr_getpshared
	.global	_sigfe_pthread_rwlockattr_getpshared
	.seh_proc _sigfe_pthread_rwlockattr_getpshared
_sigfe_pthread_rwlockattr_getpshared:
	leaq	pthread_rwlockattr_getpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlockattr_init
	.global	_sigfe_pthread_rwlockattr_init
	.seh_proc _sigfe_pthread_rwlockattr_init
_sigfe_pthread_rwlockattr_init:
	leaq	pthread_rwlockattr_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_rwlockattr_setpshared
	.global	_sigfe_pthread_rwlockattr_setpshared
	.seh_proc _sigfe_pthread_rwlockattr_setpshared
_sigfe_pthread_rwlockattr_setpshared:
	leaq	pthread_rwlockattr_setpshared(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_self
	.global	_sigfe_pthread_self
	.seh_proc _sigfe_pthread_self
_sigfe_pthread_self:
	leaq	pthread_self(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setaffinity_np
	.global	_sigfe_pthread_setaffinity_np
	.seh_proc _sigfe_pthread_setaffinity_np
_sigfe_pthread_setaffinity_np:
	leaq	pthread_setaffinity_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setcancelstate
	.global	_sigfe_pthread_setcancelstate
	.seh_proc _sigfe_pthread_setcancelstate
_sigfe_pthread_setcancelstate:
	leaq	pthread_setcancelstate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setcanceltype
	.global	_sigfe_pthread_setcanceltype
	.seh_proc _sigfe_pthread_setcanceltype
_sigfe_pthread_setcanceltype:
	leaq	pthread_setcanceltype(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setconcurrency
	.global	_sigfe_pthread_setconcurrency
	.seh_proc _sigfe_pthread_setconcurrency
_sigfe_pthread_setconcurrency:
	leaq	pthread_setconcurrency(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setname_np
	.global	_sigfe_pthread_setname_np
	.seh_proc _sigfe_pthread_setname_np
_sigfe_pthread_setname_np:
	leaq	pthread_setname_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setschedparam
	.global	_sigfe_pthread_setschedparam
	.seh_proc _sigfe_pthread_setschedparam
_sigfe_pthread_setschedparam:
	leaq	pthread_setschedparam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setschedprio
	.global	_sigfe_pthread_setschedprio
	.seh_proc _sigfe_pthread_setschedprio
_sigfe_pthread_setschedprio:
	leaq	pthread_setschedprio(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_setspecific
	.global	_sigfe_pthread_setspecific
	.seh_proc _sigfe_pthread_setspecific
_sigfe_pthread_setspecific:
	leaq	pthread_setspecific(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_sigmask
	.global	_sigfe_pthread_sigmask
	.seh_proc _sigfe_pthread_sigmask
_sigfe_pthread_sigmask:
	leaq	pthread_sigmask(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_sigqueue
	.global	_sigfe_pthread_sigqueue
	.seh_proc _sigfe_pthread_sigqueue
_sigfe_pthread_sigqueue:
	leaq	pthread_sigqueue(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_spin_destroy
	.global	_sigfe_pthread_spin_destroy
	.seh_proc _sigfe_pthread_spin_destroy
_sigfe_pthread_spin_destroy:
	leaq	pthread_spin_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_spin_init
	.global	_sigfe_pthread_spin_init
	.seh_proc _sigfe_pthread_spin_init
_sigfe_pthread_spin_init:
	leaq	pthread_spin_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_spin_lock
	.global	_sigfe_pthread_spin_lock
	.seh_proc _sigfe_pthread_spin_lock
_sigfe_pthread_spin_lock:
	leaq	pthread_spin_lock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_spin_trylock
	.global	_sigfe_pthread_spin_trylock
	.seh_proc _sigfe_pthread_spin_trylock
_sigfe_pthread_spin_trylock:
	leaq	pthread_spin_trylock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_spin_unlock
	.global	_sigfe_pthread_spin_unlock
	.seh_proc _sigfe_pthread_spin_unlock
_sigfe_pthread_spin_unlock:
	leaq	pthread_spin_unlock(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_suspend
	.global	_sigfe_pthread_suspend
	.seh_proc _sigfe_pthread_suspend
_sigfe_pthread_suspend:
	leaq	pthread_suspend(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_testcancel
	.global	_sigfe_pthread_testcancel
	.seh_proc _sigfe_pthread_testcancel
_sigfe_pthread_testcancel:
	leaq	pthread_testcancel(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_timedjoin_np
	.global	_sigfe_pthread_timedjoin_np
	.seh_proc _sigfe_pthread_timedjoin_np
_sigfe_pthread_timedjoin_np:
	leaq	pthread_timedjoin_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_tryjoin_np
	.global	_sigfe_pthread_tryjoin_np
	.seh_proc _sigfe_pthread_tryjoin_np
_sigfe_pthread_tryjoin_np:
	leaq	pthread_tryjoin_np(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pthread_yield
	.global	_sigfe_pthread_yield
	.seh_proc _sigfe_pthread_yield
_sigfe_pthread_yield:
	leaq	pthread_yield(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ptsname
	.global	_sigfe_ptsname
	.seh_proc _sigfe_ptsname
_sigfe_ptsname:
	leaq	ptsname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ptsname_r
	.global	_sigfe_ptsname_r
	.seh_proc _sigfe_ptsname_r
_sigfe_ptsname_r:
	leaq	ptsname_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putc
	.global	_sigfe_putc
	.seh_proc _sigfe_putc
_sigfe_putc:
	leaq	putc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putc_unlocked
	.global	_sigfe_putc_unlocked
	.seh_proc _sigfe_putc_unlocked
_sigfe_putc_unlocked:
	leaq	putc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putchar
	.global	_sigfe_putchar
	.seh_proc _sigfe_putchar
_sigfe_putchar:
	leaq	putchar(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putchar_unlocked
	.global	_sigfe_putchar_unlocked
	.seh_proc _sigfe_putchar_unlocked
_sigfe_putchar_unlocked:
	leaq	putchar_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putenv
	.global	_sigfe_putenv
	.seh_proc _sigfe_putenv
_sigfe_putenv:
	leaq	putenv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	puts
	.global	_sigfe_puts
	.seh_proc _sigfe_puts
_sigfe_puts:
	leaq	puts(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pututline
	.global	_sigfe_pututline
	.seh_proc _sigfe_pututline
_sigfe_pututline:
	leaq	pututline(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pututxline
	.global	_sigfe_pututxline
	.seh_proc _sigfe_pututxline
_sigfe_pututxline:
	leaq	pututxline(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putw
	.global	_sigfe_putw
	.seh_proc _sigfe_putw
_sigfe_putw:
	leaq	putw(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putwc
	.global	_sigfe_putwc
	.seh_proc _sigfe_putwc
_sigfe_putwc:
	leaq	putwc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putwc_unlocked
	.global	_sigfe_putwc_unlocked
	.seh_proc _sigfe_putwc_unlocked
_sigfe_putwc_unlocked:
	leaq	putwc_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putwchar
	.global	_sigfe_putwchar
	.seh_proc _sigfe_putwchar
_sigfe_putwchar:
	leaq	putwchar(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	putwchar_unlocked
	.global	_sigfe_putwchar_unlocked
	.seh_proc _sigfe_putwchar_unlocked
_sigfe_putwchar_unlocked:
	leaq	putwchar_unlocked(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	pwrite
	.global	_sigfe_pwrite
	.seh_proc _sigfe_pwrite
_sigfe_pwrite:
	leaq	pwrite(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	quick_exit
	.global	_sigfe_quick_exit
	.seh_proc _sigfe_quick_exit
_sigfe_quick_exit:
	leaq	quick_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	quotactl
	.global	_sigfe_quotactl
	.seh_proc _sigfe_quotactl
_sigfe_quotactl:
	leaq	quotactl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	raise
	.global	_sigfe_raise
	.seh_proc _sigfe_raise
_sigfe_raise:
	leaq	raise(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	read
	.global	_sigfe_read
	.seh_proc _sigfe_read
_sigfe_read:
	leaq	read(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	readdir
	.global	_sigfe_readdir
	.seh_proc _sigfe_readdir
_sigfe_readdir:
	leaq	readdir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	readdir_r
	.global	_sigfe_readdir_r
	.seh_proc _sigfe_readdir_r
_sigfe_readdir_r:
	leaq	readdir_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	readlink
	.global	_sigfe_readlink
	.seh_proc _sigfe_readlink
_sigfe_readlink:
	leaq	readlink(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	readlinkat
	.global	_sigfe_readlinkat
	.seh_proc _sigfe_readlinkat
_sigfe_readlinkat:
	leaq	readlinkat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	readv
	.global	_sigfe_readv
	.seh_proc _sigfe_readv
_sigfe_readv:
	leaq	readv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	realloc
	.global	_sigfe_realloc
	.seh_proc _sigfe_realloc
_sigfe_realloc:
	leaq	realloc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	reallocarray
	.global	_sigfe_reallocarray
	.seh_proc _sigfe_reallocarray
_sigfe_reallocarray:
	leaq	reallocarray(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	reallocf
	.global	_sigfe_reallocf
	.seh_proc _sigfe_reallocf
_sigfe_reallocf:
	leaq	reallocf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	realpath
	.global	_sigfe_realpath
	.seh_proc _sigfe_realpath
_sigfe_realpath:
	leaq	realpath(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	regcomp
	.global	_sigfe_regcomp
	.seh_proc _sigfe_regcomp
_sigfe_regcomp:
	leaq	regcomp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	regerror
	.global	_sigfe_regerror
	.seh_proc _sigfe_regerror
_sigfe_regerror:
	leaq	regerror(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	regexec
	.global	_sigfe_regexec
	.seh_proc _sigfe_regexec
_sigfe_regexec:
	leaq	regexec(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	regfree
	.global	_sigfe_regfree
	.seh_proc _sigfe_regfree
_sigfe_regfree:
	leaq	regfree(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	remove
	.global	_sigfe_remove
	.seh_proc _sigfe_remove
_sigfe_remove:
	leaq	remove(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	removexattr
	.global	_sigfe_removexattr
	.seh_proc _sigfe_removexattr
_sigfe_removexattr:
	leaq	removexattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	rename
	.global	_sigfe_rename
	.seh_proc _sigfe_rename
_sigfe_rename:
	leaq	rename(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	renameat
	.global	_sigfe_renameat
	.seh_proc _sigfe_renameat
_sigfe_renameat:
	leaq	renameat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	renameat2
	.global	_sigfe_renameat2
	.seh_proc _sigfe_renameat2
_sigfe_renameat2:
	leaq	renameat2(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	revoke
	.global	_sigfe_revoke
	.seh_proc _sigfe_revoke
_sigfe_revoke:
	leaq	revoke(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	rewind
	.global	_sigfe_rewind
	.seh_proc _sigfe_rewind
_sigfe_rewind:
	leaq	rewind(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	rewinddir
	.global	_sigfe_rewinddir
	.seh_proc _sigfe_rewinddir
_sigfe_rewinddir:
	leaq	rewinddir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	rmdir
	.global	_sigfe_rmdir
	.seh_proc _sigfe_rmdir
_sigfe_rmdir:
	leaq	rmdir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	rpmatch
	.global	_sigfe_rpmatch
	.seh_proc _sigfe_rpmatch
_sigfe_rpmatch:
	leaq	rpmatch(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ruserok
	.global	_sigfe_ruserok
	.seh_proc _sigfe_ruserok
_sigfe_ruserok:
	leaq	ruserok(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sbrk
	.global	_sigfe_sbrk
	.seh_proc _sigfe_sbrk
_sigfe_sbrk:
	leaq	sbrk(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	scandir
	.global	_sigfe_scandir
	.seh_proc _sigfe_scandir
_sigfe_scandir:
	leaq	scandir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	scandirat
	.global	_sigfe_scandirat
	.seh_proc _sigfe_scandirat
_sigfe_scandirat:
	leaq	scandirat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	scanf
	.global	_sigfe_scanf
	.seh_proc _sigfe_scanf
_sigfe_scanf:
	leaq	scanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_get_priority_max
	.global	_sigfe_sched_get_priority_max
	.seh_proc _sigfe_sched_get_priority_max
_sigfe_sched_get_priority_max:
	leaq	sched_get_priority_max(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_get_priority_min
	.global	_sigfe_sched_get_priority_min
	.seh_proc _sigfe_sched_get_priority_min
_sigfe_sched_get_priority_min:
	leaq	sched_get_priority_min(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_getaffinity
	.global	_sigfe_sched_getaffinity
	.seh_proc _sigfe_sched_getaffinity
_sigfe_sched_getaffinity:
	leaq	sched_getaffinity(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_getcpu
	.global	_sigfe_sched_getcpu
	.seh_proc _sigfe_sched_getcpu
_sigfe_sched_getcpu:
	leaq	sched_getcpu(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_getparam
	.global	_sigfe_sched_getparam
	.seh_proc _sigfe_sched_getparam
_sigfe_sched_getparam:
	leaq	sched_getparam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_rr_get_interval
	.global	_sigfe_sched_rr_get_interval
	.seh_proc _sigfe_sched_rr_get_interval
_sigfe_sched_rr_get_interval:
	leaq	sched_rr_get_interval(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_setaffinity
	.global	_sigfe_sched_setaffinity
	.seh_proc _sigfe_sched_setaffinity
_sigfe_sched_setaffinity:
	leaq	sched_setaffinity(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_setparam
	.global	_sigfe_sched_setparam
	.seh_proc _sigfe_sched_setparam
_sigfe_sched_setparam:
	leaq	sched_setparam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_setscheduler
	.global	_sigfe_sched_setscheduler
	.seh_proc _sigfe_sched_setscheduler
_sigfe_sched_setscheduler:
	leaq	sched_setscheduler(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sched_yield
	.global	_sigfe_sched_yield
	.seh_proc _sigfe_sched_yield
_sigfe_sched_yield:
	leaq	sched_yield(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	seekdir
	.global	_sigfe_seekdir
	.seh_proc _sigfe_seekdir
_sigfe_seekdir:
	leaq	seekdir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_clockwait
	.global	_sigfe_sem_clockwait
	.seh_proc _sigfe_sem_clockwait
_sigfe_sem_clockwait:
	leaq	sem_clockwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_close
	.global	_sigfe_sem_close
	.seh_proc _sigfe_sem_close
_sigfe_sem_close:
	leaq	sem_close(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_destroy
	.global	_sigfe_sem_destroy
	.seh_proc _sigfe_sem_destroy
_sigfe_sem_destroy:
	leaq	sem_destroy(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_getvalue
	.global	_sigfe_sem_getvalue
	.seh_proc _sigfe_sem_getvalue
_sigfe_sem_getvalue:
	leaq	sem_getvalue(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_init
	.global	_sigfe_sem_init
	.seh_proc _sigfe_sem_init
_sigfe_sem_init:
	leaq	sem_init(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_open
	.global	_sigfe_sem_open
	.seh_proc _sigfe_sem_open
_sigfe_sem_open:
	leaq	sem_open(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_post
	.global	_sigfe_sem_post
	.seh_proc _sigfe_sem_post
_sigfe_sem_post:
	leaq	sem_post(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_timedwait
	.global	_sigfe_sem_timedwait
	.seh_proc _sigfe_sem_timedwait
_sigfe_sem_timedwait:
	leaq	sem_timedwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_trywait
	.global	_sigfe_sem_trywait
	.seh_proc _sigfe_sem_trywait
_sigfe_sem_trywait:
	leaq	sem_trywait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_unlink
	.global	_sigfe_sem_unlink
	.seh_proc _sigfe_sem_unlink
_sigfe_sem_unlink:
	leaq	sem_unlink(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sem_wait
	.global	_sigfe_sem_wait
	.seh_proc _sigfe_sem_wait
_sigfe_sem_wait:
	leaq	sem_wait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	semctl
	.global	_sigfe_semctl
	.seh_proc _sigfe_semctl
_sigfe_semctl:
	leaq	semctl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	semget
	.global	_sigfe_semget
	.seh_proc _sigfe_semget
_sigfe_semget:
	leaq	semget(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	semop
	.global	_sigfe_semop
	.seh_proc _sigfe_semop
_sigfe_semop:
	leaq	semop(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setbuf
	.global	_sigfe_setbuf
	.seh_proc _sigfe_setbuf
_sigfe_setbuf:
	leaq	setbuf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setbuffer
	.global	_sigfe_setbuffer
	.seh_proc _sigfe_setbuffer
_sigfe_setbuffer:
	leaq	setbuffer(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setdtablesize
	.global	_sigfe_setdtablesize
	.seh_proc _sigfe_setdtablesize
_sigfe_setdtablesize:
	leaq	setdtablesize(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setegid
	.global	_sigfe_setegid
	.seh_proc _sigfe_setegid
_sigfe_setegid:
	leaq	setegid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setenv
	.global	_sigfe_setenv
	.seh_proc _sigfe_setenv
_sigfe_setenv:
	leaq	setenv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	seteuid
	.global	_sigfe_seteuid
	.seh_proc _sigfe_seteuid
_sigfe_seteuid:
	leaq	seteuid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setgid
	.global	_sigfe_setgid
	.seh_proc _sigfe_setgid
_sigfe_setgid:
	leaq	setgid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setgroups
	.global	_sigfe_setgroups
	.seh_proc _sigfe_setgroups
_sigfe_setgroups:
	leaq	setgroups(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sethostname
	.global	_sigfe_sethostname
	.seh_proc _sigfe_sethostname
_sigfe_sethostname:
	leaq	sethostname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setitimer
	.global	_sigfe_setitimer
	.seh_proc _sigfe_setitimer
_sigfe_setitimer:
	leaq	setitimer(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setlinebuf
	.global	_sigfe_setlinebuf
	.seh_proc _sigfe_setlinebuf
_sigfe_setlinebuf:
	leaq	setlinebuf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setmntent
	.global	_sigfe_setmntent
	.seh_proc _sigfe_setmntent
_sigfe_setmntent:
	leaq	setmntent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setpgid
	.global	_sigfe_setpgid
	.seh_proc _sigfe_setpgid
_sigfe_setpgid:
	leaq	setpgid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setpgrp
	.global	_sigfe_setpgrp
	.seh_proc _sigfe_setpgrp
_sigfe_setpgrp:
	leaq	setpgrp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setpriority
	.global	_sigfe_setpriority
	.seh_proc _sigfe_setpriority
_sigfe_setpriority:
	leaq	setpriority(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setregid
	.global	_sigfe_setregid
	.seh_proc _sigfe_setregid
_sigfe_setregid:
	leaq	setregid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setreuid
	.global	_sigfe_setreuid
	.seh_proc _sigfe_setreuid
_sigfe_setreuid:
	leaq	setreuid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setrlimit
	.global	_sigfe_setrlimit
	.seh_proc _sigfe_setrlimit
_sigfe_setrlimit:
	leaq	setrlimit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setsid
	.global	_sigfe_setsid
	.seh_proc _sigfe_setsid
_sigfe_setsid:
	leaq	setsid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	settimeofday
	.global	_sigfe_settimeofday
	.seh_proc _sigfe_settimeofday
_sigfe_settimeofday:
	leaq	settimeofday(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setuid
	.global	_sigfe_setuid
	.seh_proc _sigfe_setuid
_sigfe_setuid:
	leaq	setuid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setusershell
	.global	_sigfe_setusershell
	.seh_proc _sigfe_setusershell
_sigfe_setusershell:
	leaq	setusershell(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setutent
	.global	_sigfe_setutent
	.seh_proc _sigfe_setutent
_sigfe_setutent:
	leaq	setutent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setutxent
	.global	_sigfe_setutxent
	.seh_proc _sigfe_setutxent
_sigfe_setutxent:
	leaq	setutxent(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setvbuf
	.global	_sigfe_setvbuf
	.seh_proc _sigfe_setvbuf
_sigfe_setvbuf:
	leaq	setvbuf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	setxattr
	.global	_sigfe_setxattr
	.seh_proc _sigfe_setxattr
_sigfe_setxattr:
	leaq	setxattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	shm_open
	.global	_sigfe_shm_open
	.seh_proc _sigfe_shm_open
_sigfe_shm_open:
	leaq	shm_open(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	shm_unlink
	.global	_sigfe_shm_unlink
	.seh_proc _sigfe_shm_unlink
_sigfe_shm_unlink:
	leaq	shm_unlink(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	shmat
	.global	_sigfe_shmat
	.seh_proc _sigfe_shmat
_sigfe_shmat:
	leaq	shmat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	shmctl
	.global	_sigfe_shmctl
	.seh_proc _sigfe_shmctl
_sigfe_shmctl:
	leaq	shmctl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	shmdt
	.global	_sigfe_shmdt
	.seh_proc _sigfe_shmdt
_sigfe_shmdt:
	leaq	shmdt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	shmget
	.global	_sigfe_shmget
	.seh_proc _sigfe_shmget
_sigfe_shmget:
	leaq	shmget(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sig2str
	.global	_sigfe_sig2str
	.seh_proc _sigfe_sig2str
_sigfe_sig2str:
	leaq	sig2str(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigaction
	.global	_sigfe_sigaction
	.seh_proc _sigfe_sigaction
_sigfe_sigaction:
	leaq	sigaction(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigaddset
	.global	_sigfe_sigaddset
	.seh_proc _sigfe_sigaddset
_sigfe_sigaddset:
	leaq	sigaddset(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigaltstack
	.global	_sigfe_sigaltstack
	.seh_proc _sigfe_sigaltstack
_sigfe_sigaltstack:
	leaq	sigaltstack(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigdelset
	.global	_sigfe_sigdelset
	.seh_proc _sigfe_sigdelset
_sigfe_sigdelset:
	leaq	sigdelset(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sighold
	.global	_sigfe_sighold
	.seh_proc _sigfe_sighold
_sigfe_sighold:
	leaq	sighold(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigignore
	.global	_sigfe_sigignore
	.seh_proc _sigfe_sigignore
_sigfe_sigignore:
	leaq	sigignore(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	siginterrupt
	.global	_sigfe_siginterrupt
	.seh_proc _sigfe_siginterrupt
_sigfe_siginterrupt:
	leaq	siginterrupt(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigismember
	.global	_sigfe_sigismember
	.seh_proc _sigfe_sigismember
_sigfe_sigismember:
	leaq	sigismember(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	signal
	.global	_sigfe_signal
	.seh_proc _sigfe_signal
_sigfe_signal:
	leaq	signal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	signalfd
	.global	_sigfe_signalfd
	.seh_proc _sigfe_signalfd
_sigfe_signalfd:
	leaq	signalfd(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigpause
	.global	_sigfe_sigpause
	.seh_proc _sigfe_sigpause
_sigfe_sigpause:
	leaq	sigpause(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigpending
	.global	_sigfe_sigpending
	.seh_proc _sigfe_sigpending
_sigfe_sigpending:
	leaq	sigpending(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigprocmask
	.global	_sigfe_sigprocmask
	.seh_proc _sigfe_sigprocmask
_sigfe_sigprocmask:
	leaq	sigprocmask(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigqueue
	.global	_sigfe_sigqueue
	.seh_proc _sigfe_sigqueue
_sigfe_sigqueue:
	leaq	sigqueue(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigrelse
	.global	_sigfe_sigrelse
	.seh_proc _sigfe_sigrelse
_sigfe_sigrelse:
	leaq	sigrelse(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigset
	.global	_sigfe_sigset
	.seh_proc _sigfe_sigset
_sigfe_sigset:
	leaq	sigset(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigsuspend
	.global	_sigfe_sigsuspend
	.seh_proc _sigfe_sigsuspend
_sigfe_sigsuspend:
	leaq	sigsuspend(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigtimedwait
	.global	_sigfe_sigtimedwait
	.seh_proc _sigfe_sigtimedwait
_sigfe_sigtimedwait:
	leaq	sigtimedwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigwait
	.global	_sigfe_sigwait
	.seh_proc _sigfe_sigwait
_sigfe_sigwait:
	leaq	sigwait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sigwaitinfo
	.global	_sigfe_sigwaitinfo
	.seh_proc _sigfe_sigwaitinfo
_sigfe_sigwaitinfo:
	leaq	sigwaitinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	siprintf
	.global	_sigfe_siprintf
	.seh_proc _sigfe_siprintf
_sigfe_siprintf:
	leaq	siprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sleep
	.global	_sigfe_sleep
	.seh_proc _sigfe_sleep
_sigfe_sleep:
	leaq	sleep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	snprintf
	.global	_sigfe_snprintf
	.seh_proc _sigfe_snprintf
_sigfe_snprintf:
	leaq	snprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sockatmark
	.global	_sigfe_sockatmark
	.seh_proc _sigfe_sockatmark
_sigfe_sockatmark:
	leaq	sockatmark(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	socketpair
	.global	_sigfe_socketpair
	.seh_proc _sigfe_socketpair
_sigfe_socketpair:
	leaq	socketpair(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnl
	.global	_sigfe_spawnl
	.seh_proc _sigfe_spawnl
_sigfe_spawnl:
	leaq	spawnl(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnle
	.global	_sigfe_spawnle
	.seh_proc _sigfe_spawnle
_sigfe_spawnle:
	leaq	spawnle(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnlp
	.global	_sigfe_spawnlp
	.seh_proc _sigfe_spawnlp
_sigfe_spawnlp:
	leaq	spawnlp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnlpe
	.global	_sigfe_spawnlpe
	.seh_proc _sigfe_spawnlpe
_sigfe_spawnlpe:
	leaq	spawnlpe(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnv
	.global	_sigfe_spawnv
	.seh_proc _sigfe_spawnv
_sigfe_spawnv:
	leaq	spawnv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnve
	.global	_sigfe_spawnve
	.seh_proc _sigfe_spawnve
_sigfe_spawnve:
	leaq	spawnve(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnvp
	.global	_sigfe_spawnvp
	.seh_proc _sigfe_spawnvp
_sigfe_spawnvp:
	leaq	spawnvp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	spawnvpe
	.global	_sigfe_spawnvpe
	.seh_proc _sigfe_spawnvpe
_sigfe_spawnvpe:
	leaq	spawnvpe(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sprintf
	.global	_sigfe_sprintf
	.seh_proc _sigfe_sprintf
_sigfe_sprintf:
	leaq	sprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sscanf
	.global	_sigfe_sscanf
	.seh_proc _sigfe_sscanf
_sigfe_sscanf:
	leaq	sscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	stat
	.global	_sigfe_stat
	.seh_proc _sigfe_stat
_sigfe_stat:
	leaq	stat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	statfs
	.global	_sigfe_statfs
	.seh_proc _sigfe_statfs
_sigfe_statfs:
	leaq	statfs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	statvfs
	.global	_sigfe_statvfs
	.seh_proc _sigfe_statvfs
_sigfe_statvfs:
	leaq	statvfs(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	stime
	.global	_sigfe_stime
	.seh_proc _sigfe_stime
_sigfe_stime:
	leaq	stime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	str2sig
	.global	_sigfe_str2sig
	.seh_proc _sigfe_str2sig
_sigfe_str2sig:
	leaq	str2sig(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strdup
	.global	_sigfe_strdup
	.seh_proc _sigfe_strdup
_sigfe_strdup:
	leaq	strdup(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strerror
	.global	_sigfe_strerror
	.seh_proc _sigfe_strerror
_sigfe_strerror:
	leaq	strerror(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strerror_l
	.global	_sigfe_strerror_l
	.seh_proc _sigfe_strerror_l
_sigfe_strerror_l:
	leaq	strerror_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strerror_r
	.global	_sigfe_strerror_r
	.seh_proc _sigfe_strerror_r
_sigfe_strerror_r:
	leaq	strerror_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strfmon
	.global	_sigfe_strfmon
	.seh_proc _sigfe_strfmon
_sigfe_strfmon:
	leaq	strfmon(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strfmon_l
	.global	_sigfe_strfmon_l
	.seh_proc _sigfe_strfmon_l
_sigfe_strfmon_l:
	leaq	strfmon_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strftime
	.global	_sigfe_strftime
	.seh_proc _sigfe_strftime
_sigfe_strftime:
	leaq	strftime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strftime_l
	.global	_sigfe_strftime_l
	.seh_proc _sigfe_strftime_l
_sigfe_strftime_l:
	leaq	strftime_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strndup
	.global	_sigfe_strndup
	.seh_proc _sigfe_strndup
_sigfe_strndup:
	leaq	strndup(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strptime
	.global	_sigfe_strptime
	.seh_proc _sigfe_strptime
_sigfe_strptime:
	leaq	strptime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strptime_l
	.global	_sigfe_strptime_l
	.seh_proc _sigfe_strptime_l
_sigfe_strptime_l:
	leaq	strptime_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strsignal
	.global	_sigfe_strsignal
	.seh_proc _sigfe_strsignal
_sigfe_strsignal:
	leaq	strsignal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strtod
	.global	_sigfe_strtod
	.seh_proc _sigfe_strtod
_sigfe_strtod:
	leaq	strtod(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strtod_l
	.global	_sigfe_strtod_l
	.seh_proc _sigfe_strtod_l
_sigfe_strtod_l:
	leaq	strtod_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strtof
	.global	_sigfe_strtof
	.seh_proc _sigfe_strtof
_sigfe_strtof:
	leaq	strtof(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strtof_l
	.global	_sigfe_strtof_l
	.seh_proc _sigfe_strtof_l
_sigfe_strtof_l:
	leaq	strtof_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strtold
	.global	_sigfe_strtold
	.seh_proc _sigfe_strtold
_sigfe_strtold:
	leaq	strtold(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	strtold_l
	.global	_sigfe_strtold_l
	.seh_proc _sigfe_strtold_l
_sigfe_strtold_l:
	leaq	strtold_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	swprintf
	.global	_sigfe_swprintf
	.seh_proc _sigfe_swprintf
_sigfe_swprintf:
	leaq	swprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	swscanf
	.global	_sigfe_swscanf
	.seh_proc _sigfe_swscanf
_sigfe_swscanf:
	leaq	swscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	symlink
	.global	_sigfe_symlink
	.seh_proc _sigfe_symlink
_sigfe_symlink:
	leaq	symlink(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	symlinkat
	.global	_sigfe_symlinkat
	.seh_proc _sigfe_symlinkat
_sigfe_symlinkat:
	leaq	symlinkat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sync
	.global	_sigfe_sync
	.seh_proc _sigfe_sync
_sigfe_sync:
	leaq	sync(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sysconf
	.global	_sigfe_sysconf
	.seh_proc _sigfe_sysconf
_sigfe_sysconf:
	leaq	sysconf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	sysinfo
	.global	_sigfe_sysinfo
	.seh_proc _sigfe_sysinfo
_sigfe_sysinfo:
	leaq	sysinfo(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	syslog
	.global	_sigfe_syslog
	.seh_proc _sigfe_syslog
_sigfe_syslog:
	leaq	syslog(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	system
	.global	_sigfe_system
	.seh_proc _sigfe_system
_sigfe_system:
	leaq	system(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcdrain
	.global	_sigfe_tcdrain
	.seh_proc _sigfe_tcdrain
_sigfe_tcdrain:
	leaq	tcdrain(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcflow
	.global	_sigfe_tcflow
	.seh_proc _sigfe_tcflow
_sigfe_tcflow:
	leaq	tcflow(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcflush
	.global	_sigfe_tcflush
	.seh_proc _sigfe_tcflush
_sigfe_tcflush:
	leaq	tcflush(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcgetattr
	.global	_sigfe_tcgetattr
	.seh_proc _sigfe_tcgetattr
_sigfe_tcgetattr:
	leaq	tcgetattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcgetpgrp
	.global	_sigfe_tcgetpgrp
	.seh_proc _sigfe_tcgetpgrp
_sigfe_tcgetpgrp:
	leaq	tcgetpgrp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcgetsid
	.global	_sigfe_tcgetsid
	.seh_proc _sigfe_tcgetsid
_sigfe_tcgetsid:
	leaq	tcgetsid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcsendbreak
	.global	_sigfe_tcsendbreak
	.seh_proc _sigfe_tcsendbreak
_sigfe_tcsendbreak:
	leaq	tcsendbreak(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcsetattr
	.global	_sigfe_tcsetattr
	.seh_proc _sigfe_tcsetattr
_sigfe_tcsetattr:
	leaq	tcsetattr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tcsetpgrp
	.global	_sigfe_tcsetpgrp
	.seh_proc _sigfe_tcsetpgrp
_sigfe_tcsetpgrp:
	leaq	tcsetpgrp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tdelete
	.global	_sigfe_tdelete
	.seh_proc _sigfe_tdelete
_sigfe_tdelete:
	leaq	tdelete(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	telldir
	.global	_sigfe_telldir
	.seh_proc _sigfe_telldir
_sigfe_telldir:
	leaq	telldir(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tempnam
	.global	_sigfe_tempnam
	.seh_proc _sigfe_tempnam
_sigfe_tempnam:
	leaq	tempnam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_create
	.global	_sigfe_thrd_create
	.seh_proc _sigfe_thrd_create
_sigfe_thrd_create:
	leaq	thrd_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_current
	.global	_sigfe_thrd_current
	.seh_proc _sigfe_thrd_current
_sigfe_thrd_current:
	leaq	thrd_current(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_detach
	.global	_sigfe_thrd_detach
	.seh_proc _sigfe_thrd_detach
_sigfe_thrd_detach:
	leaq	thrd_detach(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_equal
	.global	_sigfe_thrd_equal
	.seh_proc _sigfe_thrd_equal
_sigfe_thrd_equal:
	leaq	thrd_equal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_exit
	.global	_sigfe_thrd_exit
	.seh_proc _sigfe_thrd_exit
_sigfe_thrd_exit:
	leaq	thrd_exit(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_join
	.global	_sigfe_thrd_join
	.seh_proc _sigfe_thrd_join
_sigfe_thrd_join:
	leaq	thrd_join(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_sleep
	.global	_sigfe_thrd_sleep
	.seh_proc _sigfe_thrd_sleep
_sigfe_thrd_sleep:
	leaq	thrd_sleep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	thrd_yield
	.global	_sigfe_thrd_yield
	.seh_proc _sigfe_thrd_yield
_sigfe_thrd_yield:
	leaq	thrd_yield(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	time
	.global	_sigfe_time
	.seh_proc _sigfe_time
_sigfe_time:
	leaq	time(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timelocal
	.global	_sigfe_timelocal
	.seh_proc _sigfe_timelocal
_sigfe_timelocal:
	leaq	timelocal(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timer_create
	.global	_sigfe_timer_create
	.seh_proc _sigfe_timer_create
_sigfe_timer_create:
	leaq	timer_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timer_delete
	.global	_sigfe_timer_delete
	.seh_proc _sigfe_timer_delete
_sigfe_timer_delete:
	leaq	timer_delete(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timer_getoverrun
	.global	_sigfe_timer_getoverrun
	.seh_proc _sigfe_timer_getoverrun
_sigfe_timer_getoverrun:
	leaq	timer_getoverrun(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timer_gettime
	.global	_sigfe_timer_gettime
	.seh_proc _sigfe_timer_gettime
_sigfe_timer_gettime:
	leaq	timer_gettime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timer_settime
	.global	_sigfe_timer_settime
	.seh_proc _sigfe_timer_settime
_sigfe_timer_settime:
	leaq	timer_settime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timerfd_create
	.global	_sigfe_timerfd_create
	.seh_proc _sigfe_timerfd_create
_sigfe_timerfd_create:
	leaq	timerfd_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timerfd_gettime
	.global	_sigfe_timerfd_gettime
	.seh_proc _sigfe_timerfd_gettime
_sigfe_timerfd_gettime:
	leaq	timerfd_gettime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timerfd_settime
	.global	_sigfe_timerfd_settime
	.seh_proc _sigfe_timerfd_settime
_sigfe_timerfd_settime:
	leaq	timerfd_settime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	times
	.global	_sigfe_times
	.seh_proc _sigfe_times
_sigfe_times:
	leaq	times(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	timezone
	.global	_sigfe_timezone
	.seh_proc _sigfe_timezone
_sigfe_timezone:
	leaq	timezone(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tmpfile
	.global	_sigfe_tmpfile
	.seh_proc _sigfe_tmpfile
_sigfe_tmpfile:
	leaq	tmpfile(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tmpnam
	.global	_sigfe_tmpnam
	.seh_proc _sigfe_tmpnam
_sigfe_tmpnam:
	leaq	tmpnam(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	truncate
	.global	_sigfe_truncate
	.seh_proc _sigfe_truncate
_sigfe_truncate:
	leaq	truncate(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tsearch
	.global	_sigfe_tsearch
	.seh_proc _sigfe_tsearch
_sigfe_tsearch:
	leaq	tsearch(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tss_create
	.global	_sigfe_tss_create
	.seh_proc _sigfe_tss_create
_sigfe_tss_create:
	leaq	tss_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tss_delete
	.global	_sigfe_tss_delete
	.seh_proc _sigfe_tss_delete
_sigfe_tss_delete:
	leaq	tss_delete(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tss_get
	.global	_sigfe_tss_get
	.seh_proc _sigfe_tss_get
_sigfe_tss_get:
	leaq	tss_get(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tss_set
	.global	_sigfe_tss_set
	.seh_proc _sigfe_tss_set
_sigfe_tss_set:
	leaq	tss_set(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ttyname
	.global	_sigfe_ttyname
	.seh_proc _sigfe_ttyname
_sigfe_ttyname:
	leaq	ttyname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ttyname_r
	.global	_sigfe_ttyname_r
	.seh_proc _sigfe_ttyname_r
_sigfe_ttyname_r:
	leaq	ttyname_r(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	tzset
	.global	_sigfe_tzset
	.seh_proc _sigfe_tzset
_sigfe_tzset:
	leaq	tzset(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ualarm
	.global	_sigfe_ualarm
	.seh_proc _sigfe_ualarm
_sigfe_ualarm:
	leaq	ualarm(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	umount
	.global	_sigfe_umount
	.seh_proc _sigfe_umount
_sigfe_umount:
	leaq	umount(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	uname
	.global	_sigfe_uname
	.seh_proc _sigfe_uname
_sigfe_uname:
	leaq	uname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	uname_x
	.global	_sigfe_uname_x
	.seh_proc _sigfe_uname_x
_sigfe_uname_x:
	leaq	uname_x(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ungetc
	.global	_sigfe_ungetc
	.seh_proc _sigfe_ungetc
_sigfe_ungetc:
	leaq	ungetc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	ungetwc
	.global	_sigfe_ungetwc
	.seh_proc _sigfe_ungetwc
_sigfe_ungetwc:
	leaq	ungetwc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	unlink
	.global	_sigfe_unlink
	.seh_proc _sigfe_unlink
_sigfe_unlink:
	leaq	unlink(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	unlinkat
	.global	_sigfe_unlinkat
	.seh_proc _sigfe_unlinkat
_sigfe_unlinkat:
	leaq	unlinkat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	unsetenv
	.global	_sigfe_unsetenv
	.seh_proc _sigfe_unsetenv
_sigfe_unsetenv:
	leaq	unsetenv(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	updwtmp
	.global	_sigfe_updwtmp
	.seh_proc _sigfe_updwtmp
_sigfe_updwtmp:
	leaq	updwtmp(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	updwtmpx
	.global	_sigfe_updwtmpx
	.seh_proc _sigfe_updwtmpx
_sigfe_updwtmpx:
	leaq	updwtmpx(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	uselocale
	.global	_sigfe_uselocale
	.seh_proc _sigfe_uselocale
_sigfe_uselocale:
	leaq	uselocale(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	usleep
	.global	_sigfe_usleep
	.seh_proc _sigfe_usleep
_sigfe_usleep:
	leaq	usleep(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	utime
	.global	_sigfe_utime
	.seh_proc _sigfe_utime
_sigfe_utime:
	leaq	utime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	utimensat
	.global	_sigfe_utimensat
	.seh_proc _sigfe_utimensat
_sigfe_utimensat:
	leaq	utimensat(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	utimes
	.global	_sigfe_utimes
	.seh_proc _sigfe_utimes
_sigfe_utimes:
	leaq	utimes(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	utmpname
	.global	_sigfe_utmpname
	.seh_proc _sigfe_utmpname
_sigfe_utmpname:
	leaq	utmpname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	utmpxname
	.global	_sigfe_utmpxname
	.seh_proc _sigfe_utmpxname
_sigfe_utmpxname:
	leaq	utmpxname(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	valloc
	.global	_sigfe_valloc
	.seh_proc _sigfe_valloc
_sigfe_valloc:
	leaq	valloc(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vasnprintf
	.global	_sigfe_vasnprintf
	.seh_proc _sigfe_vasnprintf
_sigfe_vasnprintf:
	leaq	vasnprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vasprintf
	.global	_sigfe_vasprintf
	.seh_proc _sigfe_vasprintf
_sigfe_vasprintf:
	leaq	vasprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vdprintf
	.global	_sigfe_vdprintf
	.seh_proc _sigfe_vdprintf
_sigfe_vdprintf:
	leaq	vdprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	verr
	.global	_sigfe_verr
	.seh_proc _sigfe_verr
_sigfe_verr:
	leaq	verr(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	verrx
	.global	_sigfe_verrx
	.seh_proc _sigfe_verrx
_sigfe_verrx:
	leaq	verrx(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vfiprintf
	.global	_sigfe_vfiprintf
	.seh_proc _sigfe_vfiprintf
_sigfe_vfiprintf:
	leaq	vfiprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vfork
	.global	_sigfe_vfork
	.seh_proc _sigfe_vfork
_sigfe_vfork:
	leaq	vfork(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vfprintf
	.global	_sigfe_vfprintf
	.seh_proc _sigfe_vfprintf
_sigfe_vfprintf:
	leaq	vfprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vfscanf
	.global	_sigfe_vfscanf
	.seh_proc _sigfe_vfscanf
_sigfe_vfscanf:
	leaq	vfscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vfwprintf
	.global	_sigfe_vfwprintf
	.seh_proc _sigfe_vfwprintf
_sigfe_vfwprintf:
	leaq	vfwprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vfwscanf
	.global	_sigfe_vfwscanf
	.seh_proc _sigfe_vfwscanf
_sigfe_vfwscanf:
	leaq	vfwscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vhangup
	.global	_sigfe_vhangup
	.seh_proc _sigfe_vhangup
_sigfe_vhangup:
	leaq	vhangup(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vprintf
	.global	_sigfe_vprintf
	.seh_proc _sigfe_vprintf
_sigfe_vprintf:
	leaq	vprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vscanf
	.global	_sigfe_vscanf
	.seh_proc _sigfe_vscanf
_sigfe_vscanf:
	leaq	vscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vsnprintf
	.global	_sigfe_vsnprintf
	.seh_proc _sigfe_vsnprintf
_sigfe_vsnprintf:
	leaq	vsnprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vsprintf
	.global	_sigfe_vsprintf
	.seh_proc _sigfe_vsprintf
_sigfe_vsprintf:
	leaq	vsprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vsscanf
	.global	_sigfe_vsscanf
	.seh_proc _sigfe_vsscanf
_sigfe_vsscanf:
	leaq	vsscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vswprintf
	.global	_sigfe_vswprintf
	.seh_proc _sigfe_vswprintf
_sigfe_vswprintf:
	leaq	vswprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vswscanf
	.global	_sigfe_vswscanf
	.seh_proc _sigfe_vswscanf
_sigfe_vswscanf:
	leaq	vswscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vsyslog
	.global	_sigfe_vsyslog
	.seh_proc _sigfe_vsyslog
_sigfe_vsyslog:
	leaq	vsyslog(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vwarn
	.global	_sigfe_vwarn
	.seh_proc _sigfe_vwarn
_sigfe_vwarn:
	leaq	vwarn(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vwarnx
	.global	_sigfe_vwarnx
	.seh_proc _sigfe_vwarnx
_sigfe_vwarnx:
	leaq	vwarnx(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vwprintf
	.global	_sigfe_vwprintf
	.seh_proc _sigfe_vwprintf
_sigfe_vwprintf:
	leaq	vwprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	vwscanf
	.global	_sigfe_vwscanf
	.seh_proc _sigfe_vwscanf
_sigfe_vwscanf:
	leaq	vwscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wait
	.global	_sigfe_wait
	.seh_proc _sigfe_wait
_sigfe_wait:
	leaq	wait(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wait3
	.global	_sigfe_wait3
	.seh_proc _sigfe_wait3
_sigfe_wait3:
	leaq	wait3(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wait4
	.global	_sigfe_wait4
	.seh_proc _sigfe_wait4
_sigfe_wait4:
	leaq	wait4(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	waitpid
	.global	_sigfe_waitpid
	.seh_proc _sigfe_waitpid
_sigfe_waitpid:
	leaq	waitpid(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	warn
	.global	_sigfe_warn
	.seh_proc _sigfe_warn
_sigfe_warn:
	leaq	warn(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	warnx
	.global	_sigfe_warnx
	.seh_proc _sigfe_warnx
_sigfe_warnx:
	leaq	warnx(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wcsftime
	.global	_sigfe_wcsftime
	.seh_proc _sigfe_wcsftime
_sigfe_wcsftime:
	leaq	wcsftime(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wcsftime_l
	.global	_sigfe_wcsftime_l
	.seh_proc _sigfe_wcsftime_l
_sigfe_wcsftime_l:
	leaq	wcsftime_l(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wprintf
	.global	_sigfe_wprintf
	.seh_proc _sigfe_wprintf
_sigfe_wprintf:
	leaq	wprintf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	write
	.global	_sigfe_write
	.seh_proc _sigfe_write
_sigfe_write:
	leaq	write(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	writev
	.global	_sigfe_writev
	.seh_proc _sigfe_writev
_sigfe_writev:
	leaq	writev(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	wscanf
	.global	_sigfe_wscanf
	.seh_proc _sigfe_wscanf
_sigfe_wscanf:
	leaq	wscanf(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_array
	.global	_sigfe_xdr_array
	.seh_proc _sigfe_xdr_array
_sigfe_xdr_array:
	leaq	xdr_array(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_bool
	.global	_sigfe_xdr_bool
	.seh_proc _sigfe_xdr_bool
_sigfe_xdr_bool:
	leaq	xdr_bool(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_bytes
	.global	_sigfe_xdr_bytes
	.seh_proc _sigfe_xdr_bytes
_sigfe_xdr_bytes:
	leaq	xdr_bytes(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_char
	.global	_sigfe_xdr_char
	.seh_proc _sigfe_xdr_char
_sigfe_xdr_char:
	leaq	xdr_char(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_double
	.global	_sigfe_xdr_double
	.seh_proc _sigfe_xdr_double
_sigfe_xdr_double:
	leaq	xdr_double(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_enum
	.global	_sigfe_xdr_enum
	.seh_proc _sigfe_xdr_enum
_sigfe_xdr_enum:
	leaq	xdr_enum(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_float
	.global	_sigfe_xdr_float
	.seh_proc _sigfe_xdr_float
_sigfe_xdr_float:
	leaq	xdr_float(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_free
	.global	_sigfe_xdr_free
	.seh_proc _sigfe_xdr_free
_sigfe_xdr_free:
	leaq	xdr_free(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_hyper
	.global	_sigfe_xdr_hyper
	.seh_proc _sigfe_xdr_hyper
_sigfe_xdr_hyper:
	leaq	xdr_hyper(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_int
	.global	_sigfe_xdr_int
	.seh_proc _sigfe_xdr_int
_sigfe_xdr_int:
	leaq	xdr_int(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_int16_t
	.global	_sigfe_xdr_int16_t
	.seh_proc _sigfe_xdr_int16_t
_sigfe_xdr_int16_t:
	leaq	xdr_int16_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_int32_t
	.global	_sigfe_xdr_int32_t
	.seh_proc _sigfe_xdr_int32_t
_sigfe_xdr_int32_t:
	leaq	xdr_int32_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_int64_t
	.global	_sigfe_xdr_int64_t
	.seh_proc _sigfe_xdr_int64_t
_sigfe_xdr_int64_t:
	leaq	xdr_int64_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_int8_t
	.global	_sigfe_xdr_int8_t
	.seh_proc _sigfe_xdr_int8_t
_sigfe_xdr_int8_t:
	leaq	xdr_int8_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_long
	.global	_sigfe_xdr_long
	.seh_proc _sigfe_xdr_long
_sigfe_xdr_long:
	leaq	xdr_long(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_longlong_t
	.global	_sigfe_xdr_longlong_t
	.seh_proc _sigfe_xdr_longlong_t
_sigfe_xdr_longlong_t:
	leaq	xdr_longlong_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_netobj
	.global	_sigfe_xdr_netobj
	.seh_proc _sigfe_xdr_netobj
_sigfe_xdr_netobj:
	leaq	xdr_netobj(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_opaque
	.global	_sigfe_xdr_opaque
	.seh_proc _sigfe_xdr_opaque
_sigfe_xdr_opaque:
	leaq	xdr_opaque(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_pointer
	.global	_sigfe_xdr_pointer
	.seh_proc _sigfe_xdr_pointer
_sigfe_xdr_pointer:
	leaq	xdr_pointer(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_reference
	.global	_sigfe_xdr_reference
	.seh_proc _sigfe_xdr_reference
_sigfe_xdr_reference:
	leaq	xdr_reference(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_short
	.global	_sigfe_xdr_short
	.seh_proc _sigfe_xdr_short
_sigfe_xdr_short:
	leaq	xdr_short(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_sizeof
	.global	_sigfe_xdr_sizeof
	.seh_proc _sigfe_xdr_sizeof
_sigfe_xdr_sizeof:
	leaq	xdr_sizeof(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_string
	.global	_sigfe_xdr_string
	.seh_proc _sigfe_xdr_string
_sigfe_xdr_string:
	leaq	xdr_string(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_char
	.global	_sigfe_xdr_u_char
	.seh_proc _sigfe_xdr_u_char
_sigfe_xdr_u_char:
	leaq	xdr_u_char(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_hyper
	.global	_sigfe_xdr_u_hyper
	.seh_proc _sigfe_xdr_u_hyper
_sigfe_xdr_u_hyper:
	leaq	xdr_u_hyper(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_int
	.global	_sigfe_xdr_u_int
	.seh_proc _sigfe_xdr_u_int
_sigfe_xdr_u_int:
	leaq	xdr_u_int(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_int16_t
	.global	_sigfe_xdr_u_int16_t
	.seh_proc _sigfe_xdr_u_int16_t
_sigfe_xdr_u_int16_t:
	leaq	xdr_u_int16_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_int32_t
	.global	_sigfe_xdr_u_int32_t
	.seh_proc _sigfe_xdr_u_int32_t
_sigfe_xdr_u_int32_t:
	leaq	xdr_u_int32_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_int64_t
	.global	_sigfe_xdr_u_int64_t
	.seh_proc _sigfe_xdr_u_int64_t
_sigfe_xdr_u_int64_t:
	leaq	xdr_u_int64_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_int8_t
	.global	_sigfe_xdr_u_int8_t
	.seh_proc _sigfe_xdr_u_int8_t
_sigfe_xdr_u_int8_t:
	leaq	xdr_u_int8_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_long
	.global	_sigfe_xdr_u_long
	.seh_proc _sigfe_xdr_u_long
_sigfe_xdr_u_long:
	leaq	xdr_u_long(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_longlong_t
	.global	_sigfe_xdr_u_longlong_t
	.seh_proc _sigfe_xdr_u_longlong_t
_sigfe_xdr_u_longlong_t:
	leaq	xdr_u_longlong_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_u_short
	.global	_sigfe_xdr_u_short
	.seh_proc _sigfe_xdr_u_short
_sigfe_xdr_u_short:
	leaq	xdr_u_short(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_uint16_t
	.global	_sigfe_xdr_uint16_t
	.seh_proc _sigfe_xdr_uint16_t
_sigfe_xdr_uint16_t:
	leaq	xdr_uint16_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_uint32_t
	.global	_sigfe_xdr_uint32_t
	.seh_proc _sigfe_xdr_uint32_t
_sigfe_xdr_uint32_t:
	leaq	xdr_uint32_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_uint64_t
	.global	_sigfe_xdr_uint64_t
	.seh_proc _sigfe_xdr_uint64_t
_sigfe_xdr_uint64_t:
	leaq	xdr_uint64_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_uint8_t
	.global	_sigfe_xdr_uint8_t
	.seh_proc _sigfe_xdr_uint8_t
_sigfe_xdr_uint8_t:
	leaq	xdr_uint8_t(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_union
	.global	_sigfe_xdr_union
	.seh_proc _sigfe_xdr_union
_sigfe_xdr_union:
	leaq	xdr_union(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_vector
	.global	_sigfe_xdr_vector
	.seh_proc _sigfe_xdr_vector
_sigfe_xdr_vector:
	leaq	xdr_vector(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_void
	.global	_sigfe_xdr_void
	.seh_proc _sigfe_xdr_void
_sigfe_xdr_void:
	leaq	xdr_void(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdr_wrapstring
	.global	_sigfe_xdr_wrapstring
	.seh_proc _sigfe_xdr_wrapstring
_sigfe_xdr_wrapstring:
	leaq	xdr_wrapstring(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdrmem_create
	.global	_sigfe_xdrmem_create
	.seh_proc _sigfe_xdrmem_create
_sigfe_xdrmem_create:
	leaq	xdrmem_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdrrec_create
	.global	_sigfe_xdrrec_create
	.seh_proc _sigfe_xdrrec_create
_sigfe_xdrrec_create:
	leaq	xdrrec_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdrrec_endofrecord
	.global	_sigfe_xdrrec_endofrecord
	.seh_proc _sigfe_xdrrec_endofrecord
_sigfe_xdrrec_endofrecord:
	leaq	xdrrec_endofrecord(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdrrec_eof
	.global	_sigfe_xdrrec_eof
	.seh_proc _sigfe_xdrrec_eof
_sigfe_xdrrec_eof:
	leaq	xdrrec_eof(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdrrec_skiprecord
	.global	_sigfe_xdrrec_skiprecord
	.seh_proc _sigfe_xdrrec_skiprecord
_sigfe_xdrrec_skiprecord:
	leaq	xdrrec_skiprecord(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

	.extern	xdrstdio_create
	.global	_sigfe_xdrstdio_create
	.seh_proc _sigfe_xdrstdio_create
_sigfe_xdrstdio_create:
	leaq	xdrstdio_create(%rip),%r10
	pushq	%r10
	.seh_pushreg %r10
	.seh_endprologue
	jmp	_sigfe
	.seh_endproc

