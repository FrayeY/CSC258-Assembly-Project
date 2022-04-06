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
# - Milestone 5
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. Displaying a pause screen or image when the 'p' key is pressed, and returning to the game when 'p' is pressed again.
# 2. Make the frog point in the direction that it's traveling.
# 3. Have objects in different rows move at different speeds.
# 4. After final player death, display game over/retry screen. Restart the game if the "retry" option is chosen.
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

        faded_safe:     .word 0x6f7e53
        faded_water:    .word 0x5e8b99
        faded_log:      .word 0x5c483a
        faded_middle:   .word 0xb0a485
        faded_road:     .word 0x555555
        faded_car:      .word 0xa66e6e
        faded_frog:     .word 0x99649e

        filled_goal:    .word 0xffd700
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
    # frequencies and counters to implement movement of obstacles
        freq_log_row1:  .half 15
        count_log_row1: .half 0
        freq_log_row2:  .half 12
        count_log_row2: .half 0
        freq_car_row1:  .half 16
        count_car_row1: .half 0
        freq_car_row2:  .half 9
        count_car_row2: .half 0
    # gamestates
        # paused:         .byte 0   # whether the game is paused, 0 by default
        lives:          .byte 3   # number of lives left, initialized to 3
        goal1:          .byte 0   # whether a frog has reached this goal region (tile 8)
        goal2:          .byte 0   # whether a frog has reached this goal region (tile 10)
        goal3:          .byte 0   # whether a frog has reached this goal region (tile 12)
        goal4:          .byte 0   # whether a frog has reached this goal region (tile 13)
        goal5:          .byte 0   # whether a frog has reached this goal region (tile 15)

.text
GAMELOOP:
        # handle keyboard input
        lw $t8, 0xffff0000
        beq $t8, 1, KEYSTROKE
        j NOKEYSTROKE
  KEYSTROKE:
        jal INPUT                 # call function to handle input in the event of a keystroke
  NOKEYSTROKE:
        jal CHECK_COLLIDE         # check for collisions
        jal MOVE_OBSTACLES        # move obstacles which should move this cycle
        jal DRAW_BACKGROUND       # call function DRAW_BACKGROUND
        jal DRAW_FILLED_GOALS     # call function to draw goals which are filled
        jal DRAW_LOGS             # call function to draw 4 logs
        jal DRAW_CARS             # call function to draw 4 cars
        # draw frog
        lh $a0, frog              # load location of frog
        jal CONVERT               # call CONVERT function
        jal DRAW_FROG             # draw frog at its location
        jal CHECK_WIN

        li $v0, 32                # sleep syscall
        li $a0, 140               #   for 140 milliseconds before looping
        syscall                   #   (achieving roughly 6 fps)
        j GAMELOOP
  PAUSELOOP:
        # handle keyboard input
        lw $t8, 0xffff0000
        bne $t8, 1, PAUSELOOP
        lw $t2, 0xffff0004        # load ASCII value of pressed key into $t2
        beq $t2, 0x70, UNPAUSE    # if 'p' pressed, unpause
        j PAUSELOOP
    UNPAUSE:
        j GAMELOOP
LOSE:
        # end/restart page
        li $a0, 0
        li $a1, 32                # width is 32
        li $a2, 32                # height is 32
        li $a3, 0xff0000          # red color
        jal DRAW_RECTANGLE        # draw rectangle
  LOSELOOP:
        # handle keyboard input
        lw $t8, 0xffff0000
        bne $t8, 1, LOSELOOP
        lw $t2, 0xffff0004        # load ASCII value of pressed key into $t2
        beq $t2, 0x65, END        # if 'e' pressed, end
        beq $t2, 0x72, RESTART    # if 'r' pressed, restart
        j LOSELOOP
WIN:
        # win page
        li $a0, 0
        li $a1, 32                # width is 32
        li $a2, 32                # height is 32
        li $a3, 0xffd700          # gold color
        jal DRAW_RECTANGLE        # draw rectangle
        j END
END:
        li $v0, 32                # sleep syscall
        li $a0, 5000              #   for 5000 milliseconds before terminating
        syscall
        li $v0, 10                # terminate the program gracefully
        syscall
RESTART:
        li $t0, 3                 # default number of lives
        sb $t0, lives             # reset to 3 lives
        li $t0, 60                # default location of frog
        sh $t0, frog              # set location of frog
        j GAMELOOP
