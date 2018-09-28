/*************************************************************************
 *
 * Startup Code (reset vector)
 *
 * Do important init only if we don't start from memory!
 * Setup memory and board specific bits prior to relocation.
 * Relocate armboot to ram. Setup stack.
 *
 *************************************************************************/

	.globl  reset
        .globl  save_boot_params_ret
        .type   save_boot_params_ret,%function

reset:
        /* Allow the board to save important registers */
        b       save_boot_params

save_boot_params_ret:

/*
 * disable interrupts (FIQ and IRQ), also set the cpu to SVC32 mode,
 * except if in HYP mode already
 * check for hypervisor mode is made here, refer to start.S main filr
 * for more details
 * mrc implies read
 */

	mrs     r0, cpsr
        bicne   r0, r0, #0x1f           @ clear all mode bits
        orrne   r0, r0, #0x13           @ set SVC mode
        orr     r0, r0, #0xc0           @ disable FIQ and IRQ
        msr     cpsr,r0

/* Set V=0 bit in CP15 SCTLR register - for VBAR to point to vector 
   implies normal exception vectors selected, not high exception vectors */

	mrc     p15, 0, r0, c1, c0, 0   @ Read CP15 control Register
        bic     r0, #0x2000             @ V bit cleares => normal exception vectors selected, not high exception vectors
        mcr     p15, 0, r0, c1, c0, 0   @ Write CP15 SCTLR Register

/* Set vector address in CP15 VBAR register 
 * r0 is loaded with address of _start symbol 
 * and it is written in c12 which is VBAR register
 * _start is the entry point for this binary
 * in vector.S it is defined as global symbol and contains exception vectors
 */

        ldr     r0, =_start
        mcr     p15, 0, r0, c12, c0, 0  @Set VBAR

	bl      cpu_init_cp15
	bl      cpu_init_crit

	bl	_main

/*
 * cpu_init_cp15
 *
 * Setup CP15 registers (cache, MMU, TLBs). The I-cache is turned on unless
 * CONFIG_SYS_ICACHE_OFF is defined. here I-cache is turned on
 * mcr => write into registers
 */

ENTRY(cpu_init_cp15)
/*
 * Invalidate L1 I/D
 * research on the sequence how to do this - may be later
 */
        mov     r0, #0                  @ set up for MCR
        mcr     p15, 0, r0, c8, c7, 0   @ invalidate instruction and data TLBs
        mcr     p15, 0, r0, c7, c5, 0   @ invalidate icache
        mcr     p15, 0, r0, c7, c5, 6   @ invalidate BP array
        mcr     p15, 0, r0, c7, c10, 4  @ DSB operation
        mcr     p15, 0, r0, c7, c5, 4   @ ISB operation

/*
 * disable MMU stuff and caches
 * summary: disable MMU, data caches, use normal exception vector, decided by VBAR
 * enable instruction cache, program flow prediction and strict alignment
 */
        mrc     p15, 0, r0, c1, c0, 0   @ read c1 into r0
        bic     r0, r0, #0x00002000     @ clear bits 13 (--V-)
        bic     r0, r0, #0x00000007     @ clear bits 2:0 (-CAM)
        orr     r0, r0, #0x00000002     @ set bit 1 (--A-) Align
        orr     r0, r0, #0x00000800     @ set bit 11 (Z---) BTB
	orr     r0, r0, #0x00001000     @ set bit 12 (I) I-cache
	mcr     p15, 0, r0, c1, c0, 0   @ write r0 into c1

	mov     r5, lr                  @ Store my Caller - bl cpu_init_cp15 - above
        mrc     p15, 0, r1, c0, c0, 0   @ r1 has Read Main ID Register (MIDR)
        mov     r3, r1, lsr #20         @ get variant field
        and     r3, r3, #0xf            @ r3 has CPU variant
        and     r4, r1, #0xf            @ r4 has CPU revision
        mov     r2, r3, lsl #4          @ shift variant field for combined value
        orr     r2, r4, r2              @ r2 has combined CPU variant + revision


	mrc     p15, 0, r0, c1, c0, 1   @ Read Auxiliary Control Reg
	orr     r0, r0, #(0x1 << 6)     @ Set IBE bit always to enable OS WA
	push    {r1-r5}                 @ Save the cpu info registers
        bl      v7_arch_cp15_set_acr
        pop     {r1-r5}                 @ Restore the cpu info - fall through

	mov     pc, r5                  @ back to my caller
ENDPROC(cpu_init_cp15)

/*
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 */

ENTRY(cpu_init_crit)
        /*
         * Jump to board specific initialization...
         * The Mask ROM will have already initialized
         * basic memory. Go here to bump up clock rate and handle
         * wake up conditions.
         */
        b       lowlevel_init           @ go setup pll,mux,memory
ENDPROC(cpu_init_crit)
