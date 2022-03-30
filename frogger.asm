#####################################################################
#
# CSC258H5S Winter 2022 Assembly Final Project
# University of Toronto, St. George
#
# Student: Franklin Yeung, 1007100101
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 0
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################

.data
        displayAddress: .word 0x10008000
.text
        lw $t0, displayAddress    # $t0 stores the base address for display
        li $t1, 0xff0000          # $t1 stores the red colour code
        li $t2, 0x00ff00          # $t2 stores the green colour code
        li $t3, 0x0000ff          # $t3 stores the blue colour code
GAMELOOP:
        jal DRAW_BACKGROUND       # call function DRAW_BACKGROUND
        # sw $t1, 0($t0)            # paint the first (top-left) unit red.
        # sw $t2, 4($t0)            # paint the second unit on the first row green. Why $t0+4?
        # sw $t3, 128($t0)          # paint the first unit on the second row blue. Why +128?
Exit:
        li $v0, 10                # terminate the program gracefully
        syscall

DRAW_BACKGROUND:
        addi $sp, $sp, -4         # put $ra value
        sw $ra, 0($sp)            #   onto stack
        li $a0, 128                 # first rectangle starts in the top left
        li $a1, 24                # width is 32
        li $a2, 8                 # height is 8
        move $a3, $t2             # goal region is green
        jal DRAW_RECTANGLE        # draw rectangle
        lw $ra, 0($sp)            # restore return
        addi $sp, $sp, 4          #   address value
        jr $ra                    # return

DRAW_RECTANGLE:                   # $a0, $a1, $a2, $a3 store the position addr , width, height, and colour of the rectangle respectively
        li $t9, 0                 # horizontal iteration index $t9 = 0
        li $t8, 0                 # vertical iteration index $t8 = 0
        li $t5, 32                # units per horizontal line
        div $a0, $t5              # position addr / 32
        mfhi $t6                  # horizontal (unit) coordinate of rectangle
  VERTICAL_LOOP:
        beq $t8, $a2, VERTICAL_END # done loop if $t8 = $a2
        mult $t8, $t5
        mflo $t4
    HORIZONTAL_LOOP:
        beq $t9, $a1, HORIZONTAL_END # done loop if $t9 = $a1
        add $t7, $t6, $t9         # $t7 = $t6 + $t9 = horizontal (unit) coordinate of current "cursor" position
        bge $t7, $t5, WRAP        # if $t7 >= $t5 = 32 then WRAP
        j NOWRAP                  # jump to NOWRAP
      WRAP:
        sub $t7, $t7, $t5        # $t7 = $t7 - 32
      NOWRAP:
      	add $t7, $a0, $t7         # coordinate relative to $a0
        add $t7, $t7, $t4         # $t7 = $t7 + $t4 = (unit) coordinate of current "cursor" position
        sll $t7, $t7, 2           # $t7 = $t7 * 4 = offset
        add $t7, $t0, $t7         # $t7 = $t0 + $t7,  actual address is relative to $t0
        sw $a3, 0($t7)            # paint the $t7 unit $a3 colour
        addi $t9, $t9, 1          # $t9 = $t9 + 1
        j HORIZONTAL_LOOP         # jump back to start of loop
    HORIZONTAL_END:

        addi $t8, $t8, 1          # $t8 = $t8 + 1
        j VERTICAL_LOOP         # jump back to start of loop
  VERTICAL_END:
        jr $ra