# drawing functions
  DRAW_PAUSE_BACKGROUND:
        addi $sp, $sp, -4         # put $ra value
        sw $ra, 0($sp)            #   onto stack

        # Goal region
        li $a0, 0                 # goal region starts in the top left
        li $a1, 32                # width is 32
        li $a2, 8                 # height is 8
        lw $a3, faded_safe        # goal region color
        jal DRAW_RECTANGLE        # draw rectangle

        # Water region
        li $a0, 256               # water region starts on the third big row
        li $a1, 32                # width is 32
        li $a2, 8                 # height is 8
        lw $a3, faded_water       # water region color
        jal DRAW_RECTANGLE        # draw rectangle

        # Middle safe region
        li $a0, 512               # middle region starts on the fifth big row
        li $a1, 32                # width is 32
        li $a2, 4                 # height is 4
        lw $a3, faded_middle      # middle safe region color
        jal DRAW_RECTANGLE        # draw rectangle

        # Road region
        li $a0, 640               # road region starts on the sixth big row
        li $a1, 32                # width is 32
        li $a2, 8                 # height is 8
        lw $a3, faded_road        # road region color
        jal DRAW_RECTANGLE        # draw rectangle

        # Start region
        li $a0, 896               # start region starts on the eighth big row
        li $a1, 32                # width is 32
        li $a2, 8                 # height is 8
        lw $a3, faded_safe        # road region color
        jal DRAW_RECTANGLE        # draw rectangle

        lw $ra, 0($sp)            # restore return
        addi $sp, $sp, 4          #   address value
        jr $ra                    # return
  DRAW_PAUSE_FROG:                # both the position addr and direction of the frog are stored as variables
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          lw $t0, displayAddress    # $t0 stores the base address for display
          sll $t1, $a0, 2           # $t1 = $a0 * 4 = offset
          add $t0, $t0, $t1         # $t0 stores the base address of the frog
          lw $t2, faded_frog        # $t2 stores the color of the frog
          lb $t3, frogdir           # $t3 stores the direction of the frog
          beq $t3, 0, DRAW_PAUSE_FROG_UP
          beq $t3, 1, DRAW_PAUSE_FROG_LEFT
          beq $t3, 2, DRAW_PAUSE_FROG_DOWN
          beq $t3, 3, DRAW_PAUSE_FROG_RIGHT
          j END_DRAW_PAUSE_DIRECTION
    DRAW_PAUSE_FROG_UP:
          sw $t2, 0($t0)            # first row |x--x|
          sw $t2, 12($t0)
          sw $t2, 128($t0)          # second row |xxxx|
          sw $t2, 132($t0)
          sw $t2, 136($t0)
          sw $t2, 140($t0)
          sw $t2, 260($t0)          # third row |-xx-|
          sw $t2, 264($t0)
          sw $t2, 384($t0)          # fourth row |xxxx|
          sw $t2, 388($t0)
          sw $t2, 392($t0)
          sw $t2, 396($t0)
          j END_DRAW_PAUSE_DIRECTION
    DRAW_PAUSE_FROG_LEFT:
          sw $t2, 0($t0)            # first row |xx-x|
          sw $t2, 4($t0)
          sw $t2, 12($t0)
          sw $t2, 132($t0)          # second row |-xxx|
          sw $t2, 136($t0)
          sw $t2, 140($t0)
          sw $t2, 260($t0)          # third row |-xxx|
          sw $t2, 264($t0)
          sw $t2, 268($t0)
          sw $t2, 384($t0)          # fourth row |xx-x|
          sw $t2, 388($t0)
          sw $t2, 396($t0)
          j END_DRAW_PAUSE_DIRECTION
    DRAW_PAUSE_FROG_DOWN:
          sw $t2, 0($t0)            # first row |xxxx|
          sw $t2, 4($t0)
          sw $t2, 8($t0)
          sw $t2, 12($t0)
          sw $t2, 132($t0)          # second row |-xx-|
          sw $t2, 136($t0)
          sw $t2, 256($t0)          # third row |xxxx|
          sw $t2, 260($t0)
          sw $t2, 264($t0)
          sw $t2, 268($t0)
          sw $t2, 384($t0)          # fourth row |x--x|
          sw $t2, 396($t0)
          j END_DRAW_PAUSE_DIRECTION
    DRAW_PAUSE_FROG_RIGHT:
          sw $t2, 0($t0)            # first row |x-xx|
          sw $t2, 8($t0)
          sw $t2, 12($t0)
          sw $t2, 128($t0)          # second row |xxx-|
          sw $t2, 132($t0)
          sw $t2, 136($t0)
          sw $t2, 256($t0)          # third row |xxx-|
          sw $t2, 260($t0)
          sw $t2, 264($t0)
          sw $t2, 384($t0)          # fourth row |x-xx|
          sw $t2, 392($t0)
          sw $t2, 396($t0)
          j END_DRAW_PAUSE_DIRECTION
    END_DRAW_PAUSE_DIRECTION:
          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_PAUSE_LOG:                 # $a0 and $a1 store the position addr and width of the log respectively
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a2, 4                 # height of log is always 4
          lw $a3, faded_log         # log color
          jal DRAW_RECTANGLE        # draw log as rectangle, $a0 and $a1 are set already by the caller

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_PAUSE_LOGS:
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a1, 8                 # width of log is 8
          lh $a0, log1              # load location of log1
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_LOG
          lh $a0, log2              # load location of log2
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_LOG
          lh $a0, log3              # load location of log3
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_LOG
          lh $a0, log4              # load location of log4
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_LOG

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_PAUSE_CAR:                 # $a0 and $a1 store the position addr and width of the car respectively
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a2, 4                 # height of log is always 4
          lw $a3, faded_car         # car color
          jal DRAW_RECTANGLE        # draw car as rectangle, $a0 and $a1 are set already by the caller

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_PAUSE_CARS:
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          li $a1, 8                 # width of car is 8
          lh $a0, car1              # load location of car1
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_CAR
          lh $a0, car2              # load location of car2
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_CAR
          lh $a0, car3              # load location of car3
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_CAR
          lh $a0, car4              # load location of car4
          jal CONVERT               # call CONVERT function
          jal DRAW_PAUSE_CAR

          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
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
  DRAW_RECTANGLE:                 # $a0, $a1, $a2, $a3 store the position addr, width, height, and color of the rectangle respectively
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
  DRAW_FROG:                      # both the position addr and direction of the frog are stored as variables
          addi $sp, $sp, -4         # put $ra value
          sw $ra, 0($sp)            #   onto stack

          lw $t0, displayAddress    # $t0 stores the base address for display
          # lh $a0, frog              # position of frog
          # jal CONVERT               # convert grid position to unit position
          sll $t1, $a0, 2           # $t1 = $a0 * 4 = offset
          add $t0, $t0, $t1         # $t0 stores the base address of the frog
          lw $t2, color_frog        # $t2 stores the color of the frog
          lb $t3, frogdir           # $t3 stores the direction of the frog
          beq $t3, 0, DRAW_FROG_UP
          beq $t3, 1, DRAW_FROG_LEFT
          beq $t3, 2, DRAW_FROG_DOWN
          beq $t3, 3, DRAW_FROG_RIGHT
          j END_DRAW_DIRECTION
    DRAW_FROG_UP:
          sw $t2, 0($t0)            # first row |x--x|
          sw $t2, 12($t0)
          sw $t2, 128($t0)          # second row |xxxx|
          sw $t2, 132($t0)
          sw $t2, 136($t0)
          sw $t2, 140($t0)
          sw $t2, 260($t0)          # third row |-xx-|
          sw $t2, 264($t0)
          sw $t2, 384($t0)          # fourth row |xxxx|
          sw $t2, 388($t0)
          sw $t2, 392($t0)
          sw $t2, 396($t0)
          j END_DRAW_DIRECTION
    DRAW_FROG_LEFT:
          sw $t2, 0($t0)            # first row |xx-x|
          sw $t2, 4($t0)
          sw $t2, 12($t0)
          sw $t2, 132($t0)          # second row |-xxx|
          sw $t2, 136($t0)
          sw $t2, 140($t0)
          sw $t2, 260($t0)          # third row |-xxx|
          sw $t2, 264($t0)
          sw $t2, 268($t0)
          sw $t2, 384($t0)          # fourth row |xx-x|
          sw $t2, 388($t0)
          sw $t2, 396($t0)
          j END_DRAW_DIRECTION
    DRAW_FROG_DOWN:
          sw $t2, 0($t0)            # first row |xxxx|
          sw $t2, 4($t0)
          sw $t2, 8($t0)
          sw $t2, 12($t0)
          sw $t2, 132($t0)          # second row |-xx-|
          sw $t2, 136($t0)
          sw $t2, 256($t0)          # third row |xxxx|
          sw $t2, 260($t0)
          sw $t2, 264($t0)
          sw $t2, 268($t0)
          sw $t2, 384($t0)          # fourth row |x--x|
          sw $t2, 396($t0)
          j END_DRAW_DIRECTION
    DRAW_FROG_RIGHT:
          sw $t2, 0($t0)            # first row |x-xx|
          sw $t2, 8($t0)
          sw $t2, 12($t0)
          sw $t2, 128($t0)          # second row |xxx-|
          sw $t2, 132($t0)
          sw $t2, 136($t0)
          sw $t2, 256($t0)          # third row |xxx-|
          sw $t2, 260($t0)
          sw $t2, 264($t0)
          sw $t2, 384($t0)          # fourth row |x-xx|
          sw $t2, 392($t0)
          sw $t2, 396($t0)
          j END_DRAW_DIRECTION
    END_DRAW_DIRECTION:
          lw $ra, 0($sp)            # restore return
          addi $sp, $sp, 4          #   address value
          jr $ra                    # return
  DRAW_LOG:                       # $a0 and $a1 store the position addr and width of the log respectively
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
  DRAW_CAR:                       # $a0 and $a1 store the position addr and width of the car respectively
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
  CONVERT:                        # convert 8x8 tile position $a0 to 32x32 unit position (store value at same register)
          li $t0, 8                 # 8 tiles per row
          div $a0, $t0              # $a0 / 8
          mflo  $t1                 # $t1 = floor($a0 / 8)
          mfhi  $t2                 # $t2 = $a0 mod 8
          sll $t1, $t1, 7           # 128 units per tile row
          sll $t2, $t2, 2           # 4 units per top of each tile
          add $a0, $t1, $t2         # $v0 is top left unit of corresponding tile in grid
          jr $ra                    # return
  DRAW_FILLED_GOALS:
        addi $sp, $sp, -4         # put $ra value
        sw $ra, 0($sp)            #   onto stack
        li $a1, 4                 # width is 4
        li $a2, 2                 # height is 2
        lw $a3, filled_goal       # filled goal region color

        lb $t1, goal1
        bne $t1, 1, NO_GOAL_1
        li $a0, 128
        jal DRAW_RECTANGLE        # draw rectangle
    NO_GOAL_1:
        lb $t2, goal2
        bne $t2, 1, NO_GOAL_2
        li $a0, 136
        jal DRAW_RECTANGLE        # draw rectangle
    NO_GOAL_2:
        lb $t3, goal3
        bne $t3, 1, NO_GOAL_3
        li $a0, 144
        jal DRAW_RECTANGLE        # draw rectangle
    NO_GOAL_3:
        lb $t4, goal4
        bne $t4, 1, NO_GOAL_4
        li $a0, 148
        jal DRAW_RECTANGLE        # draw rectangle
    NO_GOAL_4:
        lb $t5, goal5
        bne $t5, 1, NO_GOAL_5
        li $a0, 156
        jal DRAW_RECTANGLE        # draw rectangle
    NO_GOAL_5:

        lw $ra, 0($sp)            # restore return
        addi $sp, $sp, 4          #   address value
        jr $ra                    # return
