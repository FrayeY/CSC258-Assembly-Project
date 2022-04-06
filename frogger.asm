#####################################################################
#
# CSC258H1S Winter 2022 Assembly Final Project
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
# - Milestone 1
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

    # colors
        color_safe:     .word 0x84c011
        color_water:    .word 0x06b7f2
        color_log:      .word 0x8f3f07
        color_middle:   .word 0xf2c043
        color_road:     .word 0x555555
        color_car:      .word 0xfb1919
        color_frog:     .word 0xe10cf6

    # positions
        frog:           .half 60
        frogdir:        .byte 0   # 0 for up (default), 1 for left, 2 for down, 3 for right
        log1:           .half 17
        log2:           .half 21
        log3:           .half 26
        log4:           .half 30
        car1:           .half 40
        car2:           .half 44
        car3:           .half 51
        car4:           .half 55

    # gamestates
        paused:         .byte 0   # whether the game is paused, 0 by default
.text
GAMELOOP:
        jal DRAW_BACKGROUND       # call function DRAW_BACKGROUND

        # handle keyboard input
        lw $t8, 0xffff0000
        beq $t8, 1, KEYSTROKE
        j NOKEYSTROKE
  KEYSTROKE:
        jal INPUT                 # call function to handle input in the event of a keystroke
  NOKEYSTROKE:

        jal DRAW_LOGS             # call function to draw 4 logs
        jal DRAW_CARS             # call function to draw 4 cars
        # draw frog
        lh $a0, frog              # load location of frog
        jal CONVERT               # call CONVERT function
        jal DRAW_FROG             # draw frog at $a0

        li $v0, 32                # sleep
        li $a0, 140               #   for 140 milliseconds before looping
        syscall                   #   (achieving roughly 6 fps)
        j GAMELOOP
Exit:
        li $v0, 10                # terminate the program gracefully
        syscall