INPUT:                            # function to execute relevant actions when a keystoke is detected
        lh $t1, frog                # load current frog position
        lw $t2, 0xffff0004          # load ASCII value of pressed key into $t2
        beq $t2, 0x70, respond_to_p
        beq $t2, 0x77, respond_to_w
        beq $t2, 0x61, respond_to_a
	      beq $t2, 0x73, respond_to_s
        beq $t2, 0x64, respond_to_d
        j END_INPUT                 # if none of branch cases match, invalid input, ignore
  respond_to_p:
        jal DRAW_PAUSE_BACKGROUND
        jal DRAW_PAUSE_LOGS
        jal DRAW_PAUSE_CARS
        j PAUSELOOP
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

MOVE_OBSTACLE:                    # $a0, $a1(+1/-1), $a2, and $a3 store the address of the position, the direction, and the frequency of movement of the obstacle
        lh $t0, 0($a0)            # position of obstacle
        li $t9, 8                 # $t9 = 8
        div $t0, $t9
        mfhi $t1                  # $t1 = $t0 % 8 is the horizontal position of the obstacle
        add $t0, $t0, $a1         # new position
        add $t1, $t1, $a1         # new horizontal position
        bgt $t1, 7, OVERFLOW_RIGHT
        blt $t1, 0, OVERFLOW_LEFT
        j NO_OVERFLOW
  OVERFLOW_RIGHT:
        addi $t0, $t0, -8
        j NO_OVERFLOW
  OVERFLOW_LEFT:
        addi $t0, $t0, 8
        j NO_OVERFLOW
  NO_OVERFLOW:
        sh $t0, 0($a0)            # store $a0 back at the $a0 address
        jr $ra

MOVE_OBSTACLES:
        addi $sp, $sp, -4         # put $ra value
        sw $ra, 0($sp)            #   onto stack

        # log row 1
        li $a1, 1                 # move to the right
        lh $a2, freq_log_row1
        lh $t3, count_log_row1    # counter value of log row 1
        addi $t3, $t3, 1          # iterate $t3
        bne $t3, $a2, END_LOG_ROW_1 # move the obstacle only when the counter value is equal to the frequency
        li $t3, 0                 # reset $t3 back to 0
        la $a0, log1              # load the address of the position of log1
        jal MOVE_OBSTACLE
        la $a0, log2              # load the address of the position of log2
        jal MOVE_OBSTACLE

        lh $t5, frog              # position of frog
        li $t9, 8                 # $t9 = 8 = tiles per row
        div $t5, $t9
        mflo $t6                  # $t6 = $t5 / 8 is the row of the frog
        bne $t6, 2, END_LOG_ROW_1 # branch if frog not on this row
        la $a0, frog              # load the address of the position of frog
        jal MOVE_OBSTACLE
  END_LOG_ROW_1:
        sh $t3, count_log_row1    # store $t3 back at the counter address

        # log row 2
        li $a1, -1                 # move to the left
        lh $a2, freq_log_row2
        lh $t3, count_log_row2    # counter value of log row 2
        addi $t3, $t3, 1          # iterate $t3
        bne $t3, $a2, END_LOG_ROW_2 # move the obstacle only when the counter value is equal to the frequency
        li $t3, 0                 # reset $t3 back to 0
        la $a0, log3              # load the address of the position of log3
        jal MOVE_OBSTACLE
        la $a0, log4              # load the address of the position of log4
        jal MOVE_OBSTACLE

        lh $t5, frog              # position of frog
        li $t9, 8                 # $t9 = 8 = tiles per row
        div $t5, $t9
        mflo $t6                  # $t6 = $t5 / 8 is the row of the frog
        bne $t6, 3, END_LOG_ROW_2 # branch if frog not on this row
        la $a0, frog              # load the address of the position of frog
        jal MOVE_OBSTACLE
  END_LOG_ROW_2:
        sh $t3, count_log_row2    # store $t3 back at the counter address


        # car row 1
        li $a1, -1                 # move to the right
        lh $a2, freq_car_row1
        lh $t3, count_car_row1    # counter value of car row 1
        addi $t3, $t3, 1          # iterate $t3
        bne $t3, $a2, END_CAR_ROW_1 # move the obstacle only when the counter value is equal to the frequency
        li $t3, 0                 # reset $t3 back to 0
        la $a0, car1              # load the address of the position of car1
        jal MOVE_OBSTACLE
        la $a0, car2              # load the address of the position of car2
        jal MOVE_OBSTACLE
  END_CAR_ROW_1:
        sh $t3, count_car_row1    # store $t3 back at the counter address

        # car row 2
        li $a1, 1                 # move to the left
        lh $a2, freq_car_row2
        lh $t3, count_car_row2    # counter value of car row 2
        addi $t3, $t3, 1          # iterate $t3
        bne $t3, $a2, END_CAR_ROW_2 # move the obstacle only when the counter value is equal to the frequency
        li $t3, 0                 # reset $t3 back to 0
        la $a0, car3              # load the address of the position of car3
        jal MOVE_OBSTACLE
        la $a0, car4              # load the address of the position of car4
        jal MOVE_OBSTACLE
  END_CAR_ROW_2:
        sh $t3, count_car_row2    # store $t3 back at the counter address


        lw $ra, 0($sp)            # restore return
        addi $sp, $sp, 4          #   address value
        jr $ra                    # return