# drawing functions
  DRAW_BACKGROUND:
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          # Goal region
          li $a0, 0                 # goal region starts in the top left
          li $a1, 32                # width is 32
          li $a2, 8                 # height is 8
          lw $a3, color_safe        # goal region color
          jal DRAW_RECTANGLE        # draw rectangle

          # Water region
          li $a0, 256               # water region starts on the third big row
          li $a1, 32                # width is 32
          li $a2, 8                 # height is 8
          lw $a3, color_water       # water region color
          jal DRAW_RECTANGLE        # draw rectangle

          # Middle safe region
          li $a0, 512               # middle region starts on the fifth big row
          li $a1, 32                # width is 32
          li $a2, 4                 # height is 4
          lw $a3, color_middle      # middle safe region color
          jal DRAW_RECTANGLE        # draw rectangle

          # Road region
          li $a0, 640               # road region starts on the sixth big row
          li $a1, 32                # width is 32
          li $a2, 8                 # height is 8
          lw $a3, color_road        # road region color
          jal DRAW_RECTANGLE        # draw rectangle

          # Start region
          li $a0, 896               # start region starts on the eighth big row
          li $a1, 32                # width is 32
          li $a2, 8                 # height is 8
          lw $a3, color_safe        # road region color
          jal DRAW_RECTANGLE        # draw rectangle

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_RECTANGLE:                   # $a0, $a1, $a2, $a3 store the position addr, width, height, and color of the rectangle respectively
          li $t8, 0                 # vertical iteration index $t8 = 0
          li $t5, 32                # units per horizontal line
          div $a0, $t5              # position addr / 32
          mfhi $t6                  # horizontal (unit) coordinate of rectangle
    VERTICAL_LOOP:
          beq $t8, $a2, VERTICAL_END # done loop if $t8 = $a2
          sll $t4, $t8, 5           # $t4 = $t8 * 32 = offset to move down $t8 rows
          li $t9, 0                 # horizontal iteration index $t9 = 0
      HORIZONTAL_LOOP:
          beq $t9, $a1, HORIZONTAL_END # done loop if $t9 = $a1
          lw $t0, displayAddress    # $t0 stores the base address for display
          add $t7, $a0, $t9         # $t7 = $a0 + $t9 = (unit) coordinate of current "cursor" position (before vertical displacement)
          add $t7, $t7, $t4         # $t7 = $t7 + $t4 = (unit) coordinate of current "cursor" position (after vertical displacement)

          add $t1, $t9, $t6         # temporary value to check wrap
          bge $t1, $t5, WRAP        # if $t7 >= $t5 = 32 then WRAP
          j NOWRAP                  # jump to NOWRAP
        WRAP:
          sub $t7, $t7, $t5         # $t7 = $t7 - 32
        NOWRAP:
          sll $t7, $t7, 2           # $t7 = $t7 * 4 = offset
          add $t7, $t0, $t7         # $t7 = $t0 + $t7,  actual address is relative to $t0
          sw $a3, 0($t7)            # paint the $t7 unit $a3 colour
          addi $t9, $t9, 1          # $t9 = $t9 + 1
          j HORIZONTAL_LOOP         # jump back to start of loop
      HORIZONTAL_END:
          addi $t8, $t8, 1          # $t8 = $t8 + 1
          j VERTICAL_LOOP           # jump back to start of loop
    VERTICAL_END:
          jr $ra                    # return
  DRAW_FROG:                        # $a0 and $a1 store the position addr and direction (TODO) of the frog respectively
          lw $t0, displayAddress    # $t0 stores the base address for display
          sll $t1, $a0, 2           # $t1 = $a0 * 4 = offset
          add $t0, $t0, $t1         # $t0 stores the base address of the frog
          lw $t2, color_frog        # $t1 stores the color of the frog

          sw $t2, 0($t0)            # first row |x__x|
          sw $t2, 12($t0)

          sw $t2, 128($t0)          # second row |xxxx|
          sw $t2, 132($t0)
          sw $t2, 136($t0)
          sw $t2, 140($t0)

          sw $t2, 260($t0)          # third row |_xx_|
          sw $t2, 264($t0)

          sw $t2, 384($t0)          # fourth row |xxxx|
          sw $t2, 388($t0)
          sw $t2, 392($t0)
          sw $t2, 396($t0)

          jr $ra                    # return
  DRAW_LOG:                         # $a0 and $a1 store the position addr and width of the log respectively
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a2, 4                 # height of log is always 4
          lw $a3, color_log         # log color
          jal DRAW_RECTANGLE        # draw log as rectangle, $a0 and $a1 are set already by the caller

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_LOGS:
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a1, 8                 # width of log is 8
          lh $a0, log1              # load location of log1
          jal CONVERT               # call CONVERT function
          jal DRAW_LOG
          lh $a0, log2              # load location of log2
          jal CONVERT               # call CONVERT function
          jal DRAW_LOG
          lh $a0, log3              # load location of log3
          jal CONVERT               # call CONVERT function
          jal DRAW_LOG
          lh $a0, log4              # load location of log4
          jal CONVERT               # call CONVERT function
          jal DRAW_LOG

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_CAR:                         # $a0 and $a1 store the position addr and width of the car respectively
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a2, 4                 # height of log is always 4
          lw $a3, color_car         # car color
          jal DRAW_RECTANGLE        # draw car as rectangle, $a0 and $a1 are set already by the caller

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_CARS:
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a1, 8                 # width of car is 8
          lh $a0, car1              # load location of car1
          jal CONVERT               # call CONVERT function
          jal DRAW_CAR
          lh $a0, car2              # load location of car2
          jal CONVERT               # call CONVERT function
          jal DRAW_CAR
          lh $a0, car3              # load location of car3
          jal CONVERT               # call CONVERT function
          jal DRAW_CAR
          lh $a0, car4              # load location of car4
          jal CONVERT               # call CONVERT function
          jal DRAW_CAR

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  CONVERT:                          # convert 8x8 tile position $a0 to 32x32 unit position (store value at same register)
          li $t0, 8                 # 8 tiles per row
          div $a0, $t0              # $a0 / 8
          mflo  $t1                 # $t1 = floor($a0 / 8)
          mfhi  $t2                 # $t2 = $a0 mod 8
          sll $t1, $t1, 7           # 128 units per tile row
          sll $t2, $t2, 2           # 4 units per top of each tile
          add $a0, $t1, $t2         # $v0 is top left unit of corresponding tile in grid
          jr $ra                    # return

INPUT:
        lh $t1, frog                # load current frog position
        lw $t2, 0xffff0004          # load ASCII value of pressed key into $t2
        beq $t2, 0x70, respong_to_p
        beq $t2, 0x77, respond_to_w
        beq $t2, 0x61, respond_to_a
	      beq $t2, 0x73, respond_to_s
        beq $t2, 0x64, respond_to_d
        j END_INPUT                 # if none of branch cases match, invalid input, ignore
  respong_to_p:
        j END_INPUT                 # TODO
  respond_to_w:
        li $t3, 0                   # frogdir = 0 indicates upward direction
        addi $t1, $t1, -8           # -8 from position
        sh $t1, frog                #   is moving up 1 tile
        sb $t3, frogdir
        j END_INPUT
  respond_to_a:
        li $t3, 1                   # frogdir = 1 indicates leftward direction
        addi $t1, $t1, -1           # -1 from position
        sh $t1, frog                #   is moving left 1 tile
        sb $t3, frogdir
        j END_INPUT
  respond_to_s:
        li $t3, 2                   # frogdir = 2 indicates downward direction
        addi $t1, $t1, 8            # +8 of position
        sh $t1, frog                #   is moving down 1 tile
        sb $t3, frogdir
        j END_INPUT
  respond_to_d:
        li $t3, 3                   # frogdir = 3 indicates rightward direction
        addi $t1, $t1, 1            # +1 of position
        sh $t1, frog                #   is moving right 1 tile
        sb $t3, frogdir
        j END_INPUT
  END_INPUT:
        jr $ra                      # return