CHECK_WIN:
        lb $t1, goal1
        lb $t2, goal2
        lb $t3, goal3
        lb $t4, goal4
        lb $t5, goal5
        bne $t1, 1, NOT_WIN
        bne $t2, 1, NOT_WIN
        bne $t3, 1, NOT_WIN
        bne $t4, 1, NOT_WIN
        bne $t5, 1, NOT_WIN
        j WIN
  NOT_WIN:
        jr $ra
CHECK_COLLIDE:
        lh $t0, frog              # location of frog
        li $t9, 8                 # tiles per row
        div $t0, $t9
        mflo $t1                  # $t1 = $t0 / 8 = row frog is on
        mfhi $t2                  # $t2 = $t0 % 8 = column frog is on
        ble $t1, 1, ON_GOAL       # frog is in goal region
        beq $t1, 2, ON_LOG_ROW_1  # frog is on log row 1
        beq $t1, 3, ON_LOG_ROW_2  # frog is on log row 2
        beq $t1, 5, ON_CAR_ROW_1  # frog is on car row 1
        beq $t1, 6, ON_CAR_ROW_2  # frog is on car row 2
        j CHECK_END
  ON_GOAL:
        beq $t2, 0, GOAL1
        beq $t2, 2, GOAL2
        beq $t2, 4, GOAL3
        beq $t2, 5, GOAL4
        beq $t2, 7, GOAL5
        j CHECK_END
    GOAL1:
        li $t9, 1
        sb $t9, goal1
        li $t0, 60                # default location of frog
        sh $t0, frog              # set location of frog
        j CHECK_END
    GOAL2:
        li $t9, 1
        sb $t9, goal2
        li $t0, 60                # default location of frog
        sh $t0, frog              # set location of frog
        j CHECK_END
    GOAL3:
        li $t9, 1
        sb $t9, goal3
        li $t0, 60                # default location of frog
        sh $t0, frog              # set location of frog
        j CHECK_END
    GOAL4:
        li $t9, 1
        sb $t9, goal4
        li $t0, 60                # default location of frog
        sh $t0, frog              # set location of frog
        j CHECK_END
    GOAL5:
        li $t9, 1
        sb $t9, goal5
        li $t0, 60                # default location of frog
        sh $t0, frog              # set location of frog
        j CHECK_END
  ON_LOG_ROW_1:
        lh $t7, log1                # position of first log on log row 1
        lh $t8, log2                # position of second log on log row 1
        addi $t5, $t0, -1           # tile left of frog
        beq $t5, $t7, CHECK_END
        beq $t5, $t8, CHECK_END
        addi $t5, $t0, 0            # tile of frog
        beq $t5, $t7, CHECK_END
        beq $t5, $t8, CHECK_END
        addi $t5, $t0, 0            # tile right of frog
        beq $t5, $t7, CHECK_END
        beq $t5, $t8, CHECK_END
        j DEAD                      # frog not on any log on this row
  ON_LOG_ROW_2:
        lh $t7, log3                # position of first log on log row 2
        lh $t8, log4                # position of second log on log row 2
        addi $t5, $t0, -1           # tile left of frog
        beq $t5, $t7, CHECK_END
        beq $t5, $t8, CHECK_END
        addi $t5, $t0, 0            # tile of frog
        beq $t5, $t7, CHECK_END
        beq $t5, $t8, CHECK_END
        addi $t5, $t0, 0            # tile right of frog
        beq $t5, $t7, CHECK_END
        beq $t5, $t8, CHECK_END
        j DEAD                      # frog not on any log on this row
  ON_CAR_ROW_1:
        lh $t7, car1                # position of first car on car row 1
        lh $t8, car2                # position of second car on car row 1
        addi $t5, $t0, -1           # tile left of frog
        beq $t5, $t7, DEAD
        beq $t5, $t8, DEAD
        addi $t5, $t0, 0            # tile of frog
        beq $t5, $t7, DEAD
        beq $t5, $t8, DEAD
        addi $t5, $t0, 0            # tile right of frog
        beq $t5, $t7, DEAD
        beq $t5, $t8, DEAD
        j CHECK_END                 # frog not on any car on this row
  ON_CAR_ROW_2:
        lh $t7, car3                # position of first car on car row 2
        lh $t8, car4                # position of second car on car row 2
        addi $t5, $t0, -1           # tile left of frog
        beq $t5, $t7, DEAD
        beq $t5, $t8, DEAD
        addi $t5, $t0, 0            # tile of frog
        beq $t5, $t7, DEAD
        beq $t5, $t8, DEAD
        addi $t5, $t0, 0            # tile right of frog
        beq $t5, $t7, DEAD
        beq $t5, $t8, DEAD
        j CHECK_END                 # frog not on any car on this row
  DEAD:
        lb $t6, lives               # number of lives
        addi $t6, $t6, -1           # decrement lives
        sb $t6, lives               # set lives
        li $t0, 60                  # default location of frog
        sh $t0, frog                # set location of frog
        beq $t6, 0, LOSE            # zero lives, game over
  CHECK_END:
        jr $ra                    # return
