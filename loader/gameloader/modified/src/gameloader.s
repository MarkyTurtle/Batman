
;---------- Includes ----------
              INCDIR      "include"
              INCLUDE     "hw.i"
              ;INCLUDE     "funcdef.i"
              ;INCLUDE     "exec/exec_lib.i"
              ;INCLUDE     "graphics/graphics_lib.i"
              ;INCLUDE     "hardware/cia.i"
;---------- Const ----------


;Interrupt status flags for variable $0000209A.B
DSKBLK_FINISHED equ $0                                  ; set by level 1 interrupt handler but unused.
BLIT_FINISHED   equ $1                                  ; set by level 3 interrupt handler but unused.
TIMERA_FINISHED equ $2
DISK_INDEX1     equ $3                                  ; set by level 6 interrupt handler (disk write trigger - both must be set to 0 & CIAB FLG interrupt)
DISK_INDEX2     equ $4                                  ; set by level 6 interrupt handler (disk write trigger - both must be set to 0 & CIAB FLG interrupt)



                    section BATMAN,code_c


                    org $800

                ;------------------------- BATMAN entry point --------------------------
                ;-- Main Game Loader, entry point from the 'RTS' in the bool block code.
                ;-- immediately calls the 'load_loading_screen' jump table entry.
                ;--
                ;-- $2AD6   - The disk file table, held on 3rd sector of track 0, loaded in to this address.
                ;--         - See documentation on the File Table structure: 
                ;--
                ;-- $7C7FC  - The top/end address of the load buffer,
                ;--           The loader loads files into memory in blocks below this address.
                ;--           e.g. the titlepic.iff raw file is loaded into $6FB06 and ends at $7C7FC - Length $CCF6
                ;--                the titleprg.iff raw file is loaded into $59766 and ends at $6FB05 - Length 163A0
                ;--           Once the files are loaded, the loader then processes the iff files and relocates
                ;--           them in memory etc.
                ;--
                ;--         
batman_start
                bra.b jump_table                                ; Calls $0000081C - jmp_load_screen (addr: $00000800)
                                                                ; This will get overwritten by the stack during loading

                dc.w    $0000, $22BA, $0000, $0000              ; scrap memory (i think)
                dc.w    $0000, $0000, $0000, $0000  
                dc.w    $0000, $0000, $0000, $0000  
                dc.w    $0000   

stack                                                           ; Top of Loader Stack, (re)set each time a game section is loaded. (addr:$0000081C) 
jump_table                                                      ; Start of jump table for loading and executing the game sections. (addr:$0000081C)
L0000081C       bra.w  load_loading_screen                      ; Calls $00000838 - Load Loading Screen (instruction addr:$0000081C)
L00000820       bra.w  load_title_screen2                       ; Calls $00000948 - Load Title Screen2  (instruction addr:$00000820)
L00000824       bra.w  load_level1                              ; Calls $000009C8 - Load Level 1 - Axis Chemicals (instruction addr:$00000824)
L00000828       bra.w  load_level_2                             ; Calls $00000A78 - Load Level 2 - Bat Mobile (instruction addr:$00000829)
L0000082C       bra.w  load_level_3                             ; Calls $00000B28 - Load Level 3 - Bat Cave Puzzle (instruction addr:$0000082C)
L00000830       bra.w  load_level_4                             ; Calls $00000B90 - Load Level 4 - Batwing Parade (instruction addr:$00000830)
L00000834       bra.w  load_level_5                             ; Calls $00000C40 - Load Level 5 - Cathedral (instruction addr:$00000834)




                

                ;---------------------- load loading screen ------------------------
                ;-- load the batman loading.iff and display it for 5 seconds.
                ;-- then, jump to load the title screen.
load_loading_screen                                             ; relocated address: $00000838
                LEA.L  stack,A7                                 ; stack address $0000081C
                BSR.W  init_system                              ; calls $00001F26 - init_system
                BSR.W  detect_available_drives                  ; calls $00001B4A - detect which disk drives are connected
                MOVE.L #$0007C7FC,ld_loadbuffer_top             ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr              ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_loading_screen(PC),A0                 ; addr $008C8 - address of the load parameter block (files to load for the loading screen section)
                BSR.W  loader                                   ; calls $00000CFC - Load/Process files & Copy Protection

                ; clear out color palette
                LEA.L  CUSTOM,A6
                LEA.L  COLOR00(A6),A0
                MOVE.L #$0000001f,D0                            ; loop counter = 31 + 1
.clearloop      CLR.W (A0)+                                     ; Clear Colour Pallete Registers (instruction addr $0000086C)
                DBF.W D0,.clearloop

                ; display loading screen (5 seconds)
                MOVE.W #$0000,BPL1MOD(A6)                       ; clear bit-plane modulos
                MOVE.W #$0000,BPL2MOD(A6)                       ; clear bit-plane modulos
                MOVE.W #$0038,DDFSTRT(A6)                       ; standard data fetch start for low-res 320 wide screen
                MOVE.W #$00d0,DDFSTOP(A6)                       ; startard data fetch stop for low-res 320 wide screen
                MOVE.W #$2c81,DIWSTRT(A6)                       ; standard window start position for 320x256 pal screen
                MOVE.W #$2cc1,DIWSTOP(A6)                       ; standard window end position for 320x256 pal screen
                MOVE.W #$5200,BPLCON0(A6)                       ; 5 bit-planes, COLOR_ON = 1
                LEA.L  copper_list(PC),A0                       ; Get Copper List 1 address. addr: $00001490
                MOVE.L A0,COP1LC(A6)                            ; Set Copper 1 Pointer
                LEA.L  copper_endwait(PC),A0                    ; Get Copper List 2 address. addr: $00001538
                MOVE.L A0,COP2LC(A6)                            ; Set copper 2 Pointer
                MOVE.W A0,COPJMP2(A6)                           ; Strobe COPJMP2 to run empty list, will revert to copper 1 on next frame.
                MOVE.W #$8180,DMACON(A6)                        ; Enable DMA - BPLEN, COPEN
 
                                                                ; display loading screen for 5 seconds.
                CLR.W  ciab_tb_20ms_tick                        ; reset CIAB Timer B, ticker count
.timerwait      CMP.W  #$00fa,ciab_tb_20ms_tick                 ; wait for 250 x 20 ms = 5,000ms - $0000223A
                BCS.B  .timerwait
                BRA.B  load_title_screen1                       ; addr: $0000090E


lp_loading_screen                                               ; loading screen load parameters - addr: $000008C8
                ; Disk Name (offset from here)
.diskname_offset    dc.w    $0020
                ; File Entry to load
                ;       0 - 2 Bytes - File Name Offset (from here)
                ;       2 - 4 bytes - File reloacation address
                ;       6 - 4 bytes - File Length Stored below from file table
                ;       a - 4 bytes - File Load Address stored below
.file1_name_offset  dc.w    $002E
.file1_reloc_addr   dc.l    $00000000
.file1_byte_length  dc.l    $00000000
.file1_loadbuf_addr dc.l    $00000000 
                ; File Entry to load
                ;       0 - 2 Bytes - File Name Offset (from here)
                ;       2 - 4 bytes - File reloacation address
                ;       6 - 4 bytes - File Length Stored below from file table
                ;       a - 4 bytes - File Load Address stored below
.file2_name_offset  dc.w    $002B
.file2_reloc_addr   dc.l    $0007C7FC
.file2_byte_length  dc.l    $00000000
.file2_loadbuf_addr dc.l    $00000000
.filename3_offset   dc.w    $0000          
.diskname           dc.b    "BATMAN MOVIE   0"
.filename1          dc.b    "LOADING IFF"
.filename2          dc.b    "PANEL   IFF"







                ;---------------------- load title screen 1 & 2------------------------
                ;-- called on first load, after the loading screen.
                ;-- 1) starts the title screen (without the end game joker laugh etc)
                ;-- 2) starts the title screen (with joket laugh)
load_title_screen1                                              ; relocated address: $0000090E
                LEA.L  stack,A7                                 ; stack address $0000081C
                BSR.W  init_system                              ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top             ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr              ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_title_screen(PC),A0                   ; get title screen load parameters address
                BSR.W  loader                                   ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                        ; disable interrupts
                MOVE.W #$1fff,DMACON(A6)                        ; disable all dma
                MOVE.W #$2000,SR                                ; set supervisor mode bit 
                JMP    $0001c000                                ; title screen start (on load)


load_title_screen2                                              ; relocated address: $00000948
                LEA.L  stack,A7                                 ; Stack Address $0000081C
                BSR.W  init_system                              ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top             ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr              ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_title_screen(PC),A0                   ; get title screen load parameters address
                BSR.W  loader                                   ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                        ; disable interrupts
                MOVE.W #$1fff,DMACON(A6)                        ; disable all dma
                MOVE.W #$2000,SR                                ; set supervisor mode bit
                JMP    $0001c004                                ; title screen start (on end of a game)



lp_title_screen:                                                                    ; title screen loader parameters. addr: $00000982
                dc.w   $0020, $002E, $0000, $3FFC, $0000, $0000, $0000, $0000       ;. ....?.........
                dc.w   $002B, $0003, $F236, $0000, $0000, $0000, $0000, $0000       ;.+...6..........
                dc.w   $4241, $544D, $414E, $204D, $4F56, $4945, $2020, $2030       ;BATMAN MOVIE   0
                dc.w   $5449, $544C, $4550, $5247, $4946, $4654, $4954, $4C45       ;TITLEPRGIFFTITLE
                dc.w   $5049, $4349, $4646                                          ;PICIFF







                ;---------------------- load level1 - axis chemicals ------------------------
load_level1                                                         ; relocated address: $000009C8
                LEA.L  stack,A7                                     ; stack address $0000081C
                BSR.W  init_system                                  ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top                 ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr                  ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_level_1(PC),A0                            ; get level 1 load parameters address
                BSR.W  loader                                       ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                            ; disable all interrupts
                MOVE.W #$1fff,DMACON(A6)                            ; disable all dma
                MOVE.W #$2000,SR                                    ; set supervisor mode bit
                JMP $00003000                                       ; level 1 start

lp_level_1                                                      ; level 1 loader parameters. addr: $00000A00
                dc.w   $003C, $004A, $0000, $2FFC, $0000, $0000, $0000, $0000         ;.<.J../.........
                dc.w   $0047, $0000, $7FFC, $0000, $0000, $0000, $0000, $0044         ;.G.............D
                dc.w   $0001, $0FFC, $0000, $0000, $0000, $0000, $0041, $0004         ;.............A..
                dc.w   $7FE4, $0000, $0000, $0000, $0000, $0000, $4241, $544D         ;............BATM
                dc.w   $414E, $204D, $4F56, $4945, $2020, $2030, $434F, $4445         ;AN MOVIE   0CODE
                dc.w   $3120, $2020, $4946, $464D, $4150, $4752, $2020, $2049         ;1   IFFMAPGR   I
                dc.w   $4646, $4241, $5453, $5052, $3120, $4946, $4643, $4845         ;FFBATSPR1 IFFCHE
                dc.w   $4D20, $2020, $2049, $4646                                     ;M    IFF







                ;---------------------- load level 2 - bat mobile ------------------------
load_level_2                                                    ; relocated address: $00000A78
                LEA.L  stack,A7                                     ; stack address $0000081C
                BSR.W  init_system                                  ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top                 ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr                  ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_level_2(PC),A0                            ; get level 2 load parameters address
                BSR.W  loader                                       ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                            ; disable all interrupts
                MOVE.W #$1fff,DMACON(A6)                            ; disable all dma
                MOVE.W #$2000,SR                                    ; set supervisor mode bit
                JMP $00003000                                       ; level 2 start

lp_level_2                                                      ; level 2 loader parameters. addr: $00000AB0
                dc.w   $003C, $004A, $0000, $2FFC, $0000, $0000, $0000, $0000         ;.<.J../.........
                dc.w   $0047, $0001, $FFFC, $0000, $0000, $0000, $0000, $0044         ;.G.............D
                dc.w   $0002, $A416, $0000, $0000, $0000, $0000, $0041, $0006         ;.............A..
                dc.w   $8F7C, $0000, $0000, $0000, $0000, $0000, $4241, $544D         ;.|..........BATM
                dc.w   $414E, $204D, $4F56, $4945, $2020, $2031, $434F, $4445         ;AN MOVIE   1CODE
                dc.w   $2020, $2020, $4946, $4644, $4154, $4120, $2020, $2049         ;    IFFDATA    I
                dc.w   $4646, $4441, $5441, $3220, $2020, $4946, $464D, $5553         ;FFDATA2   IFFMUS
                dc.w   $4943, $2020, $2049, $4646                                     ;IC   IFFO






                ;---------------------- load level 3 - bat cave puzzle ------------------------
load_level_3                                                    ; relocated address: $00000B28
                LEA.L  stack,A7                                     ; stack address $0000081C
                BSR.W  init_system                                  ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top                 ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr                  ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_level_3(PC),A0                            ; get level 3 load parameters address
                BSR.W  loader                                       ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                            ; disable all interrupts
                MOVE.W #$1fff,DMACON(A6)                            ; disable all dma
                MOVE.W #$2000,SR                                    ; set supervisor mode bit
                JMP $0000d000                                       ; level 3 start

lp_level_3                                                      ; level 3 loader parameters. addr: $00000B62
                dc.w   $0012, $0020, $0000, $3FFC, $0000, $0000, $0000, $0000         ;... ..?.........
                dc.w   $0000, $4241, $544D, $414E, $204D, $4F56, $4945, $2020         ;..BATMAN MOVIE  
                dc.w   $2031, $4241, $5443, $4156, $4520, $4946, $4600                ; 1BATCAVE IFF.






                ;---------------------- load level 4 - batwing parade ------------------------
load_level_4                                                    ; relocated address: $00000B90
                LEA.L  stack,A7                                     ; stack address $0000081C
                BSR.W  init_system                                  ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top                 ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr                  ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_level_4(PC),A0                            ; get level 4 load parameters address
                BSR.W  loader                                       ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                            ; disable all interrupts
                MOVE.W #$1fff,DMACON(A6)                            ; disable all dma
                MOVE.W #$2000,SR                                    ; set supervisor mode bit
                JMP $00003002                                       ; level 4 start

lp_level_4                                                      ; level 4 loader parameters. addr: $00000BC8
                dc.w   $003C, $004A, $0000, $2FFC, $0000, $0000, $0000, $0000         ;.<.J../.........
                dc.w   $0047, $0001, $FFFC, $0000, $0000, $0000, $0000, $0044         ;.G.............D
                dc.w   $0002, $A416, $0000, $0000, $0000, $0000, $0041, $0006         ;.............A..
                dc.w   $8F7C, $0000, $0000, $0000, $0000, $0000, $4241, $544D         ;.|..........BATM
                dc.w   $414E, $204D, $4F56, $4945, $2020, $2031, $434F, $4445         ;AN MOVIE   1CODE
                dc.w   $2020, $2020, $4946, $4644, $4154, $4120, $2020, $2049         ;    IFFDATA    I
                dc.w   $4646, $4441, $5441, $3420, $2020, $4946, $464D, $5553         ;FFDATA4   IFFMUS
                dc.w   $4943, $2020, $2049, $4646                                     ;IC   IFFO...a...







                ;---------------------- load level 5 - cathedral  ------------------------
load_level_5                                                    ; relocated address: $00000C40
                LEA.L  stack,A7                                     ; stack address $0000081C
                BSR.W  init_system                                  ; L00001F26
                MOVE.L #$0007C7FC,ld_loadbuffer_top                 ; store loader parameter: addr $7C7FC - the Top of the Load Buffer
                MOVE.L #$00002AD6,ld_relocate_addr                  ; $00000CF0 (** SET BUT UNUSED **) ; addr $02AD6 - address of disk file table
                LEA.L  lp_level_5(PC),A0                            ; level 5 load parameters address
                BSR.W  loader                                       ; calls $00000CFC - Load/Process files & Copy Protection
                MOVE.W #$7fff,INTENA(A6)                            ; disable all interrupts
                MOVE.W #$1fff,DMACON(A6)                            ; disable all dma
                MOVE.W #$2000,SR                                    ; set supervisor mode bit
                JMP $00003000                                       ; level 5 start

lp_level_5                                                      ; level 5 loader parameters. addr: $00000C78
                dc.w   $003C, $004A, $0000, $2FFC, $0000, $0000, $0000, $0000         ;.<.J../.........
                dc.w   $0047, $0000, $7FFC, $0000, $0000, $0000, $0000, $0044         ;.G.............D
                dc.w   $0001, $0FFC, $0000, $0000, $0000, $0000, $0041, $0004         ;.............A..
                dc.w   $7FE4, $0000, $0000, $0000, $0000, $0000, $4241, $544D         ;............BATM
                dc.w   $414E, $204D, $4F56, $4945, $2020, $2030, $434F, $4445         ;AN MOVIE   0CODE
                dc.w   $3520, $2020, $4946, $464D, $4150, $4752, $3220, $2049         ;5   IFFMAPGR2  I
                dc.w   $4646, $4241, $5453, $5052, $3120, $4946, $4643, $4855         ;FFBATSPR1 IFFCHU
                dc.w   $5243, $4820, $2049, $4646                                     ;RCH  IFF 








                ;----------------------------------------------------------------------------------------------------
                ;----------------------------------------------------------------------------------------------------
                ; GAME LOADER & FILE PROCESSOR/RELOCATOR
                ;----------------------------------------------------------------------------------------------------
                ;----------------------------------------------------------------------------------------------------







                ;------------------------------ loader data/parameters ------------------------------
                ;-- loader parameters and data store
                ;-- starts at relocated address $00000CF0
                ;-- $CF0 - File Relocation Address
                ;-- $CF4 - Top/End of Loaded Files Buffer 
                ;--        files are loaded below this address, kinda like a file stack
                ;--        when all files are loaded they are then processed and relocated
                ;--        also by the loader.
                ;-- $CF8 - Holds the File Table Memory Address Pointer (set in loader)
ld_relocate_addr                                ; addr $00000CF0 - file relocation address (misused by code external to the loader)
                dc.l   $00000000
ld_loadbuffer_top                               ; addr $00000CF4
                dc.l   $00000000                ; ptr to load buffer end/top of memory (file are loaded below this address sequentially)
ld_filetable                                    ; addr $00000CF8
                dc.l   $00000000                ; ptr to disk file table addess (disk directory, file names, length & start sectors)




                ;---------------------------------- loader ---------------------------------------
                ;-- the main call made to load a game section into memory.
                ;-- loads and decodes files into memory buffer, then processes the files and
                ;-- relocates them, finally hands off to the copy protection.
                ;-- the copy protection man-handles the stack to return to the called of loader()
                ;--
                ; IN: A0            - load parameter block base address.
                ; IN: 00000CF4.l    - Top/end of Load buffer in memory ($7C7FC)
                ; IN: 00000CF0.l    - (** SET BUT UNUSED **) Disk File Table Contents ($2AD6) for all loading sections.
                ;
loader                                                          ; relocated routine start Addr $00000CFC 
                MOVEM.L D0-D7/A0-A6,-(A7)
                CLR.W   ld_load_status                          ; $00001B08 ; clear 'load status' word
                MOVE.L  #$00002AD6,ld_filetable                 ; store file table address
                MOVE.L  #$00002CD6,ld_decoded_track_ptr         ; decoded track buffer address
                MOVE.L  #$000042D6,ld_mfmencoded_track_ptr      ; mfm encoded track buffer address
                TST.W   (A0)                                    ; test first load parameter value
                BEQ.W   .end_load_files                         ; end load if = 0 - just check copy protection? ; jmp $00000D6E 

.check_disk
                MOVEA.L A0,A1                                   ; copy file parameter block base address
                ADDA.W  (A1)+,A0                                ; A0 = ptr to disk name string e.g. "BATMAN MOVIE   0"
                MOVE.L  A1,-(A7)                                ; A1 = ptr to first filename structure.
                BSR.W   load_filetable                          ; $000015DE ; Load File Table $2AD6 & Check Disk Name
                BEQ.B   .correct_disk                           ; $00000D38 ; Z = 1 - correct disk in the drive
                BSR.W   L000013B2                               ;       - else wait for correct disk to be inserted

.correct_disk
                MOVEA.L (A7),A0                                 ; A0 = ptr to first filename structure. (CCR not affected)
                LEA.L   $0007c7fc,A6                            ; Top/End of loaded files buffer
                CLR.W   ld_load_status                          ; $00001B08 ; clear 'load status' word
                BSR.W   load_file_entries                       ; call $00001652 - load files (A0 = first file entry)
                MOVEA.L (A7)+,A0                                ; A0 = ptr to first filename structure. (CCR not affected)
                BNE.B   .end_load_files                         ; Z=0 - error, jmp $00000D6E

.process_files_loop
                TST.W   (A0)                                    ; A0 = ptr to 1st file entry loaded. Test for file to process
                BEQ.B   .end_load_files                          ; Test First File Entry data value, if null jmp $00000D6E
                MOVE.L  A0,-(A7)
                MOVE.L  $0002(A0),ld_relocate_addr              ; $00000CF0 = ld_relocate_addr, file relocation address (from file entry table)
                MOVE.L  $0006(A0),D0                            ; D0 = File Length
                MOVEA.L $000a(A0),A0                            ; A0 = File Address
                BSR.W   process_file                            ; call $000016E0
                MOVEA.L (A7)+,A0
                LEA.L   $000e(A0),A0
                BRA.B   .process_files_loop                     ; jmp $00000D4E ; process next file

.end_load_files                                                  ; relocated address: $00000D6E
                MOVE.W  ld_drive_number,D0                      ; $00001AFC
                BSR.W   drive_motor_off                         ; calls $00001B7A
                LEA.L   $00bfd100,A0                            ; CIAB PRB - as a base register

.vbwait1                                                        ; Vertical Blank Wait 1                                           
                CLR.W   frame_counter                           ; Clear frame counter
.wait_frame1
                TST.W   frame_counter                           ; Compare Frame Counter with 0
                BEQ.B   .wait_frame1                            ; loop until next VERTB interrupt

                MOVE.B  #$00,$0900(A0)                          ; CIAB - Clear TODHI 
                MOVE.B  #$00,$0800(A0)                          ; CIAB - Clear TODMID
                MOVE.B  #$00,$0700(A0)                          ; CIAB - Clear TODLOW

.vbwait2                                                        ; Vertical Blank Wait 2
                CLR.W   frame_counter                           ; $00002144
.wait_frame2
                TST.W   frame_counter                       
                BEQ.B   .wait_frame2                            ; loop until next VERTB interrupt

                MOVE.L  #$00000000,D0                           ; CIAB - Read TOD value
                MOVE.B  $0900(A0),D0                            ; CIAB - Read TODHI
                ASL.L   #$00000008,D0                           ; CIAB - shift bits
                MOVE.B  $0800(A0),D0                            ; CIAB - Read TODMID
                ASL.L   #$00000008,D0                           ; CIAB - shift bits
                MOVE.B  $0700(A0),D0                            ; CIAB - Read TODLOW
 
                CMP.L   #$00000115,D0                           ; Compare value in TOD with #$115 (277 scan lines, TOD tick is synced to Horizontal Sync)
.infinite_loop
                BCS.B   .infinite_loop                          ; A check for execution speed between .vbwait1 & .vbwait2
                                                                ; or the number of scan lines (maybe fail for NTSC?)
                                                                ; infinite loop if D0 < 277 
                                                                ;    - PAL 312.5 scanlines
                                                                ;    - NTSC 262.5 scan lines

                BRA.W   copy_protection_init1                   ; instruction addr: $00000DC6 - jump to copy protection $00000E82                   







                ;----------------------------------------------------------------------------------------------------
                ;----------------------------------------------------------------------------------------------------
                ; COPY PROTECTION (Rob Northen)
                ;----------------------------------------------------------------------------------------------------
                ;----------------------------------------------------------------------------------------------------






                ;------------- copy protection - mfm and decode buffer ---------------
                ;-- data is read in from the protected track 'manually' and stored
                ;-- here mfm encoded. It is later decoded in place (half size)
cp_mfm_buffer                                                                           ; relocated addr 00000DCA
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;......
                dc.W    $0000, $0000, $0000


                ;------------ copy protection variables/data ------------------------
                ;-- various data registers and storage value start at $E10 
cp_register_store                                                                       ; original address $00000E10
                dc.w    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................ 
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................


                ;------------ saved exception vector values --------------------------
cp_exception_vectors_store                                                              ; original address $00000E50
                dc.w    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000          ;................
                dc.W    $0000, $0000, $0000, $0000, $0000, $0000                        ;............
cp_checksum_vector 
                dc.w    $0000, $0000                                                    ; original address $00000E6C


                ;------------ current drive track numbers ---------------------------
                ; copy protection appears to support either drive 0 or drive 1
                ; any more drives may cause bug with indexing into other values.
cp_current_track                                                                        ; relocated addr $00000E70
                dc.w    $FFFF                                                           ; current track drive 0
                dc.w    $FFFF                                                           ; current track drive 1

                ;------------ current disk drive in use -----------------------------
                ; 0 or 1 used as an index to cp_current_track
cp_current_drive                                                                        ; relocated addr $00000E74
                dc.w    $0000 

                ;------------ copy lock track number --------------------------------
                ; the track number holding the protected copylock track data
cp_protection_track                                                                     ; relocated addr $00000E76
                dc.w    $0001   

                ;------------ saved track number ------------------------------------
                ; the track that the disk drive was at before the copylock started
                ; used to return the heads back to where they started after copy
                ; check.                
cp_saved_track_number                                                                   ; relocated addr $00000E78
                dc.W    $0000

                ;------------ decoded/encoded instruction buffer --------------------
                ; normally used by the trace vector decoder to store the encoded
                ; versions of the currently executing instruction, so they
                ; can be replaced quickly without requiring re-encoding
cp_decode_instructions                                                                  ; relocated addr $00000E7A    
                dc.W    $0000, $0000, $0000, $0000                               




copy_protection_init1                                                           ; original routine address $00000E82
                MOVE.L  A6,-(A7)
                LEA.L   cp_register_store(PC),A6                                ; L00000E10(pc),A6
                MOVEM.L D0-D7/A0-A7,(A6)
                LEA.L   $0040(A6),A6
                MOVE.L  (A7)+,-$0008(A6)
                MOVE.L  $00000010,D0
                PEA.L   cp_supervisor(PC)                                                     
                MOVE.L  (A7)+,$00000010
                ILLEGAL  

                ;------------ enter supervisor (if not already) ------------------
                ;-- This exception never returns to this point in the code.
                ;-- Later the stack is return address is modified to return to
                ;-- the address L0000139C 'cp_end'

cp_supervisor                               
L00000EA6       MOVE.L  D0,$00000010
L00000EAC       MOVEM.L $00000008,D0-D7
L00000EB4       MOVEM.L D0-D7,(A6)

L00000EB8       LEA.L cp_toggle_tvd(PC),A0
L00000EBC       MOVE.L A0,$00000010                             ; Set ILLEGAL Exception vector to 'cp_toggle_tvd'
L00000EC2       ILLEGAL                                         ; Toggle on trace vector decoder (TVD)
                ; Execution continues here with TVD on
                ; normally the code would be encoded.

                ;---------------- jump around table nonsense --------------------
                ;-- Normally this code would be encoded by the TVD, this table
                ;-- of jumps is no doubt intended to cause confusion and
                ;-- cause would-be crackers problems tracing the code.
cp_confusion
L00000EC4       BRA.W L00000ED4
L00000EC8       BRA.W L00000F04
L00000ECC       BRA.W L00000F30
L00000ED0       BRA.W L00000EDC
L00000ED4       BRA.W L00000EE0                                            
L00000ED8       BRA.W L00000EF4
L00000EDC       BRA.W L00000F00
L00000EE0       BRA.W L00000F34
L00000EE4       BRA.W L00000EC8
L00000EE8       BRA.W L00000EF0
L00000EEC       BRA.W L00000EFC
L00000EF0       BRA.W L00000F0C
L00000EF4       BRA.W L00000F2C
L00000EF8       BRA.W L00000F28
L00000EFC       BRA.W L00000F10
L00000F00       BRA.W L00000EE4
L00000F04       BRA.W L00000EE8
L00000F08       BRA.W cp_set_vectors                                        ;L00000f9e Exit point from the jumps
L00000F0C       BRA.W L00000F14
L00000F10       BRA.W L00000ED0
L00000F14       BRA.W L00000F1C
L00000F18       BRA.W L00000ECC
L00000F1C       BRA.W L00000ED8
L00000F20       BRA.W L00000EEC
L00000F24       BRA.W L00000EF8
L00000F28       BRA.W L00000F18
L00000F2C       BRA.W L00000F24
L00000F30       BRA.W L00000F08
L00000F34       BRA.W L00000F20


                ;------------ copy protection - toggle trace vector decoder -------------
                ;-- ILLEGAL intruction exception handler, this routine would normally
                ;-- toggle on/off the TVD and also decode/encode the first/last
                ;-- instruction that was being executed by the copy protection.
                ;-- It's been patched so it doesn't encode/decode any instructions,
                ;-- The 68000 trace bit is still toggled in 
cp_toggle_tvd                                                                   ; original routine address $00000F38
                MOVEM.L D0/A0-A1,-(A7)
                LEA.L   cp_tvd(PC),A0                                           ; A0 = Address of Trace Vector Decoded routine. 
                MOVE.L  A0,$00000024                                            ; Set TVD Address in Trace Exception Vector
                LEA.L   cp_end(PC),A0                                           ; A0 = Address of copy protection end routine 'cp_end' $0000139C 
                MOVE.L  A0,$00000020                                            ; Set 'cp_end' in Privilege Violation Exception Vector, maybe a protection mechanism to prevent tampering.
                ADD.L   #$00000002,$000e(A7)                                    ; Increment the return address on stack 2 bytes
                OR.B    #$07,$000c(A7)                                          ; Enable Interrupts
                BCHG.B  #$07,$000c(A7)                                          ; Toggle the 68000 trace bit on/off
                LEA.L   cp_decode_instructions(PC),A1                           ; unused (locatopn previously used for encode/decode)
                MOVEM.L (A7)+,D0/A0-A1
                RTE 
                NOP 
                NOP 


                ;----------- copy protection - trace vector decoder (TVD) -------------
                ;-- This code would normaly decode the next instruction and encode
                ;-- the previous copy protection instruction while the 68000 is
                ;-- in trace mode.
                ;-- Patched to do nothing but flash the screen when each instruction
                ;-- executes while the 68000 trace bit is enabled.
cp_tvd                                                                  ; original routine address $00000F72
                AND.W #$f8ff,SR
                MOVEM.L D0/A0-A1,-(A7)
                NOP 
                NOP 
                MOVE.W #$0fff,D0
.flash_loop     MOVE.W D0,$00dff180
                SUB.W #$0111,D0
                BNE.B .flash_loop
                NOP 
                NOP 
                NOP 
                NOP 
                NOP 
                MOVEM.L (A7)+,D0/A0-A1
                RTE 


                ;------------ copy protection - set vectors -------------------
                ; updates exception vectors $08 (Bus Error) to $24 (Trace)
                ; with new values, the original code updates the vectors
                ; to the following values:-
                ;
                ; $08 - Bus Error             = $0000141c
                ; $0C - Address Error         = $0000139C 'cp_end'
                ; $10 - Illegal Intruction    = $00000F38 'cp_toggle_tvd'
                ; $14 - Zero Divide           = $0000145C
                ; $18 - CHK Instruction       = $0000149C
                ; $1C - TRAPV Instruction     = $0000151C
                ; $20 - Privilege Instruction = $0000139C 'cp_end'
                ; $24 - Trace                 = $00000F72 'cp_tvd'
                ;
                ; The important entries are:
                ; $10 - Illegal Instruction - normally used to toggle TVD on/off
                ; $24 - Trace               - normally decode/encode next/previous instuction
                ;
                ; The other entries are there most probably to disguise the above
                ; entries, or to cause additional problems with tracing/tampering.
                ;
                ; The 'exception_vector_offsets' is a table of values for the offsets
                ; of each exception handler, the offsets are added to the address of
                ; 'copy_protection_init1', originally located at $00000E82
                ; again, any tampering would cause these offsets to alter, causing
                ; problems with the execution of the code.
                ;
cp_set_vectors                                                  ; original routine address $00000F9E
                LEA.L exception_vector_offsets(PC),A0
                LEA.L $00000008,A1                              ; A1 = first exception vector address $08 = Bus Error
                LEA.L copy_protection_init1(PC),A2              ; A2 = Address of 'copy_protection_init1', originally $00000E82
                MOVE.L #$00000007,D0                            ; D0 = loop counter 7 + 1
.loop
                MOVE.L #$00000000,D1
                MOVE.W (A0)+,D1                                 ; D1 = next handler address offset
                ADD.L A2,D1                                     ; D1 = offset + base address 'copy_protection_init1'
                MOVE.L D1,(A1)+                                 ; set exception handler address
                DBF.W D0,.loop                                  ; update next exception vector, loop to $00000FAE
                BRA.W cp_do_protection_check                    ; continue as address $00000FCE

exception_vector_offsets
L00000FBE       dc.w    $059A, $051A, $00B6, $05DA, $061A ,$069A ,$051A, $00F0              ;................




                ;------------------- Do Protection Check ----------------------
                ; try to load data from the copylock track,
                ; check the values loaded from the track and calculate a 
                ; checksum/serial number for the copy protection check.
                ;
cp_do_protection_check                                          ; original routine address $00000FCE
                LEA.L  cp_exception_vectors_store(PC),A1        ; A1 = Address buffer of saved exception vectors $00000E50
                CLR.L  $001C(A1)                                ; clear copy protection checksum value $00000E6C
                BSR.W  cp_load_data1                            ; cp_load_data1, calls $00001070
                BEQ.W  cp_end_protection_check                  ; if Z = 1 then fail, jmp $0000136E

                MOVE.L #$00000006,D2                            ; D2 = loop counter
.retry_loop                                                      ; original address $00000FE0
                SUB.L  #$00000001,D2                            ; D2 = decrement by 1
                BEQ.B  exit_do_protection_check                 ; if D2 = 0 then jmp $00001044

                LEA.L  cp_mfm_buffer(PC),A0                     ; $00000DCA
                MOVE.L #$00000005,D0
                BSR.W  cp_load_data2                            ; read from disk - calls $000010B4
                MOVE.L D0,D3                                    ; D0,D3 = num bytes read

                MOVE.L #$00000004,D0
                BSR.W  cp_load_data2                            ; read from disk - calls $000010B4
                MOVE.L D0,D1                                    ; D1 = num bytes read (cp_load_data2 - 2nd read)
                MOVE.L D3,D0                                    ; D0 = num bytes read (cp_load_data2 - 1st read)
                BSR.B  cp_check_bytes_read                      ; check bytes read, $00001058
                BMI.B  .retry_loop                               ; if N = 1 then retry, jmp $00000FE0

                MOVE.L #$00000006,D0
                BSR.W  cp_load_data2                            ; calls $000010B4
                MOVE.L D3,D1                                    ; D1 = num bytes read (cp_load_data2 - 1st read)
                                                                ; D0 = num bytes read (cp_load_data2 - 3rd read)
                BSR.B  cp_check_bytes_read                      ; check bytes read, $00001058
                BMI.B  .retry_loop                               ; if N = 1 then retry, jmp $00000FE0

                CMP.L  #'Rob ',(A0)                             ; #$526f6220,(A0)
                BNE.B  .retry_loop                               ; $00000FE0

                CMP.L  #'Nort',$0004(A0)                        ; #$4e6f7274,$0004(A0)
                BNE.B  .retry_loop                               ; $00000FE0

                CMP.L  #'hen ',$0008(A0)                        ;  #$68656e20,$0008(A0)'
                BNE.B  .retry_loop                               ; $00000FE0

                CMP.L  #'Comp',$000c(A0)                        ; #$436f6d70,$000c(A0)
                BNE.B  .retry_loop                               ; $00000FE0

                ; update copy protection checksum/serial no. 
                MOVE.L #$00000005,D1                            ; D1 = loop counter 5 + 1
                MOVEA.L A0,A1                                   ; A1 = decoded copy protection data buffer
.checksum_loop
                ADD.L  (A1)+,D0                                 ; D0 = add next long word of buffer data
                ROL.L  #$00000001,D0                            ; D0 = rotate data left
                DBF.W  D1,.checksum_loop                        ; loop through 6 long words (24 bytes)

                LEA.L  cp_exception_vectors_store(PC),A1        ; $00000E50
                ADD.L  D0,$001C(A1)                             ; update copy protection checksum $00000E6C

exit_do_protection_check                                        ; original address $00001044
                MOVE.W cp_saved_track_number(PC),D2             ; $00000E78
                BSR.W  cp_seek_to_track                         ; D2.w = track number, calls $0000124C
                BSR.W  cp_drive_off                             ; switch drive motor off $0000121A
                MOVE.L cp_checksum_vector(PC),D0                ; $00000E6C
                BRA.W  cp_end_protection_check                  ; jmp $0000136E




                ;------------------------ check bytes read --------------------------
                ; checks the number of bytes read in by successive calls to
                ; cp_load_data2, best I can work out is that the values readd in
                ; are checked to see if the difference between the number of bytes
                ; read in by successive calls to 'cp_load_data2' fall within
                ; the allowed tolerance.  Will revisit this after having a think...
                ;
                ; IN: D0.l - Count of previous bytes read
                ; IN: D1.l - COunt of previous bytes read
                ; OUT: D0.l - 0 = Success, -1 = Fail
                ;
cp_check_bytes_read                                             ; original routine address $00001058
                SUB.L  D1,D0
                BMI.B  .check_error                             ; jmp $0000106C
                MULU.W #$0064,D0
                DIVU.W D1,D0
                CMP.B  #$03,D0
                BLT.B  .check_error                             ; jmp $0000106C
                MOVE.L #$00000000,D0
                RTS 
.check_error
                MOVE.L #$ffffffff,D0
                RTS 




                ;------------------------------ Load Data 1 -------------------------------
                ; this routine cycles through the disk drives and reads in data in to
                ; the 'cp_mfm_buffer' for copy protection processing.
                ; it works by, selecting the current drive, seeking to track 0,
                ; selecting a sync mark from 'cp_disk_sync_table', then 
                ; calling 'cp_read_disk' to read the data.
                ; it will retry 3 times on a read error, and also try all connected drives.
                ; IN: D0.w = current drive
                ; IN: D1.w = current track
cp_load_data1                                           ; original routine address $00001070
                MOVE.L  #$00000003,D3                   ; disk drive retry count (next drive retry)
retry_next_drive
                BSR.W   cp_drive_on                     ; Switch on Current Drive $00000E74, calls $00001206
                BNE.B   try_next_drive                  ; Z = 0, fail, jmp $0000109C
                MOVE.L  #$00000000,D2                   ; D2 = desired track number
                BSR.W   cp_seek_to_track                ; D2.w = track number, calls $0000124C
                BNE.B   try_next_drive                  ; Z = 0, fail, jmp $000109C
                ; read from disk
                LEA.L   cp_mfm_buffer(PC),A0            ; A0 = mfm read buffer, $00000DCA
                MOVE.L  #$00000002,D2                   ; D2 = read retry count
retry_read_disk
                MOVE.W  cp_disk_sync_table(PC),D0       ; D0 = first disk sync number from address $000011EA
                BSR.W   cp_read_disk                    ; calls $00001134
                BNE.B   exit_load_data1                 ; Z = 0, success, jmp $000010B2
                ; read fail, retry
                DBF.W   D2,retry_read_disk              ; retry the read, jmp $00001086
                ; failed to read, reset drive
                MOVE.W  cp_saved_track_number(PC),D2    ; $00000E78(PC),D2
                BSR.W   cp_seek_to_track                ; D2.w = track number, calls $0000124C
try_next_drive
                BSR.W   cp_drive_off                    ; turn drive off, calls $0000121A
                LEA.L   cp_current_drive(PC),A0         ; get current drive number ,$00000E74(PC),A0
                ADD.W   #$0001,(A0)                     ; increase drive number
                AND.W   #$0003,(A0)                     ; clamp drive number to range 0-3
                DBF.W   D3,retry_next_drive             ; retry next drive number, jmp $00001072
                ; all drives failed
                MOVE.L  #$00000000,D0                   ; Z = 1, failed return code.
exit_load_data1
                RTS 




cp_load_data2                                                   ; original routine address $000010B4
                MOVEM.L D0-D2/A0-A1,-(A7)
L000010B8       BSR.B   L0000110A
L000010BA       MOVE.L  D0,D2
L000010BC       MOVE.L  (A7),D0
L000010BE       LEA.L   cp_disk_sync_table(PC),A1               ; $000011EA(PC),A1
L000010C2       LSL.L   #$00000001,D0
L000010C4       MOVE.W  $00(A1,D0.L),D0
L000010C8       MOVE.L  D0,D1
L000010CA       MOVE.L  D1,D0
L000010CC       BSR.B   cp_read_disk                            ; calls $00001134
L000010CE       BEQ.B   L000010CA
L000010D0       MOVE.L  D0,(A7)
L000010D2       MOVE.W  (A0),D0
L000010D4       EOR.W   D2,D0
L000010D6       AND.W   #$5555,D0
L000010DA       BNE.B   L000010CA
L000010DC       MOVEA.L A0,A1
L000010DE       TST.W   (A0)+
L000010E0       MOVE.L  #$0000000b,D1
L000010E2       MOVE.L  (A0)+,D0
L000010E4       BSR.W   L000010F4
L000010E8       MOVE.W  D0,(A1)+
L000010EA       DBF.W   D1,L000010E2
L000010EE       MOVEM.L (A7)+,D0-D2/A0-A1
L000010F2       RTS 


L000010F4       MOVEM.L D1-D2,-(A7)
L000010F8       MOVE.L  D0,D1
L000010FA       MOVE.L  #$0000000f,D2
L000010FC       ROXL.L  #$00000002,D1
L000010FE       ROXL.L  #$00000001,D0
L00001100       DBF.W   D2,L000010FC
L00001104       MOVEM.L (A7)+,D1-D2
L00001108       RTS 


L0000110A       MOVEM.L D1-D2,-(A7)
L0000110E       SWAP.W  D0
L00001110       MOVE.L  D0,D2
L00001112       MOVE.L  #$0000000f,D1
L00001114       LSL.L   #$00000002,D0
L00001116       ROXL.L  #$00000001,D2
L00001118       BCS.B   L00001126
L0000111A       BTST.L  #$0002,D0
L0000111E       BNE.B   L0000112A
L00001120       BSET.L  #$0001,D0
L00001124       BRA.B   L0000112A
L00001126       BSET.L  #$0000,D0
L0000112A       DBF.W   D1,L00001114
L0000112E       MOVEM.L (A7)+,D1-D2
L00001132       RTS 


cp_read_disk                                            ; original routine adsdress $00001134
                MOVEM.L D1-D4/A0-A1,-(A7)
L00001138       MOVEA.L A0,A1
L0000113A       LEA.L   $00dff000,A0
L00001140       MOVE.W  D0,$007e(A0)
L00001144       BSR.W   cp_initialise_drive             ; motor on, current drive select, calls $00001332
L00001148       MOVE.W  #$4000,$0024(A0)
L0000114E       MOVE.L  A1,$0020(A0)
L00001152       MOVE.W  #$6600,$009e(A0)
L00001158       MOVE.W  #$9500,$009e(A0)
L0000115E       MOVE.W  #$8010,$0096(A0)
L00001164       MOVE.W  #$0002,$009c(A0)
L0000116A       BSR.W   L0000117C
L0000116E       MOVE.W  #$0400,$009e(A0)
L00001174       TST.L   D0
L00001176       MOVEM.L (A7)+,D1-D4/A0-A1
L0000117A       RTS 




L0000117C       ILLEGAL                                     ; normally switch off TVD here, this routine would not be encoded (manual disk ready needs performance)
L0000117E       TST.B   $00bfdd00
L00001184       BTST.B  #$0004,$00bfdd00
L0000118C       BEQ.B   L00001184
L0000118E       MOVE.W  #$8000,$0024(A0)
L00001194       MOVE.W  #$8000,$0024(A0)
L0000119A       MOVE.L  #$00000000,D1
L0000119C       MOVE.L  #$00061a80,D2
L000011A2       SUB.L   #$00000001,D2
L000011A4       BEQ.B   L000011D0
L000011A6       MOVE.B  $001a(A0),D0
L000011AA       BTST.L  #$0004,D0
L000011AE       BEQ.B   L000011A2
L000011B0       MOVE.L  #$00000031,D2
L000011B2       ADD.L   #$00000001,D1
L000011B4       MOVE.W  $001a(A0),D0
L000011B8       BPL.B   L000011B2
L000011BA       MOVE.B  D0,(A1)+
L000011BC       DBF.W   D2,L000011B2
L000011C0       MOVE.W  #$03cd,D2
L000011C4       ADD.L   #$00000001,D1
L000011C6       MOVE.W  $001a(A0),D0
L000011CA       BPL.B   L000011C4
L000011CC       DBF.W   D2,L000011C4
L000011D0       MOVE.W  $001e(A0),D0
L000011D4       MOVE.W  #$0002,$009c(A0)
L000011DA       MOVE.W  #$4000,$0024(A0)
L000011E0       BTST.L  #$0001,D0
L000011E4       BNE.B   L00001200
L000011E6       MOVE.L  #$00000000,D1
L000011E8       BRA.B   L00001200

cp_disk_sync_table                              ; original address $000011EA
                dc.w    $8A91, $8A44, $8A45, $8A51, $8912, $8911, $8914, $8915      ;...D.E.Q........
                dc.w    $8944, $8945, $8951                                         ;.D.E.Q

L00001200       MOVE.L D1,D0
L00001202       ILLEGAL                                 ; normally switch on TVD again (encode/decode instructions again)
L00001204       RTS 




                ;-------------------------- drive on ---------------------------
                ; switch current drive motor on 'cp_current_drive' $00000E74
                ; 
cp_drive_on                                                 ; original routine address $00001206
                MOVEQ   #$ffffffff,D1                       ; deselect all drive bits
                BCLR.L  #$0007,D1                           ; select drive motor on (active low)
                BSR.B   cp_drive_motor                      ; calls $0000121C
                MOVE.L  #$000927c0,D0                       ; D0 = 600,000 (processor wait divides this by 32 = 18,750)
                BSR.W   cp_processor_wait_loop              ; calls $00001366
                BRA.B   cp_is_drive_ready                   ; jmp $00001230




                ;------------------------- drive off --------------------------
                ; deselect all drive bits, drop through to cp_drive_motor()
                ;
cp_drive_off                                                ; original routine address $0000121A
                MOVEQ   #$ffffffff,D1                       ; deselect all drive bits (incl. motor off)




                ;------------------------- drive motor ------------------------
                ; used by drive on/off routines to latch the motor state
                ; of the current drive.
                ; IN: D1.b = drive control bits (motor on/off bits set or cleared)
                ;
cp_drive_motor                                              ; original routine address $0000121C
                LEA.L   $00bfd100,A0                        ; A0 = CIAB PRB - drive control byte
                MOVE.B  D1,(A0)                             ; set motor state (has to be done before selecting the drive)                            
                MOVE.W  cp_current_drive(PC),D0             ; D0 = current drive number - $00000E74(PC),D0
                ADD.L   #$00000003,D0                       ; D0 = shift value to drive select bit
                BCLR.L  D0,D1                               ; Set Drive Select bit = 0 (active low)
                MOVE.B  D1,(A0)                             ; CIAB PRB - store value in drive control byte
                RTS 




                ;-------------------- is drive ready --------------------
                ; wait until drive is ready (RDY pulled low), or until
                ; processor timeout loop expires (a bit dodgy, should be a 
                ; timer wait or vbl wait)
                ; 
                ; OUT: D0 = 0 success, D0 = -1 failed
                ;
cp_is_drive_ready
                LEA.L   $00bfe001,A0                        ; A0 = CIAB PRA - Drive status byte
                MOVE.L  #$0000061A,D0                       ; processor timeout loop (a bit dodgy)
.rdy_wait
                BTST.B  #$0005,(A0)                         ; test drive RDY bit (ready)
                BEQ.B   .is_rdy                             ; drive RDY bit active low, jmp $00001248
                SUB.L   #$00000001,D0                       ; decrement timeout loop counter
                BPL.B   .rdy_wait                           ; time out loop, jmp $0000123C
                RTS 
.is_rdy
                MOVE.L #$00000000,D0                        ; set success return code.
                RTS 




                ;------------------------ seek to track ----------------------------
                ; steps the currently selected disk drive's heads to the desired
                ; track number.
                ; IN: D2.W = desired track number
                ;;
cp_seek_to_track                                            ; original routine address $0000124C
                MOVEM.L D1-D5,-(A7)                         ; save registers on stack
L00001250       MOVE.W  D2,D5                               ; D2.W, D5.w = desired track number
L00001252       BSR.W   cp_initialise_drive                 ; motor on, current drive select, calls $00001332
L00001256       AND.W   #$007f,D5
L0000125A       BEQ.B   L00001268
L0000125C       MOVE.W  cp_current_drive(PC),D0                             ;  $00000E74(PC),D0
L00001260       BSR.W   L0000129C
L00001264       MOVE.W  D1,D4
L00001266       BPL.B   L00001270
L00001268       BSR.W   L000012A8
L0000126C       BNE.B   L00001296
L0000126E       MOVE.L  #$00000000,D4
L00001270       CMP.W   D4,D5
L00001272       BEQ.B   L00001282
L00001274       BLT.B   L0000127C
L00001276       BSR.B   L000012E8
L00001278       ADD.L   #$00000001,D4
L0000127A       BRA.B   L00001270
L0000127C       BSR.B   L000012E4
L0000127E       SUB.L   #$00000001,D4
L00001280       BRA.B   L00001270
L00001282       BSR.W   cp_initialise_drive                     ; motor on, current drive select, calls $00001332
L00001286       MOVE.W  cp_current_drive(PC),D0                             ; $00000E74(PC),D0
L0000128A       LSL.W   #$00000001,D0
L0000128C       LEA.L   cp_current_track(PC),A0                             ; $00000E70(PC),A0
L00001290       MOVE.W  D4,$00(A0,D0.W)
L00001294       MOVE.L  #$00000000,D0
L00001296       MOVEM.L (A7)+,D1-D5
L0000129A       RTS 


L0000129C       LSL.W   #$00000001,D0
L0000129E       LEA.L   cp_current_track(PC),A0                             ; $00000E70(PC),A0
L000012A2       MOVE.W  $00(A0,D0.W),D1
L000012A6       RTS 


L000012A8       MOVEM.L D1-D4,-(A7)
L000012AC       MOVE.L  #$00000055,D4
L000012AE       BTST.B  #$0004,$00bfe001
L000012B6       BEQ.B   L000012C4
L000012B8       BSR.W   L000012E4
L000012BC       DBF.W   D4,L000012AE
L000012C0       MOVE.L  #$ffffffff,D0
L000012C2       BRA.B   L000012DE
L000012C4       MOVE.W  cp_current_drive(PC),D0                             ; $00000E74(PC),D0
L000012C8       LSL.W   #$00000001,D0
L000012CA       LEA.L   cp_current_track(PC),A0                             ; $00000E70(PC),A0
L000012CE       CLR.W   $00(A0,D0.W)
L000012D2       MOVE.L  #$00000055,D0
L000012D4       SUB.L   D4,D0
L000012D6       LEA.L   cp_saved_track_number(PC),A0                        ; $00000E78(PC),A0
L000012DA       MOVE.W  D0,(A0)
L000012DC       MOVE.L  #$00000000,D0
L000012DE       MOVEM.L (A7)+,D1-D4
L000012E2       RTS 


L000012E4       MOVE.L  #$00000001,D2
L000012E6       BRA.B   L000012EA
L000012E8       MOVE.L  #$00000000,D2
L000012EA       MOVE.W  cp_current_drive(PC),D0                             ; $00000E74(PC),D0
L000012EE       MOVE.W  cp_protection_track(PC),D1                          ; $00000E76(PC),D1
L000012F2       MOVE.B  $00bfd100,D3
L000012F8       OR.B    #$7f,D3
L000012FC       ADD.B   #$03,D0
L00001300       BCLR.L  D0,D3
L00001302       SUB.B   #$03,D0
L00001306       TST.B   D1
L00001308       BEQ.B   L0000130E
L0000130A       BCLR.L  #$0002,D3
L0000130E       TST.B   D2
L00001310       BNE.B   L00001316
L00001312       BCLR.L  #$0001,D3
L00001316       BCLR.L  #$0000,D3
L0000131A       MOVE.B  D3,$00bfd100
L00001320       BSET.L  #$0000,D3
L00001324       MOVE.B  D3,$00bfd100
L0000132A       MOVE.L  #$00000bb8,D0
L00001330       BRA.B   cp_processor_wait_loop                              ; calls $00001366




                ;----------------------- initialise_drive ---------------------------
                ; initialise the current drive 'cp_current_drive', 
                ;
cp_initialise_drive                                     ; original routine address $00001332
                MOVE.W  cp_current_drive(PC),D0         ; D0 = current drive number, $00000E74(PC),D0
                MOVE.W  cp_protection_track(PC),D1      ; D1 = protection track number, $00000E76(PC),D1
                MOVE.W  D2,-(A7)                        ; save D2 on stack
                MOVE.B  $00bfd100,D2                    ; CIAB PRB - Disk control bits
                OR.B    #$7f,D2                         ; select motor on MTR (bit 7 active low)
                ADD.B   #$03,D0                         ; shift current dive number to Select bits
                BCLR.L  D0,D2                           ; select the current drive (active low)
                SUB.B   #$03,D0                         ; return current drive to drive number
                TST.B   D1                              ; test protection track number
                BEQ.B   skip_select_disk_side           ; if == 0, jmp $00001358   
select_disk_side                    
                BCLR.L  #$0002,D2                       ; if !=0 select disk side
skip_select_disk_side
                MOVE.B  D2,$00bfd100                    ; Select drive, with motor on
                MOVE.L  #$000005dc,D0                   ; processor wait loop count $5DC = 1500 (very dodgy)
                MOVE.W  (A7)+,D2                        ; restore D2 from stack
                ; drop thorugh to cp_processor_wait




                ;-------------------------- processor wait loop ---------------------------
                ; this routine uses the process to perform a busy wait for delays.
                ; disk routines require various delays between various disk ops to
                ; allow the mechanics of the drive to preform the operation and become
                ; ready for use with in a defined specificaiton. 
                ; The H/W reference guide frowns upon processor wait loops because they 
                ; are not constant on the Amiga, different processors/system config can
                ; make processor loops unreliable.
                ; best practice is to use CIA timers or VBL waits.
                ; I guess no body cared or only expected this to work on bog-standard A500
                ;
cp_processor_wait_loop                                                      ; original routine address $00001366
                LSR.L   #$00000005,D0                                       ; divide D0 by 32
.wait_loop      SUB.L   #$00000001,D0                                       ; decrement counter by 1
                BNE.B   .wait_loop                                          ; if D0 != 0, loop
                RTS 



cp_end_protection_check                                             ; original routine address $0000136E
                LEA.L   cp_register_store(PC),A0                    ; L00000E10(PC),A0
                MOVE.L  D0,(A0)
                MOVEM.L cp_exception_vectors_store(PC),D0-D7        ; L00000E50(PC),D0-D7
                MOVE.L  $00000004,D0
                MOVE.L  D0,D1
                LEA.L   cp_end(PC),A0                               ; A0 = address of 'cp_end' - copy protection return address.
                MOVE.L  A0,$0002(A7)                                ; modify the return from exception (RTE) to return to 'cp_end' instead of original 'ILLEGAL' instruction
                ILLEGAL                                             ; normally this would toggle of the Trace Vector Decoder routine.
                MOVEM.L D0-D7,$00000008
                MOVEM.L cp_register_store(PC),D0-D7/A0-A6           ; L00000E10(PC),D0-D7/A0-A6
                RTE                                                 ; Return from copy protection exception to $0000139C below.


                ;------------------- end of copy protection ----------------------------
cp_end                                                              ; original routine start address $0000139C
                MOVE.L  #$00000000,D0
                MOVE.W  #$0001,ld_load_status                       ; $00001b08 ; set load status
                MOVEM.L (A7)+,D0-D7/A0-A6
                TST.W   ld_load_status                              ; $00001b08 ; test load status
                RTS                                                 ; return from initial call to 'loader'



                ;----------------- end of copy protection routines ----------------------









                ;---------------------- wrong disk in the drive -------------------------
                ;-- IN: A0.l - ptr to disk name
                ;--
wait_for_correct_disk                                               ; relocated address $000013B2
L000013B2       MOVE.L  A0,-(A7)
                LEA.L   L00002334(PC),A0                            ; Disk logo?
                LEA.L   $00007700,A1
                LEA.L   copper_colours(PC),A2                       ; Get copper bitplane display colours. addr $000014B8

.set_background_disk_image
                BSR.W   unpack_disk_logo                            ; calls $0000153C
                
.set_disk1_or_2
                LEA.L   L00002254(PC),A0                            ; A0 = Image Data ptr for the number '1'
                MOVEA.L (A7),A1                                     ; A1 = Get Disk Name string ptr
                CMP.B   #$30,$000f(A1)                              ; #$30 = '0' - Check if disk number at end of disk name is '0' 
                BEQ.B   .copy_disk_number                           ; if '0' continue to copy number to disk  image, jmp $000013D8
.disk_2
                LEA.L   $0070(A0),A0                                ; A0 = Updated Image Data ptr for the number 2

.copy_disk_number
                LEA.L   $00007700,A1                                ; A1 = 
                ADDA.W  #$1643,A1
                MOVE.L  #$0000000d,D0                               ; 13 + 1 - loop counter (14 scan lines high x 16 pixels wide)
.disk_number_loop
                MOVE.B  (A0)+,$0000(A1)                             ; Bitplane 1
                MOVE.B  (A0)+,$0001(A1)
                MOVE.B  (A0)+,$2800(A1)                             ; Bitplane 2
                MOVE.B  (A0)+,$2801(A1)
                MOVE.B  (A0)+,$5000(A1)                             ; Bitplane 3
                MOVE.B  (A0)+,$5001(A1)
                MOVE.B  (A0)+,$7800(A1)                             ; Bitplane 4
                MOVE.B  (A0)+,$7801(A1)
                SUBA.W  #$0028,A1                                   ; Increase base bitplane ptr offset by 40 bytes (320 pixels = one scan line)
                DBF.W   D0,.disk_number_loop

.display_insert_disk
                LEA.L   $00dff000,A6                                ; A6 = custom base
                LEA.L   COLOR00(A6),A0                              ; A0 = colour 00 register
                MOVE.L  #$0000001f,D0                               ; 31 + 1 - loop counter
.clear_loop
                CLR.W   (A0)+                                       ; Clear Colopur Register (CLR not good to use on Write only Custom Chip Register)
                DBF.W   D0,.clear_loop                              ; clear pallete loop, $00001418 (no need as copper will refresh colours at top of each frame)

.set_up_display
                MOVE.W  #$0000,BPL1MOD(A6)                          ; Bitplane Modulo 0 
                MOVE.W  #$0000,BPL2MOD(A6)                          ; Bitplane Modulo 1
                MOVE.W  #$0038,DDFSTRT(A6)                          ; Bitplane Data DMA Fetch Start
                MOVE.W  #$00d0,DDFSTOP(A6)                          ; Bitplane Data DMA Fetch Stop
                MOVE.W  #$4481,DIWSTRT(A6)                          ; Display Window Start
                MOVE.W  #$0cc1,DIWSTOP(A6)                          ; Display Window Stop
                MOVE.W  #$4200,$0100(A6)                            ; 4 bitplane display, Color On, (16 colour display)
                LEA.L   copper_list(PC),A0                          ; A0 = Copper List 1 Address
                MOVE.L  A0,$0080(A6)                                ; Set Copper List 1 
                LEA.L   copper_endwait(PC),A0                       ; A0 = Copper List 2 Address (End Wait) addr: $00001538
                MOVE.L  A0,$0084(A6)                                ; Set Copper List 2
                MOVE.W  A0,$008a(A6)                                ; Strobe Copper Jump 2 - Force Copper to execute copper 2 (will revert to copper 1 on next frame)
                MOVE.W  #$8180,$0096(A6)                          ; Enable Copper & Bitplane DMA
.disk_wait_loop
                CLR.W   ciab_tb_20ms_tick                           ; reset 20ms timer tick counter
.timer_wait_loop
                CMP.W   #$0032,ciab_tb_20ms_tick                    ; #$ = 50 (50 x 20 = 1000ms) 1 second wait loop
                BCS.B   .timer_wait_loop                            ; busy wait for 1 second

                MOVEA.L (A7),A0                                     ; Disk Name String Ptr
                BSR.W   load_filetable                              ; Load the Disk File Table, calls $000015DE
                BNE.B   .disk_wait_loop                             ; Z = 0, then not correct disk in the drive
.clear_display
                LEA.L   $00dff000,A6
                MOVE.W  #$0200,$0100(A6)                            ; BPLCON = 0 bitplanes display (switch off all bitplane DMA channels)
                MOVE.W  #$0180,$0096(A6)                          ; disbale copper & bitplane DMA
.exit                
                MOVEA.L (A7)+,A0                                    ; restore A0 = disk name string ptr
                RTS 





                    ;------------------- loader copper list -------------------------
                    ; used to display change disk screen & loading picture

copper_list     ; copper-list - set bitplane pointers -  relocated address $00001490
                dc.w    BPL1PTH, $0000                      ; bit-plane 1 ptr
                dc.w    BPL1PTL, $7700              
                dc.w    BPL2PTH, $0000                      ; bit-plane 2 ptr
                dc.w    BPL2PTL, $9F00
                dc.w    BPL3PTH, $0000                      ; bit-plane 3 ptr
                dc.w    BPL3PTL, $C700
                dc.w    BPL4PTH, $0000                      ; bit-plane 4 ptr
                dc.w    BPL4PTL, $EF00
                dc.w    BPL5PTH, $0001                      ; bit-plane 5 ptr
                dc.w    BPL5PTL, $1700        
copper_colours  ; copper-list - set bitplane colour pallette - relocated address: $000014B8
                dc.w    COLOR00, $0000, COLOR01, $0000, COLOR02, $0000, COLOR03, $0000
                dc.w    COLOR04, $0000, COLOR05, $0000, COLOR06, $0000, COLOR07, $0000
                dc.w    COLOR08, $0000, COLOR09, $0000, COLOR10, $0000, COLOR11, $0000
                dc.w    COLOR12, $0000, COLOR13, $0000, COLOR14, $0000, COLOR15, $0000
                dc.w    COLOR16, $0000, COLOR17, $0000, COLOR18, $0000, COLOR19, $0000
                dc.w    COLOR20, $0000, COLOR21, $0000, COLOR22, $0000, COLOR23, $0000
                dc.w    COLOR24, $0000, COLOR25, $0000, COLOR26, $0000, COLOR27, $0000
                dc.w    COLOR28, $0000, COLOR29, $0000, COLOR30, $0000, COLOR31, $0000       
copper_endwait  ; copper-list - copper end - relocated address: $00001538
                ; also used to set second copper list address to an empty copper list.
                dc.w    $FFFF, $FFFE                            




                ;----------------------- unpack disk logo -------------------------
                ;-- unpack the insert disk image into memory buffer for later use
                ;-- appears to implement a basic compression supporting the
                ;-- insertion of repeating word values to reconstruct the image.
                ;-- *** needs more work to understand fully ***
                ;-- IN: A0 = Compressed Logo
                ;-- IN: A1 = $7700 - Uncompressed logo buffer
                ;-- IN: A2 = Copper List Colours
                ;--
unpack_disk_logo:
                MOVEM.L D0-D1/D7/A0-A3,-(A7)
                MOVE.B  (A0)+,D0                        ; get first data byte
                CMP.B   #$03,D0                         ; compare the first data byte with the value #3                  
                BCS.B   .skip_add_addr                  ; if D0.b < #03 then skip add instruction (what's the significance of #$03??)
.add_addr       ADDA.L  #$00000004,A0                   ; else, add 4 bytes to the address pointer
.skip_add_addr
                MOVE.L  #$0000000f,D0                   ; 15 + 1 loop counter (16 colours)
.set_colour_loop
                ADDA.W  #$00000002,A2
                MOVE.B  (A0)+,(A2)+
                MOVE.B  (A0)+,(A2)+
                LSL.W   -$0002(A2)                      ; correct colours by multiplying them by 2
                DBF.W   D0,.set_colour_loop             ; $0000154C - set first 16 of 32 copper colour registers.

                ; get next word from logo data into d7 
                MOVE.B  (A0)+,D7                        ; set d7 with low byte value
                ASL.W   #$00000008,D7                   ; shift d7 into high byte
                MOVE.B  (A0)+,D7                        ; set d7 with high byte value

                ADDA.L  #$00000002,A0                   ; skip next word in data structure

                LEA.L   $00(A0,D7.W),A2                 ; D7 is an index into the logo data, A2 = new data pointer
                SUB.W   #$0001,D7                       ; decrement index.
                BMI.B   .exit                           ; if index is negative then exit, jmp $000015B6

                LEA.L   $1f40(A1),A3                    ; A3 = $7700 + $1f40 = $9640 - ($1f40 - 8000) (8000/40 = 200 - could be bitplane size) 

  
                ; basic unpacker replacing repeating values
                ; d7 = outer loop counter
                ; a0/a2 = source logo data
                ; a1/a3 = dest logo data
.outer_loop
                MOVE.B  (A0)+,D0                        ; get command byte
                BMI.B   .copy_multiple_words            ; if byte < 0,  jmp $001584  (copy x words from source -> dest) 
                BEQ.B   .copy_repeating_word            ; if byte == 0, jmp $0001596 (insert x repeating words -> dest)                                                      
                CMP.B   #$01,D0                             
                BNE.B   .copy_one_word                  ; if byte == 1, jmp $00015A0 (copy 1 word from source -> dest)
.copy_multiple_words2
                MOVE.B  (A0)+,D0                        ; else (copy large number of words from source -> dest)
                ASL.W   #$00000008,D0
                MOVE.B  (A0)+,D0
                SUB.W   #$00000002,D7                   ; subtract 2 from outer loop counter
                BRA.B   .copy_bytes                     
.copy_multiple_words                                    ; copy multiple words from source to destination
                NEG.B   D0                              ; make counter positive.
                EXT.W   D0                              ; make counter positive word.

.copy_bytes     ; d0 = .loop1 counter, d7 = .outer_loop counter
                SUB.W   #$0001,D0                      ; subtract 1 from the counter
.loop1
                MOVE.B  (A2)+,(A1)+                     ; copy source byte data (gfx?) to dest a1 ($7700 first interation)
                MOVE.B  (A2)+,(A1)+                     ; copy source byte data (gfx?) to dest a1 ($7700 first interation)
                BSR.B   update_dest_bitplane_ptr        ; call $000015BC
                DBF.W   D0,.loop1                                ; $0000158A

                BRA.B   .next_outer_loop


.copy_repeating_word
                MOVE.B  (A0)+,D0
                ASL.W   #$00000008,D0
                MOVE.B  (A0)+,D0                        ; d0 = repeat count
                SUB.W   #$00000002,D7                   ; d7 = outer loop count
                BRA.B   .get_repeating_value        
.copy_one_word
                EXT.W   D0                              ; d0 = 1, extend to word 

.get_repeating_value
                SUB.W   #$0001,D0                       ; decrement loop counter
                MOVE.B  (A2)+,D1
                ASL.W   #$00000008,D1
                MOVE.B  (A2)+,D1                        ; D1 = repeating word value

.repeating_word_loop
                MOVE.W  D1,(A1)+                        ; copy repeating word to destination address
                BSR.B   update_dest_bitplane_ptr        ; $000015BC
                DBF.W   D0,.repeating_word_loop         ; $000015AA

.next_outer_loop
                DBF.W   D7,.outer_loop                          ; $0000156E

.exit
                MOVEM.L (A7)+,D0-D1/D7/A0-A3
                RTS 


                ; ------------------------ update destination bitplane pointers -------------------------
                ; Best I can make out is that the source data might bbe arranged in columns and not
                ; scanlines, this routine appears to be increasing the destination pointer by one
                ; scanline on each loop. This implies that the disk image is being reconstructed
                ; one column at a time, from  left to right and top to bottom of the screen.
                ; (maybe some Atari ST bullshit format? who knows, maybe i'm just wrong.)
                ;
                ; Data seems to be unpacked one bitplane at a time. When the destination address reached the
                ; bottom of a column, then the ptr is updated to the top of the next column by subtracting
                ; the size of the bitplane-2 from the current address #$1f3e.
                ;
                ; When the end of the last column is reached then a large ptr adjustment is made, by subtracting
                ; 55336 bytes from the destination ptr (this leads me to believe that i'm missing something here
                ; because thats a big number (almost 64K))
                ;
                ; d0 = loop counter
                ; A1 = destinaiton address buffer e.g. $7700
                ; A3 = another address buffer e.g.     $9640 ($7700 + $1F40)
                ;
update_dest_bitplane_ptr                                    ; relocated routine address: $000015BC
                MOVE.L  D0,-(A7)
                LEA.L   $0026(A1),A1        ; add 38 to destination address (40 + previously copied word) - scanline 320 wide screen
                MOVE.L  A1,D0               ; copy destination address to D0.L
                SUB.L   A3,D0               ; subtract start of next bitplane address from lower address
                BCS.B   .exit               ; if not at end of current bitplane yet then exit

.reset_dest_column                          ; jump to top of next bitplane column
                SUBA.W  #$1f3e,A1           ; update pointer back to 2nd word of source data
                CMP.W   #$0026,D0           ; #$26 = 38, test which column of data was just completed.
                BCS.B   .exit               ; If not last column of bitplane image data then exit. $000015DA
.next_bitplane
                SUBA.W  #$d828,A1           ; else (reset destination ptr 55336 bytes (thats a lot))
                LEA.L   $1f40(A1),A3        ; Increase boundary limit to start of next highest bitplane.
.exit
                MOVE.L  (A7)+,D0
                RTS 






                ;--------------------------- load file table --------------------------
                ;-- Checks the disk name and loads the file table for the disk name
                ;-- passed in here.
                ;-- IN: A0 - ptr to diskname string
                ;-- OUT: Z=1 - success
                ;--
                ;-- State:
                ;-- #$00002CD6,ld_decoded_track_ptr
                ;-- #$000042D6,ld_mfmencoded_track_ptr
                ;-- #$00002AD6,ld_filetable 
                ;--
load_filetable                                                  ; relocated address $000015DE
                MOVE.L  A0,-(A7)                                ; A0 = ptr to disk name string
                MOVE.W  #$0004,ld_drive_number                  ; $00001AFC ; $1AFC - drive number?
.select_next_drive
                MOVE.W  #$0005,ld_load_status                   ; $00001B08 ; set loader status
                MOVE.W  ld_drive_number,D0                      ; $00001AFC,D0 ; D0.w - drive number (initial value = 4)
.select_loop    SUB.W   #$00000001,D0                           ; decrement by 1 (initial value = 3)
                BMI.W   .exit                                   ; no drives left available, jmp $00001648 
                BTST.B  D0,ld_drive_bits_byte                   ; $00001AFB ; Bit field of available disk drives (initial check bit 3)
                BEQ.B   .select_loop                            ; $000015F6 ; If Drive is not available then loop next drive. (count from 3 to 0)

.select_drive   MOVE.W  D0,ld_drive_number                      ; $00001AFC ; store available drive number.

.init_drive
                BSR.W   drive_motor_on                          ; Drive Motor On: routine addr: $00001B68
                BSR.W   seek_track0                             ; calls $00001BAE
                BNE.B   .error                                  ; z = 0, error so jmp $0000163C
.load_filetable
                SF.B    ld_track_status                         ; $00001AF0
                MOVE.L  #$00000002,D0                           ; Sector Number of File Table
                BSR.W   load_decode_track                       ; calls $00001B0A
                BNE.B   .error                                  ; Z = 0, error so jmp $0000163C
.chk_diskname
                MOVEA.L (A7),A1                                 ; A1 = diskname pointer; A0 = loaded data address
                MOVE.L  #$0000000f,D0                           ; DiskName = 16 bytes
.diskname_loop
                CMPM.B  (A0)+,(A1)+                             ; compare disk name characters
                DBNE.W  D0,.diskname_loop                       ; disk name check loop $L00001626
                BNE.B   .error                                  ; final CCR check, if not equal, jmp $0000163C
.filetable_copy
                MOVEA.L ld_filetable,A1                         ; get file table address
                MOVE.L  #$0000007b,D0                           ; loop counter 123 + 1 (124 x 4 = 496). 496/16 = 31 (Max number of file table entries?)
.copy_loop
                MOVE.L  (A0)+,(A1)+                             ; copy file table data 
                DBF.W   D0,.copy_loop                           ; $00001634 ; loop for 124 long words
                BRA.B   .exit                                   ; bra $00001648
.error
                MOVE.W  ld_drive_number,D0                      ; $00001AFC
                BSR.W   drive_motor_off                         ; L00001B7A
                BRA.B   .select_next_drive                      ; try again with the next available disk drive, jmp $000015E8
.exit
                MOVEA.L (A7)+,A0                                ; relocated address $00001648
                TST.W   ld_load_status                          ; $00001B08 ; test load status ( z = 1 - success )
                RTS 


                ;------------------------ load file entries ------------------------
                ;-- loads files in to memory, starting at top of memory $7C7FC
                ;-- loads files from load parameter block, starting with the
                ;-- last file in the structure.
                ;--
                ;-- so, the last file is loaded at $7C7FC - filelen,
                ;--   , the next file is loaded at $7C7FC - filelen - filelen,
                ;--   , and so on, until all files are loaded in from disk.
                ;--
                ;-- parameters:
                ;-- IN: A0 = Entry to first file to load in the file list.
                ;-- IN: A6 = Top of load file buffer - (initially 0007C7FC) -grows downwards with each file loaded
                ;
load_file_entries                                       ; this routine's relocated address: $00001652
                MOVE.L  A0,-(A7)                        ; store address to file entry
                TST.W   (A0)                            ; if end of file entries?
                BEQ.B   .exit                           ;  - then exit - $000016D6
                LEA.L   $000e(A0),A0                    ;  - else calc address of next file entry in list
                BSR.B   load_file_entries               ;     & recursive call to self. addr $00001652 
                BNE.B   .exit                           ; if 'load status' is not equal 0 then exit. addr $000016D6

.prep_table_search
                MOVEA.L (A7),A0                         ; A0 = ptr for file entry
                ADDA.W  (A0),A0                         ; A0 = ptr to file name string to find in disk file table (disk directory)
                MOVEA.L ld_filetable,A1                 ; A1 = file table (disk directory)
                MOVE.L  #$0000001e,D0                   ; D0 = loop counter 30 + 1

.file_table_loop   
                MOVEA.L A0,A2                           ; A2 = copy ptr to to file name - $0000166A 
                MOVEA.L A1,A3                           ; A3 = copy ptr to file table

.compare_filename                                       ; relocated address: $0000166E
                MOVE.L  #$0000000a,D1                   ; D1 = loop counter 10 + 1 (filenames are 11 characters long)
.file_loop      CMPM.B  (A2)+,(A3)+                     ; compare file name character with file table entry. addr $00001670
                DBNE.W  D1,.file_loop                   ; loop next file name character
                BEQ.B   .filefound                      ; file table entry found....

                LEA.L   $0010(A1),A1                    ; increment to start of next file table entry
                DBF.W   D0,.file_table_loop             ; decrement file table search loop

                MOVE.W  #$0005,ld_load_status           ; $00001B08 ; set 'load status' = 5 - file not found
                BRA.B   .exit                           ; $000016D6


                ; file table entry has been found
                ; A0 = File Entry to load
                ;       0 - 2 Bytes - File Name Offset
                ;       2 - 4 bytes - File reloacation address
                ;       6 - 4 bytes - File Length Stored below from file table
                ;       a - 4 bytes - File Load Address stored below
                ; A3 = File Table Entry
                ;       - 11 characters = filename
                ;       - 3 bytes = 24 bit file length
                ;       - 2 bytes = start sector number
.filefound                                              ; relocated address: $0000168A 
.L0000168A       MOVEA.L (A7),A0                        ; File Entry to load
.L0000168C       MOVE.L  $000a(A1),D2                   ; Get File Length (and last character of filename) from file table (disk directory)
.L00001690       AND.L   #$00ffffff,D2                  ; D2 = 24 bit file length mask
.L00001696       MOVE.L  D2,$0006(A0)                   ; Save File length into Level Load Parameters current file entry (2nd long word)
.L0000169A       BEQ.B   .exit                          ; If file length is 0 then exit.

.L0000169C       MOVE.W  $000e(A1),D1                   ; D1 = start sector of file on disk
.L000016A0       MOVE.L  D2,D0                          ; D2,D0 = File Length in Bytes

.L000016A2       BTST.L  #$0000,D0                      ; Is file odd byte length?
.L000016A6       BEQ.B   .L000016AA                     ; no... no padding required
.L000016A8       ADD.L   #$00000001,D0                  ; yes.. add extra byte to make file length even

.L000016AA       SUBA.L  D0,A6                          ; Subtract File Length from current top of file buffer memory (file load address into buffer)
.L000016AC       MOVEA.L A6,A1                          ; A1, A6 = file load address in to memory buffer
.L000016AE       MOVE.L  A6,$000a(A0)                   ; store file load address into level load file entry table.

.load_loop
.L000016B2       MOVE.W  D1,D0                          ; D0, D1 = start sector on disk
.L000016B4       BSR.W   load_decode_track              ; calls $00001B0A ; track/part track from disk (a6,a1 = load address, d1,d0 = start sector, a0 = file entry) routine address: $00001B0A

.L000016B8       BNE.B   .L000016D6                     ; Z = 0 = error

.L000016BA       MOVE.L  #$00000200,D0                  ; d0 = 512
.L000016C0       CMP.L   D0,D2                          ; compare d2 with file length (d2 = number of bytes remaining?)
.L000016C2       BCC.B   .L000016C6

.L000016C4       MOVE.L  D2,D0                          ; copy bytes remaining into d0
.L000016C6       SUB.L   D0,D2                          ; clear d2
.L000016C8       SUB.W   #$00000001,D0                  ; decrement bytes remaining by 1
.L000016CA       MOVE.B  (A0)+,(A1)+
.L000016CC       DBF.W   D0,.L000016CA

.L000016D0       ADD.W   #$0001,D1                      ; Add 1 to track number
.L000016D2       TST.L   D2                             ; If bytes remaining
.L000016D4       BNE.B   .L000016B2                     ; yes... load next track/part track
                                                        ; no.... exit
.exit
.L000016D6       MOVEA.L (A7)+,A0                       ; A0 = entry to first file entry to load (restored from stack)
.L000016D8       TST.W   ld_load_status                 ; $00001B08 ; test 'load status' and exit.
.L000016DE       RTS 

















                ;----------------------------------------------------------------------------------------------------
                ;----------------------------------------------------------------------------------------------------
                ; PROCESS LOADED FILES
                ;----------------------------------------------------------------------------------------------------
                ;----------------------------------------------------------------------------------------------------
                ; Code to navigate and prcocess the loaded 'iff' formatted files. 
                ; It also provides a mechanism for copying non iff files to a relocated address.
                ; Much of the code is focused
                ; on navigating through the IFF structure until the code finds the 'chunks' containing the data
                ; of interest.
                ; The code appears spagetti-like, much duplication and some recursion, modification of stack
                ; values, quite untidy and difficult to follow the stack push and pops.
                ; Supprised there's no stack issues as some routines push values on the stack and then jump or bsr
                ; off into other routines. Obviously it must work, but could be massively refactored.
                ; maybe done in a rush?? who knows... 
                ;----------------------------------------------------------------------------------------------------
                ; Code files processed in - iff_inner_huff_chunk 
                ;                         - Best Guess, Huffman Endoded Chunk, (Googled, can't find any info) contains...
                ;                         - ID = 'HUFF', sub chunks/blocks
                ;                                        - ID = 'SIZE'
                ;                                        - ID = 'CODE'
                ;                                        - ID = 'TREE'
                ; Images processed in - iff_ilbm_chunk
                ;                           - Colours are stored at adress $000014B8 (copper_colours) registers of loader copper list.
                ;                           - Bitmap Header Address is stored in location: $00001A08 (bitmap_header_address)
                ;






                ;------------------------------- processs files ----------------------------------------
                ;-- process/relocate loaded files into memory,
                ;-- files have 'iff' extensions, even the executables (which i'm not familiar with)
                ;-- These routines process the iff files, skipping through their internal structure
                ;-- and copying their contents to the required memory destination locations.
                ;--
                ;-- Lots of drilling down through the file structures and faffing around - bear with me caller...
                ;-- 
                ;-- IN: ld_relocate_addr
                ;-- D0 = File Length/remaining bytes
                ;-- A0 = File Address      
process_file                                            ; relocated address: $000016E0
                MOVEM.L D0/A0,-(A7)
                TST.L   D0                              ; test file length
                BEQ.B   .exit_process_file              ; if file is 0 bytes in length then jmp $00001704
                CMP.L   #$0000000c,D0                   ; compare file length with len of 12 bytes
                BCS.B   .relocate_small                 ; if file len < 12 bytes then rolocate_small number of bytes $00001702

                MOVE.L  (A0),D1                         ; D1 = Iff Header Id Word
                CMP.L   #'FORM',D1                      ; Test for 'FORM' header - #$464f524d,D1
                BEQ.B   process_form_or_cat             ; jmp $0000171C
                CMP.L   #'CAT ',D1                      ; Test for 'CAT ' header - #$43415420,D1
                BEQ.B   process_form_or_cat             ; jmp $0000171C

.relocate_small
                BSR.B   relocate__bytes                 ; calls $0000170A

.exit_process_file
                MOVEM.L (A7)+,D0/A0
                RTS 




                ;----------------------------- relocate bytes -----------------------------
                ;-- copy bytes from source addr to a destination address (ld_relocate_addr)
                ;-- IN: A0 = source addr
                ;-- IN: D0 = number of bytes
                ;-- IN: ld_relocate_addr = dest addr
                ;
                ;-- OUT: A0 = incremented by number of words copied
                ;-- OUT: D0 = 0
                ;-- OUT: ld_relocate_addr = incrememented by number of words copied
                ;
relocate__bytes                                             ; relocated address: $0000170A
                MOVEA.L ld_relocate_addr,A1                 ; A1 = destination address, $00000CF0
                ASR.L   #$00000001,D0                       ; D0 = divide bytes by 2, copy words
.relocate_loop
                MOVE.W  (A0)+,(A1)+
                SUB.L   #$00000001,D0
                BNE.B   .relocate_loop                          ; loop until D0 = 0, jmp $00001710
                MOVE.L  A1,ld_relocate_addr                     ; update destination ptr $00000CF0
                RTS




                ;-------------------------- process form or cat ------------------------
                ;-- Process the 'FORM' or 'CAT ' chunk of the iff file.
                ;-- IN: A0 = start of chunk (ptr to ID)
                ;-- IN: D0 = File Length/remaining bytes
                ;-- IN: ld_relocate_addr = dest addr
                ;
process_form_or_cat
                TST.L   D0                              ; Test file length/bytes remaining
                BEQ.B   .exit_process_file              ; if end of file then .exit_process_file, jmp $0000172A
                MOVE.L  (A0)+,D1                        ; D1 = header id
                SUB.L   #$00000004,D0                   ; subtract 4 bytes from remaining file length
                BSR.W   iff_form_or_cat                 ; calls $00001730
                BRA.B   process_form_or_cat             ; loop to process form or cat, jmp $0000171C

.exit_process_file
                MOVEM.L (A7)+,D0/A0
                RTS                                     ; *** THIS RTS exits process_file or recursive call ***




                ;------------------------- iff form or cat -------------------------
                ;-- Another routine for processing 'FORM' or 'CAT' this time as a 
                ;-- more reusable sub routine.
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_form_or_cat
                CMP.L   #'FORM',D1                      ; Test for 'FORM' header Id, #$464f524d
                BEQ.W   iff_form                        ; jmp $00001766
                CMP.L   #'CAT ',D1                      ; Test for 'CAT ' header Id, #$43415420
                BEQ.W   iff_cat                         ; jmp $00001748
                CLR.L   D0
                RTS 




                ;-------------------------- iff cat --------------------------------
                ;-- process 'CAT ' chunk, appears to skip any chunks with the 'CAT ' Id
                ;-- updates the address pointer and remaining bytes held on the stack.
                ;--
                ;-- preserves remaining bytes & start address on stack
                ;--
                ;-- This looks nasty because it's pushing to
                ;-- the stack and not popping before jumping out of here.
                ;-- potential for all sorts of stack problems and corruption.
                ;-- it makes recursive calls to 'process_form_or_cat'.
                ;-- 
                ;-- IN: A0 = start of data chuck id
                ;-- IN: D0 = file length/remaining bytes
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
iff_cat                                                 ; relocate address $00001748
                MOVEM.L D0/A0,-(A7)                     ; save remaining bytes/chunk address ptr
                MOVE.L  (A0)+,D0                        ; D0 = chunk length
                MOVE.L  D0,D1                           ; D1 = chunk length

                BTST.L  #$0000,D1                       ; test if odd/even
                BEQ.B   .is_even                        ; if is even, jmp $00001758
                ADD.L   #$00000001,D1                   ; else add pad byte to length
.is_even
                ADD.L   #$00000004,D1                   ; add header id length to block length
                ADD.L   D1,$0004(A7)                    ; increase address on stack to point to end of block.
                SUB.L   D1,(A7)                         ; subtract length from remaining bytes held on stack.

                ADDA.L  #$00000004,A0                   ; skip long word
                SUB.L   #$00000004,D0                   ; subtract long from remaining bytes 

                BRA.B   process_form_or_cat             ; jmp to $0000171C, find next FORM/CAT to process




                ;------------------------- iff form -----------------------------
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_form                                                ; relocated addr $00001766
                MOVEM.L D0/A0,-(A7)
                MOVE.L  (A0)+,D0                        ; D0 = chunk length in bytes
                MOVE.L  D0,D1                           ; D1 = chunk length in bytes
                BTST.L  #$0000,D1                       ; test even/odd
                BEQ.B   .is_even                        ; is an even length, jmp $00001776
                ADD.L   #$00000001,D1                   ; is odd, add pad byte
.is_even
                ADD.L   #$00000004,D1                   ; add 4 bytes to data length (header id)
                ADD.L   D1,$0004(A7)                    ; increment address ptr on stack to end of data block.
                SUB.L   D1,(A7)                         ; subtract block length from, remaining byte length on stack.

                MOVE.L  (A0)+,D1                        ; D1 = get next long word
                SUB.L   #$00000004,D0                   ; D0 = subtract 4 bytes from remaining byte count
                CMP.L   #'    ',D1                      ; check Id '    ' (spaces) #$20202020,D1
                BEQ.W   iff_blank_chunk                 ; call $000017A6
                CMP.L   #'HUFF',D1                      ; check Id 'HUFF' #$48554646,D1
                BEQ.W   iff_huff_chunk                  ; jmp $00001816
                CMP.L   #'ILBM',D1                      ; check Id 'ILBM' #$494c424d,D1
                BEQ.W   iff_ilbm_chunk                  ; jmp $0000193E

.iff_form_exit
                MOVEM.L (A7)+,D0/A0
                RTS 




                ;------------------------- iff blank chunk -----------------------------
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_blank_chunk
                TST.L   D0                        ; test remaining bytes value
                BEQ.B   .exit_blank_chink       ; if Remaining bytes = 0, jmp $000017B4
                MOVE.L  (A0)+,D1                ; D1 = chunk length (bytes)
                SUB.L   #$00000004,D0           ; D0 = subtract 4 bytes (chunk len) from remaining bytes
                BSR.W   iff_inner_blank_chunk   ; calls $000017BA
                BRA.B   iff_blank_chunk         ; loop, process rest of chunk, jmp $000017A6

.exit_blank_chink
                MOVEM.L (A7)+,D0/A0
                RTS 



                ;------------------------- iff inner blank chunk -----------------------------
                ;-- process '   ' (blank chunk id), process any 'FORM','CAT ','BODY' chunks
                ;-- that may reside inside it, or skip the chunk is other type.
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_inner_blank_chunk                                       ; relocated address $000017BA
                CMP.L   #'FORM',D1                          ; #$464f524d,D1
                BEQ.B   iff_form                            ; jmp $00001766
                CMP.L   #'CAT ',D1                          ; #$43415420,D1
                BEQ.W   iff_cat                             ; jmp $00001748
                CMP.L   #'BODY',D1                          ; #$424f4459,D1
                BEQ.W   iff_body                            ; jmp $000017F4
.iff_inner_blank
                MOVEM.L D0/A0,-(A7)                         ; store current remaining bytes/buffer address on stack
                MOVE.L  (A0)+,D0                            ; D0 = chunk length
                MOVE.L  D0,D1                               ; D1 = chunk length
                BTST.L  #$0000,D1                           ; test length
                BEQ.B   .is_even                            ; if is even, jmp $000017E6
.is_odd                
                ADD.L   #$00000001,D1                       ; if is odd, add pad byte to length
.is_even
                ADD.L   #$00000004,D1                       ; add 4 bytes to chunk length
                ADD.L   D1,$0004(A7)                        ; add chunk length to data buffer pointer on stack
                SUB.L   D1,(A7)                             ; subtract chunk length from remaining bytes on stack

                MOVEM.L (A7)+,D0/A0                         ; restore buffer pointer and remaining bytes from stack
                RTS 




                ;------------------------- iff body -----------------------------
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_body                                                    ; relocated address $000017F4
                MOVEM.L D0/A0,-(A7)
L000017F8       MOVE.L  (A0)+,D0
L000017FA       MOVE.L  D0,D1
L000017FC       BTST.L  #$0000,D1
L00001800       BEQ.B   L00001804
L00001802       ADD.L   #$00000001,D1
L00001804       ADD.L   #$00000004,D1
L00001806       ADD.L   D1,$0004(A7)
L0000180A       SUB.L   D1,(A7)
L0000180C       BSR.W   relocate__bytes                     ; A0 = source addr, D0 = number of bytes, ld_relocate_addr = dest addr, calls $0000170A
L00001810       MOVEM.L (A7)+,D0/A0
L00001814       RTS 




                ;------------------------- iff huff chunk -----------------------------
                ;-- Can't fins any information regarding a 'HUFF' chunk id for IFF
                ;-- files, after having a think about it.
                ;--
                ;-- My best guess would be that it's a Huffman Encoded chunk that
                ;-- Consists of a SIZE, TREE, and CODE block.
                ;--
                ;-- May come back to this at some point in the future to decode
                ;-- but i'll probably just use the existing code to decode the 
                ;-- data and then forget about this.
                ;--
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_huff_chunk
                ; create 3 long words storage on the stack                             
                CLR.L   -(A7)                   ; SIZE Long Word 
                CLR.L   -(A7)                   ; CODE source address ptr
                CLR.L   -(A7)                   ; TREE source address ptr

                MOVE.L  A6,-(A7)                ; store A6 on stack
                MOVEA.L A7,A6                   ; A6 = stack base ptr

.huff_block_loop
                TST.L   D0                      ; test remaining bytes/len
                BEQ.B   .huff_block_end         ; if = 0 jmp $0000182E       
                MOVE.L  (A0)+,D1                ; D1 = inner block id
                SUB.L   #$00000004,D0           ; D0 = subtract 4 bytes from remaining length
                BSR.W   iff_inner_huff_chunk    ; calls $00001856
                BRA.B   .huff_block_loop        ; loop jmp $00001820

.huff_block_end
                TST.L   $0004(A6)
                BEQ.B   .huff_block_exit        ; jmp $0000184A
                TST.L   $0008(A6)
                BEQ.B   .huff_block_exit        ; jmp $0000184A
                TST.L   $000c(A6)
                BEQ.B   .huff_block_exit        ; jmp $0000184A
                MOVEM.L $0004(A6),D0/A0-A1      ; D0 = Code Size, A1 = Code Address, A2 = Tree Address
                BSR.W   iff_process_code        ; call $0000190C

.huff_block_exit
                MOVEA.L (A7)+,A6                ; restore a6 from stack
                LEA.L   $000c(A7),A7            ; deallocate stack 3 long words
                MOVEM.L (A7)+,D0/A0
                RTS 




                ;------------------------- iff inner huff chunk -----------------------------
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_inner_huff_chunk
                CMP.L   #'FORM',D1                      ; #$464f524d,D1
                BEQ.W   iff_form                        ; jmp $00001766
                CMP.L   #'CAT ',D1                      ; #$43415420,D1
                BEQ.W   iff_cat                         ; jmp $00001748
                CMP.L   #'SIZE',D1                      ; #$53495a45,D1
                BEQ.W   iff_size                        ; jmp $000018A6
                CMP.L   #'CODE',D1                      ; #$434f4445,D1
                BEQ.W   iff_code                        ; jmp $000018C8
                CMP.L   #'TREE',D1                      ; #$54524545,D1
                BEQ.W   iff_tree                        ; jmp $000018EA
.iff_skip_other_id
                MOVEM.L D0/A0,-(A7)                     ; store address ptr/remaining bytes on stack
                MOVE.L  (A0)+,D0                        ; D0 = chunk length
                MOVE.L  D0,D1                           ; D1 = chunk length
                BTST.L  #$0000,D1                       ; test odd/even
                BEQ.B   .is_even                        ; if even then $00001898
.is_odd
                ADD.L   #$00000001,D1                   ; if odd, add 1 pad bytes
.is_even
                ADD.L   #$00000004,D1                   ; add 4 to chunk length
                ADD.L   D1,$0004(A7)                    ; add chunk length to address ptr on stack
                SUB.L   D1,(A7)                         ; subtract chunk length from remaining bytes on stack
.iff_skip_exit
                MOVEM.L (A7)+,D0/A0
                RTS 




                ;------------------------- iff size -----------------------------
                ;-- store the SIZE of the code block in stack storage allocated
                ;-- in iff_huff_chunk() above.
                ;--
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: A6 = Stack Storage (3 long words)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_size                                                    ; relocated size $000018A6
                MOVEM.L D0/A0,-(A7)                         ; save remaining bytes/address ptr on stack
                MOVE.L  (A0)+,D0                            ; D0 = chunk len bytes
                MOVE.L  D0,D1                               ; D1 = chunk len bytes
                BTST.L  #$0000,D1                           ; test if len odd/even
                BEQ.B   .is_even                            ; if even jmp $000018B6
.is_odd
                ADD.L   #$00000001,D1                       ; if odd then add 1 pad bytes to len
.is_even
                ADD.L   #$00000004,D1                       ; add 4 bytes to chunk len 
                ADD.L   D1,$0004(A7)                        ; add chunk len to address ptr on stack
                SUB.L   D1,(A7)                             ; subtract chunk len from remaining bytes on stack

                MOVE.L  (A0)+,$0004(A6)                     ; **** store SIZE **** Long word in first Longword on stack

                MOVEM.L (A7)+,D0/A0                         ; restore updated remaining bytes/address ptr from stack
                RTS 



                ;------------------------- iff code -------------------------------
                ;-- store the address of the CODE block in stack storage allocated
                ;-- in iff_huff_chunk() above.
                ;--
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: A6 = Stack Storage (3 long words)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_code                                                    ; relocated address $000018C8
                MOVEM.L D0/A0,-(A7)                         ; save remaining bytes/address ptr on stack
                MOVE.L  (A0)+,D0                            ; D0 = chunk len
                MOVE.L  D0,D1                               ; D1 = chunk len
                BTST.L  #$0000,D1                           ; test odd/even
                BEQ.B   .is_even                            ; if is even, jmp $000018D8
.is_odd
                ADD.L   #$00000001,D1                       ; if is odd, add 1 pad byte to chunk len
.is_even
                ADD.L   #$00000004,D1                       ; add 4 bytes to chunk len
                ADD.L   D1,$0004(A7)                        ; add chunk len to address ptr on stack
                SUB.L   D1,(A7)                             ; subtract chunk len from remaining bytes on stack

                MOVE.L  A0,$0008(A6)                        ; **** store current buffer address - CODE - address in 2nd longword on stack **** 

                MOVEM.L (A7)+,D0/A0                         ; restore updated remaining bytes/address ptr from stack
                RTS 




                ;------------------------- iff tree -------------------------------
                ;-- store the address of the TREE block in stack storage allocated
                ;-- in iff_huff_chunk() above.
                ;--
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: A6 = Stack Storage (3 long words)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_tree                                                    ; relocated address $000018EA
                MOVEM.L D0/A0,-(A7)
                MOVE.L  (A0)+,D0                            ; D0 = chunk len
                MOVE.L  D0,D1                               ; D1 = chunk len
                BTST.L  #$0000,D1                           ; test odd/even chunk len
                BEQ.B   .is_even                            ; is even, jmp $000018FA
.is_odd
                ADD.L   #$00000001,D1                       ; is odd, add 1 pad byte to chunk len
.is_even
                ADD.L   #$00000004,D1                       ; add 4 bytes to chunk len
                ADD.L   D1,$0004(A7)                        ; update address ptr on stack
                SUB.L   D1,(A7)                             ; subtract chunk len from remaining bytes on stack

                MOVE.L  A0,$000c(A6)                        ; **** store current buffer address - TREE - address in 3rd longword on stack ****

                MOVEM.L (A7)+,D0/A0                         ; restore updated remaining bytes/address ptr from stack
                RTS 




                ;------------------------- iff process code -------------------------------
                ;-- process iff code block, this is unfamiliar to me, unsure what data
                ;-- structures and values are held in the CODE & TREE blocks.
                ;-- research required.
                ;--
                ;-- what data exists in the CODE & TREE sections
                ;-- IN: D0 = SIZE
                ;-- IN: A0 = CODE address ptr
                ;-- IN: A1 = TREE address ptr
iff_process_code
                MOVEA.L ld_relocate_addr,A2                 ; A2 = code relocation address, from file entry $00000CF0
                MOVEM.L D0/A2,-(A7)                         ; store remaining bytes/address ptr on stack
.init
                MOVE.L  #$0000000f,D1                       ; D1 = 15 + 1 counter
                MOVE.W  (A0)+,D2                            ; D2 = next value from CODE block
.decode_loop
                MOVEA.L A1,A3                               ; A3 = copy of tree ptr
.inner_loop
                ADD.W   D2,D2                               ; D2 = D2 x 2
                BCC.B   .not_overflow                       ; no overflow, jmp $00001920
.is_overflow
                ADDA.W  #$00000002,A3                       ; is overflow, increment TREE ptr by 1 word
.not_overflow
                DBF.W   D1,.process_byte                    ; decrement D1 (15 + 1), branch $00001928
.code_loop_reset
                MOVE.L  #$0000000f,D1                       ; D1 = reset counter 15 + 1
                MOVE.W  (A0)+,D2                            ; D2 = next value from CODE block
.process_byte
                MOVE.W  (A3),D3                             ; D3 = current word from TREE block ptr
                BMI.B   .store_reloc_byte                   ; if low byte of TREE value < 0 (bit 8 = 1), jmp $00001930                             
                ADDA.W  D3,A3                               ; else D3 is an offset, add to TREE block ptr
                BRA.B   .inner_loop                         ; loop, jmp $0000191A
.store_reloc_byte
                MOVE.B  D3,(A2)+                            ; **** store TREE byte value in relocated address buffer
                SUB.L   #$00000001,D0                       ; decrement SIZE by 1
                BNE.B   .decode_loop                        ; loop while SIZE > 0, jmp $00001918
.end_iff_process_code
                MOVEM.L (A7)+,D0/A0                         ; restore remaining bytes/address ptr on stack
                BRA.W   process_file                        ; jump back to start process file. (not recursively) $000016E0
                                                            ; process remaining chunks in the file?







                ;------------------------- iff ilbm chunk -------------------------------
                ;-- Process interleaved Bitmap chunk
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_ilbm_chunk                                          ; relocated address $0000193E
                TST.L   D0                              ; test any bytes remaining
                BEQ.B   .end_ilbm_chunk                 ; if no, then exit, jmp $0000194C
                MOVE.L  (A0)+,D1
                SUB.L   #$00000004,D0
                BSR.W   iff_inner_ilbm_chunks           ; calls $00001952
                BRA.B   iff_ilbm_chunk                  ; $0000193E
.end_ilbm_chunk
                MOVEM.L (A7)+,D0/A0
                RTS




                ;------------------------- iff inner ilbm chunk -------------------------------
                ;-- Process interleaved Bitmap chunk
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_inner_ilbm_chunks
                CMP.L   #'FORM',D1                      ; #$464f524d,D1
                BEQ.W   iff_form                        ; jmp $00001766
                CMP.L   #'CAT ',D1                      ; #$43415420,D1
                BEQ.W   iff_cat                         ; jmp $00001748
                CMP.L   #'CMAP',D1                      ; #$434d4150,D1
                BEQ.W   iff_cmap_chunk                  ; jmp $000019B8
                CMP.L   #'BMHD',D1                      ; #$424d4844,D1
                BEQ.W   iff_bmhd_chunk                  ; jmp $00001A0C
                CMP.L   #'BODY',D1                      ; #$424f4459,D1
                BEQ.W   iff_body_chunk                  ; jmp $00001A32
                CMP.L   #'GRAB',D1                      ; #$47524142,D1
                BEQ.B   .skip_other_inner_chunk         ; jmp $0000199A
                CMP.L   #'DEST',D1                      ; #$44455354,D1
                BEQ.B   .skip_other_inner_chunk         ; jmp $0000199A
                CMP.L   #'CAMG',D1                      ; #$43414d47,D1
.skip_other_inner_chunk
                MOVEM.L D0/A0,-(A7)
                MOVE.L  (A0)+,D0                        ; D0 = chunk len
                MOVE.L  D0,D1                           ; D1 = chunk len
                BTST.L  #$0000,D1                       ; test odd/even len
                BEQ.B   .is_even                        ; if is even, jmp000019AA
.is_odd
                ADD.L   #$00000001,D1                   ; if is odd, add 1 pad byte
.is_even
                ADD.L   #$00000004,D1                   ; add 1 to chunk len
                ADD.L   D1,$0004(A7)                    ; update address ptr on stack
                SUB.L   D1,(A7)                         ; update remaining bytes on stack
                MOVEM.L (A7)+,D0/A0                     ; restore remaining len/address ptr from stack
                RTS 




                ;----------------------------- iff cmap chunk ----------------------------------
                ;-- Process 'CMAP' colour map chunk, stores the colour values in the
                ;-- loader copper list colours starting at address: copper_colours - $000014B8 
                ;-- 
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
iff_cmap_chunk                                                  ; relocation address $000019B8
                MOVEM.L D0/A0,-(A7)
                MOVE.L  (A0)+,D0                                ; d0 = chunk len
                MOVE.L  D0,D1                                   ; D1 = chunk len
                BTST.L  #$0000,D1                               ; test odd/even len
                BEQ.B   .is_even                                ; if is even, jmp $000019C8
.is_odd
                ADD.L   #$00000001,D1                           ; if is odd, add 1 pad byte
.is_even
                ADD.L   #$00000004,D1                           ; add 4 bytes to chunk len
                ADD.L   D1,$0004(A7)                            ; address ptr of the stack
                SUB.L   D1,(A7)                                 ; update remaining bytes on the stack

                DIVU.W  #$0003,D0                               ; divide chunk len by 3 (r/g/b)?
                BEQ.B   end_cmap_chunk                          ; if len == 0 then exit, jmp $00001A02

                SUB.W   #$00000001,D0
                LEA.L   copper_colours(PC),A1                   ; get bit-plane display colours. addr $000014B8
.colour_loop
                MOVE.L  #$00000000,D1
                MOVE.L  #$00000000,D2
                MOVE.B  (A0)+,D2                                ; D2 = first colour value (byte)
                LSR.W   #$00000004,D2                           ; S2 = Divide colour value by 16 (trim lower 4 bits 8 bit Red value?)
                OR.W    D2,D1                                   ; D1 = combine with D2
                ROL.W   #$00000004,D1                           ; D1 = Shift Value by 4 bits (space for next colour component )

                MOVE.L  #$00000000,D2                           ; D2 = clear down
                MOVE.B  (A0)+,D2                                ; D2 = second colour value (byte)
                LSR.W   #$00000004,D2                           ; D2 = Divide colour value by 16 (trim lower 4 bits of 8 bit green value>)
                OR.W    D2,D1                                   ; D1 = Combine with D2
                ROL.W   #$00000004,D1                           ; D1 = Shift value by 4 bits (space for next colour component)

                MOVE.L  #$00000000,D2                           ; D2 = Clear down
                MOVE.B  (A0)+,D2                                ; D2 = third colout value (byte)
                LSR.W   #$00000004,D2                           ; D2 = Divide colour value by 16 (trim lower 4 bits of 8 bit blue value?)
                OR.W    D2,D1                                   ; D1 = Combine with D2
                ADDA.L  #$00000002,A1                           ; increase copper list index to colour value address
                MOVE.W  D1,(A1)+                                ; Store colour RGB in copper colour value

                DBF.W   D0,.colour_loop                         ; convert remaining colours, jmp $000019DC

end_cmap_chunk
                MOVEM.L (A7)+,D0/A0
                RTS 





                ;----------------------------- iff bmhd chunk ----------------------------------
                ;-- Process 'BMHD' bitmap header chunk of iff file
                ;-- 
                ;-- IN: A0 = start of data chunk (chunk len)
                ;-- IN: D0 = file length/bytes remaining
                ;-- IN: D1 = chunk id
                ;-- IN: ld_relocate_addr = dest addr
                ;--
bitmap_header_address
                dc.l    $00000000                                   ; iff bitmap header address $00001A08

iff_bmhd_chunk
                MOVEM.L D0/A0,-(A7)                                 ; store remaiing bytes/address ptr on stack
                MOVE.L  (A0)+,D0                                    ; D0 = chunk len
                MOVE.L  D0,D1                                       ; D1 = chunk len
                BTST.L  #$0000,D1                                   ; test odd/even len
                BEQ.B   .is_even                                    ; if is even, jmp $00001A1C
.is_odd
                ADD.L   #$00000001,D1                               ; if is odd, add 1 pad byte
.is_even
                ADD.L   #$00000004,D1                               ; add 4 byte to chunk len
                ADD.L   D1,$0004(A7)                                ; update address ptr on stack
                SUB.L   D1,(A7)                                     ; update remaining bytes on stack

                MOVE.L  A0,bitmap_header_address                    ; store bitmap header address at $00001A08

                MOVEM.L (A7)+,D0/A0                                 ; restore remaining bytes/address ptr
                RTS 




unused_address
                dc.w    $0000, $0000                                ; $00001A2E nothing appears to reference this address

iff_body_chunk
                MOVEM.L D0/A0,-(A7)
                MOVE.L  (A0)+,D0                                    ; D0 = chunk len
                MOVE.L  D0,D1                                       ; D1 = chunk len
                BTST.L  #$0000,D1                                   ; test odd/even len
                BEQ.B   .is_even                                    ; if len is even, jmp $00001A42
.is_odd
                ADD.L   #$00000001,D1                               ; if odd then add 1 pad byte
.is_even
                ADD.L   #$00000004,D1
                ADD.L   D1,$0004(A7)
                SUB.L   D1,(A7)

.process_body
                LEA.L   $00007700,A1                                ; bitplane 1 address
                MOVEA.L bitmap_header_address,A2                    ; iff bit map header address ptr stored at $00001A08

                TST.B   $0009(A2)
                BNE.B   end_iff_body_chunk                          ; if not == 9, jmp $00001A82

                CMP.B   #$02,$000a(A2)
                BCC.B   end_iff_body_chunk                          ; if not == 9, jmp $00001A82
.header_info
                MOVE.L  #$00000000,D0                               ; D0 = clear
                MOVE.B  $0008(A2),D0                                ; D0 - number of bitplanes
                SUB.W   #$00000001,D0                               ; D0 - decremented by 1
                MOVE.W  D0,number_of_bitplanes                      ; D0 stored as word value in $00001A88

                MOVEM.W (A2),D6-D7                                  ; D6 = width pixels, D7 = height pixels
                MOVE.B  $000a(A2),D5                                ; D5 = compression byte

                ASR.W   #$00000004,D6                               ; D6 = D6 divided by 16     
                ADD.W   D6,D6                                       ; D6 = D6 * 2 = byte width value
                SUB.W   #$00000001,D7                               ; D7 = height Decremented by 1
                BSR.W   process_iff_body                            ; calls $00001A8A

end_iff_body_chunk
                MOVEM.L (A7)+,D0/A0
                RTS 


number_of_bitplanes
                dc.w    $0000                                       ; number of bitplanes in image, address $00001A88



                ;------------------------- process iff body ------------------------------
                ; Converts an interleaved source GFX Image to a collection of
                ; 'uninterleaved' bitplanes. 
                ; Bitplanes start at $7700 and each is #$2800 bytes (10K) in size.
                ; Bitplane1 = $7700
                ; Bitplane2 = $9F00
                ; Bitplane3 = $C700
                ; Bitplane4 = $EF00
                ; Bitplane5 = $11700
                ; End of Bitplanes = $13F00
                ;
                ; A0 = Source Body Data
                ; A1 = Destination Bitplane Ptr
                ; A2 = Bitmap Header Address Ptr
                ; D0 = Number of bitplanes -1
                ; D5 = Compression byte
                ; D6 = Number of Bytes Wide 
                ; D7 = Number of Rows High -1
process_iff_body                                                ; relocated address: $00001A8A
                SUBA.W  D6,A7                                   ; allocate one scanline of storage on the stack
                MOVE.W  D6,D4                                   ; D4 = copy of byte width of gfx image
                CMP.W   #$0028,D4                               ; Test if 40 bytes (320 pixels wide)
                BLE.B   .skip_clamp_40                          ; if less than or equal to 40 bytes, jmp $00001A96                           
.is_40_or_more
                MOVE.L  #$00000028,D4                           ; D4 = 40 (bytes) clamped
.skip_clamp_40
                ASR.W   #$00000001,D4                           ; D4 = D4/2 (word count)
                SUB.W   #$00000001,D4                           ; D4 = decremented by 1

.start_scanline_processing                                       ; start unpacking of 1 interleaved scanline of image data
                MOVEA.L A1,A2                                   ; A2 = copy of destination bitmap ptr
                MOVE.W  number_of_bitplanes,D3                  ; D3 = number of bitplanes - $00001A88,D3

.start_bitplane_loop                                             ; start unpacking the current bitplane's scanline of image data. relocated addr $00001AA0
                MOVEA.L A7,A3                                   ; A7,A3 = scan line buffer on the stack
                MOVE.W  D6,D2                                   ; D6,D2 = copy of image width in bytes

.check_compressed
                TST.B   D5                                      ; test compression byte
                BNE.B   .unpack_scanline                         ; if is compressed, jmp $00001AAE

.not_compressed
                MOVE.W  D2,D0                                   ; D0 = gfx bytes wide
                SUB.W   #$00000001,D0                           ; D0 = decrement by 1
                BRA.B   .copy_src_dest                           ; jmp $00001AC6, D0 = number of bytes to copy

.unpack_scanline
                CLR.W   D0                                      ; clear D0
                MOVE.B  (A0)+,D0                                ; get source BODY data byte (number of bytes to copy)
                BPL.B   .copy_src_dest                           ; if D0 +ve, then jmp $00001AC6, D0 = number of bytes to copy
                NEG.B   D0
                BVS.B   .unpack_scanline                         ; if D0 caused overflow then loop back to, $00001AAE

.repeat_byte                                                    ; repeat the last byte (D0 + 1) times
                MOVE.B  (A0)+,D1                                ; get next source BODY data byte
.repeat_byte_loop
                MOVE.B  D1,(A3)+
                SUB.W   #$00000001,D2
                DBF.W   D0,.repeat_byte_loop                     ; D0 = repeat count, loop to $00001ABA

                BNE.B   .unpack_scanline                         ; is D2 != 0, loop again. (not finished scan line) ;$00001AAE
                BRA.B   .scanline_to_destbuffer                  ; jmp $00001AD0 ; scan line unpacked, copy to dest buffer

.copy_src_dest                                                   ; D0 = number of bytes to copy + 1
                MOVE.B  (A0)+,(A3)+                             ; copy BODY byte to scanline buffer
                SUB.W   #$00000001,D2                           ; D2 = subtract 1 from remaining bytes for scan line
                DBF.W   D0,.copy_src_dest                        ; D0 = number of bytes to copy, jmp $00001AC6

                BNE.B   .unpack_scanline                         ; D2 - if bytes remaining on scanline, then loop to $00001AAE


.scanline_to_destbuffer
                MOVEA.L A7,A3                                   ; A7,A3 = scanline buffer
                MOVEA.L A2,A4                                   ; A2,A4 = destination bitplane address
                MOVE.W  D4,D2                                   ; D4,D2 = words per scan line -1

.copy_scanline_loop                                              ; copy current bitplanes' unpacked scanline to the destination bitplane
                MOVE.W  (A3)+,(A4)+                             ; copy word from scanline buffer to destination.
                DBF.W   D2,.copy_scanline_loop                   ; copy D2 words to destination bitplane, loop $00001AD6

.prep_next_interleaved_scanline
                ADDA.W  #$2800,A2                               ; increase destination ptr by 10K = 10,240 bytes
                DBF.W   D3,.start_bitplane_loop                        ; loop do next scanline on bitplane bitplane, loop to $00001AA0

.prep_next_scanline
                ADDA.W  #$0028,A1                               ; increment bitplane1 ptr by one scanline (40 bytes)
                DBF.W   D7,.start_scanline_processing            ; loop for image height (D7) + 1, jmp $00001A9A

.end_iff_body_process                
                ADDA.W  D6,A7                                   ; remove scanline buffer from the stack
                RTS 

















                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------
                ; LOW LEVEL DISK ROUTINES
                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------





                ;----------------------- loader variables/state ----------------------
                ;-- relocated address: $00001AF0
                even
ld_track_status                                             
                dc.b    $00                                 ; set to true when track loaded into buffer. $00001AF0

ld_unused_byte
                dc.b    $00

ld_decoded_track_ptr
                dc.l    $00000000                           ; relocated address: $00001AF2
   
ld_mfmencoded_track_ptr                             
                dc.l    $00000000                           ; relocated address: $00001AF6

ld_drive_bits_word                                          
                dc.b    $00                                 ; Available drives bit field as a word: $00001AFA
ld_drive_bits_byte                                          
                dc.b    $00                                 ; Available drives bit field as a byte: $00001AFB

ld_drive_number                         
                dc.w    $0000                               ; relocated address: $00001AFC 

ld_unused_word1 
                dc.w    $0000                               ; relocated address: $00001AFE 

ld_track_number_word                                        ; The current track number as a word. $00001B00                       
                dc.b    $00                             
ld_track_number_byte                                        ; The current track number as a byte. $00001B01
                dc.b    $00 

ld_unused_word2         
                dc.w    $0001                               ; relocated address: $00001B02 

ld_ciab_20ms_countdown                         
                dc.w    $0000                               ; relocated address: $00001B04 - CIAB Timer B - 20 millisecond count down timer tick

L00001B06       dc.w    $0000

ld_load_status
                dc.w    $0000                               ; relocated address: $00001B08




                ; ----------------------------- load track/file from disk --------------------------------
                ; load file from disk (a6,a1 = load address, d1,d0 = start sector, a0 = file entry)
                ; -- IN: D0.w - Start Sector of File
                ; -- 
                ; -- OUT: A0.L = Start of data in track buffer
                ; - used state:
                ; -- $1B00.W        - Current Selected Drive's track number
                ; -- $1AF2.L        -
load_decode_track                                   ; relocated routine address $00001B0A
                MOVEM.L D0-D1,-(A7)
L00001B0E       EXT.L   D0                          ; sign extend sector number to 32 bits (clear high word crap) 
L00001B10       DIVU.W  #$000b,D0                   ; d0 = start track number, divide start sector by 11 sectors per track.
L00001B14       MOVE.L  D0,D1                       ; copy result 
L00001B16       SWAP.W  D1                          ; D1.w = remining sectors (if first track is not all sectors)
L00001B18       TST.B   ld_track_status             ; $00001AF0 ; test file/track loaded status flag (set to true when track is loaded into memory)
L00001B1C       BEQ.B   L00001B24

L00001B1E       CMP.W   ld_track_number_word,D0     ; $00001B00 - D0 = start track, test current drive track number with required start track
L00001B22       BEQ.B   L00001B32                   ; if equal, track already loaded and decocded?

L00001B24       MOVEA.L ld_decoded_track_ptr,A0     ; Track Decoded Buffer Address. addr: $00001AF2
L00001B28       BSR.W   load_mfm_track              ; calls $00001CBC ; Load Track into Buffer (d0 = track number, d1 = remaining sectors if not whole track)
L00001B2C       BNE.B   L00001B40                   ; Z = 0 - error occurred
L00001B2E       ST.B    ld_track_status             ; $00001AF0 ; set file/track loaded status byte to $FF (true)

L00001B32       MOVEA.L ld_decoded_track_ptr,A0     ; decoded track buffer address.
L00001B36       MULU.W  #$0200,D1                   ; D1 = 512 x remaining sectors (bytes per sector)
L00001B3A       ADDA.L  D1,A0                       ; Increment A0 by remaining sectors from whole tracks
L00001B3C       CLR.W   ld_load_status              ; $00001B08 ; Clear Load Status = succcess

L00001B40       TST.W   ld_load_status              ; $00001B08 ; Test Load Status Z = 1 - success
L00001B44       MOVEM.L (A7)+,D0-D1
L00001B48       RTS 




                ;--------------------------- detect available drives -----------------------------
                ; creates a bit field of available drives at relocated address $00001afa.W
                ; each bit in the field 0-3 represent whether a drive exists (1 = drive detected)
                ;
detect_available_drives                                     ; relocated address: $00001B4A 
                MOVE.L  #$00000003,D0
                MOVE.L  #$00000000,D1
.detect_loop                                                ; relocated address: $00001B4E
                MOVEM.L D0-D1,-(A7)
                BSR.B   select_drive                        ; $00001B96
                BSR.B   seek_track0                         ; $00001BAE
                MOVEM.L (A7)+,D0-D1
                BNE.B   .check_next_drive                   ; if drive not available then skip to check next drive: bne $00001B5E

                BSET.L  D0,D1                               ; Set Available Drive Flag (bits 0-3)
.check_next_drive
                SUB.W   #$0001,D0                           ; decrement drive number:  relocated addr: $00001B5E
                BPL.B   .detect_loop 

                MOVE.W  D1,ld_drive_bits_word               ; store detected drives bit field: $00001afa
                BRA.B   deselect_all_drives                 ; end and clean up: jmp to $00001B8C




                ;---------------- drive motor on -------------------------
                ; -- selects and latches on the current drive
                ; -- IN: D0 = current drive number (0-3)
drive_motor_on                                              ; relocated address: $00001B68
                BCLR.B  #$0007,$00bfd100                    ; CIAB PRB  - clear /MTR bit (active low)
                BCLR.B  #$0007,$00bfd100                    ; CIAB PRB  - clear /MTR bit (active low)
                BRA.B   select_drive                        ; routine addr: $00001B96




                ;---------------- drive motor off -------------------------
                ; -- selects and latches off the current drive
                ; -- ends by deselecting all drives.
                ; -- IN: D0 = current drive number (0-3)
drive_motor_off                                             ; relocated address: $00001B7A
                BSET.B  #$0007,$00bfd100
                BSET.B  #$0007,$00bfd100
                BSR.B   select_drive                        ; routine addr: $00001B96




                ;---------------- deselect all drives ---------------------
deselect_all_drives                                         ; routine addr: $00001B8C
                OR.B    #$78,$00bfd100                      ; Deselect all drives (active low)
                RTS 




                ;------------------ select drive ----------------------------
                ; -- selects the current drive, used to latch motor on/off
                ; -- called from: drive_motor_on
                ; -- IN: D0 = current drive number (0-3)
select_drive                                                ; relocated address: $00001B96
                MOVE.L  D1,-(A7)                            ; store D1.L
                OR.B    #$78,$00bfd100                      ; Deselect all drives (active low)
                MOVE.B  D0,D1                               ; D0,D1 = current drive number
                ADD.B   #$03,D1                             ; Shift drive number bits
                BCLR.B  D1,$00bfd100                        ; Clear current drive select bit - active low (latch motor on/off state)
                MOVE.L  (A7)+,D1                            ; restore D1.L
                RTS 




                ;-------------------- seek track 0 ---------------------------
                ;-- reset drive heads to track 0 of currently selected drive
                ;
seek_track0                                                 ; relocated address: $00001BAE
                MOVE.W  #$0004,ld_load_status               ; $00001B08 ; set loader status (4 = step heads)
                MOVEM.L D0,-(A7)                            ; save D0.L
                MOVE.W  #$00a6,ld_track_number_word         ; $00001B00 ; Current Track = 168 (cylinder 84)
                CLR.W   D0                                  ; clear target track D0.W
                BSR.B   seek_to_track                       ; calls $00001BC8
                MOVEM.L (A7)+,D0                            ; restore D0.l
                RTS 




                ;------------------- seek to track----------------------------
                ;-- seek heads of the current drive to the required track
                ;-- sets heads to the correct cylinder and selects top/bottom
                ;-- head as required for odd/even track number
                ;-- even number (0,2,4,6...) uses bottom of the disk
                ;--
                ;-- IN: D0.W - required track number
                ;--
                ;-- OUT: CCR Z = 0 - track 0
                ;
seek_to_track                                                   ; relocated address: $00001BC8
.even_track_no  BSET.B  #$02,$00bfd100                          ; CIA PRB - SIDE = 1 (select bottom side)
                BCLR.B  #$00,ld_track_number_byte               ; make current track counter even (bottom head)                
                BTST.L  #$0000,D0                               ; is desired track even or odd?
                BEQ.B   .step_heads                              ; if desired track is even then continue, jmp $00001BEA
.odd_track_no
                BCLR.B  #$02,$00bfd100                          ; else, track is odd, so set CIAB PRA - SIDE = 0 (top head) and...
                BSET.B  #$00,ld_track_number_byte               ; make current track counter odd
.step_heads
                CMP.W   ld_track_number_word,D0                 ; is current track equal to the desired track?
                BEQ.B   .end_step                               ; calls $00001C5E
                BPL.B   .step_inwards                           ; calls $00001C18 ; current track less than than desired
.step_ouwards
                BSET.B  #$01,$00bfd100                          ; CIAB PRB - DIR = 1 (step outwards)
.step_out_loop
                BTST.B  #$04,$00bfe001                          ; are heads at track 0
                BEQ.B   .at_track0                              ;   yes.. $00001C12
                BSR.B   step_heads                              ; call $00001C68
                SUB.W   #$0002,ld_track_number_word             ; decrement track number by 2 (top & bottom)
                CMP.W   ld_track_number_word,D0                 ; test if at desired track number 
                BNE.B   .step_out_loop                          ; if not at desired track then step again, jmp $00001BFA
                BRA.B   .step_completed                         ; jmp $00001C2C
.at_track0
                CLR.W   ld_track_number_word                    ; clear current track number $00001b00
                BRA.B   .step_completed
.step_inwards
                BCLR.B  #$01,$00bfd100                          ; CIAB PRB - DIR = 0 (step inwards)
.step_in_loop
                BSR.B   step_heads                              ; calls $00001C68
                ADD.W   #$0002,ld_track_number_word             ; increment track number by 2 (top & bottom)
                CMP.W   ld_track_number_word,D0                 ; test if at desired track number
                BNE.B   .step_in_loop                           ; if not at desired track then step again, jmp $00001C20
.step_completed
                MOVE.B  #$00,$00bfde00                          ; CIAB CRA (stop timers)
                MOVE.B  #$f4,$00bfd400                          ; timer A low  = #$f4 
                MOVE.B  #$29,$00bfd500                          ; timer A high = #$29 (10740) - 15ms? not sure of timer freq (pal = 0.709379mhz)
                BCLR.B  #TIMERA_FINISHED,interrupt_flags_byte   ; clear timerA interrupt flag: $0000209A
                MOVE.B  #$19,$00bfde00                          ; CIAB CRA (start timer), LOAD = 1, RUNMODE = 1 (oneshot), START = 1
.timer_wait     BTST.B  #TIMERA_FINISHED,interrupt_flags_byte   ; test timerA interrupt flag: $0000209A
                BEQ.B   .timer_wait                             ; wait for timer $00001C54
.end_step
                BTST.B  #$0004,$00bfe001                        ; Test if Track 0, Z = 0
                RTS 




                ;----------------------- step heads ----------------------------
                ;-- step the disk heads of the currently selected drive, using
                ;-- the currently selected heads direction.
                ;-- heads are stepped by setting the STEP bit low then high (pulse)
                ;
step_heads                                                      ; relocated address: $00001C68
                MOVE.B  #$00,$00bfde00                          ; CIAB CRA (control reg A)
                MOVE.B  #$c8,$00bfd400                          ; TimerA low =  #$C8
                MOVE.B  #$10,$00bfd500                          ; TimerA High = #$10
                BCLR.B  #$00,$00bfd100                          ; clear STEP bit CIAB PRB   
                BCLR.B  #$00,$00bfd100                          ; clear STEP bit CIAB PRB 
                BCLR.B  #$00,$00bfd100                          ; clear STEP bit CIAB PRB 
                BSET.B  #$00,$00bfd100                          ; set STEP bit CIAB PRB 
                BCLR.B  #TIMERA_FINISHED,interrupt_flags_byte   ; clear timer A flag: $0000209A
                MOVE.B  #$19,$00bfde00                          ; CIAB CRA (start timer), LOAD = 1, RUNMODE = 1 (oneshot), START = 1
.timer_wait
                BTST.B  #TIMERA_FINISHED,interrupt_flags_byte   ; test timerA interrupt flag: $0000209A
                BEQ.B   .timer_wait                             ; wait for timer $00001CB0
                RTS 




                ; -------------------------- load mfm track -------------------------
                ; -- IN: D0.W - start track
                ; -- IN: D1.w - number of sectors (if not full track,  i.e. first read might start half way though track)
                ; -- IN: A0.L - decoded data buffer
                ; -- used state:
                ; --  $1AF6.L - Raw mfm buffer address
                ; --  $1B04.W - CIAB TimeB 20ms Timer Tick Counter
                ; --  $1B06.W - retry count
                ; --  $1B08.W - Load Status 
load_mfm_track
                MOVEM.L D1/A0-A1,-(A7)
                MOVE.W  #$0020,L00001B06                            ; #$20 = 32
                MOVE.W  #$0001,ld_load_status                       ; $00001B08 ; set load status

                MOVE.W  #$0032,ld_ciab_20ms_countdown               ; $00001B04 ; init timer ticks for wait = 50 x 20 = 1000 milliseconds (Disk RDY timeout)
.drv_rdy_loop   TST.W   ld_ciab_20ms_countdown                      ; $00001B04 ; addr: $00001CD2
                BEQ.B   .exit                                       ; if the counter is somehow hit 0 then exit. $00001D0E
                BTST.B  #$0005,$00bfe001                            ; test RDY bit (active low) of CIAA PRA (disk status byte)
                BNE.B   .drv_rdy_loop                               ; drive not ready yet. $00001CD2

.retrystep      BSR.W   seek_to_track                               ; calls $00001BC8 ; step heads to track addr: $00001CE2
.retryread      MOVE.W  #$0001,ld_load_status                       ; $00001B08 ; set load status value   addr: $00001CE6

                MOVEA.L ld_mfmencoded_track_ptr,A0                  ; mfm encoded track buffer
                BSR.W   dma_read_track                              ; $00001D36 ; read track using harware DMA 
                BEQ.B   .load_error                                 ; Z = 1 then error (timeout) jump addr: $00001D1C

                MOVE.W  #$0002,ld_load_status                       ; $00001B08 ; update load status
                MOVEA.L ld_mfmencoded_track_ptr,A0                  ; $00001AF6 ; A0 = raw mfm buffer address
                MOVEA.L $0004(A7),A1                                ; A1 = decoded buffer address
                BSR.W   decode_mfm_buffer                           ; calls $00001DD0 ; decode track to address
                BNE.B   .load_error                                 ; Z = 0 then error? jump addr: $00001D1C
                CLR.W   ld_load_status                              ; $00001B08 ; clear load status
.exit
                MOVEM.L (A7)+,D1/A0-A1
                LEA.L   $1600(A0),A0                                ; increment decoded data buffer pointer
                TST.W   ld_load_status                              ; $00001B08 ; test load status z = 1 = success
                RTS 

.load_error
                SUB.W   #$0001,D1                                   ; decrement retry count                               
                MOVE.W  D1,L00001B06                                ; update retry count
                BEQ.B   .exit                                       ; retry count = 0, then exit $00001D0E
                MOVE.W  L00001B06,D1                                ; D1 = retry count
                AND.W   #$0007,D1                                   ; clamp retry to 7
                BNE.B   .retryread                                  ; if retry  +ve then retry, addr: $00001CE6
                BSR.W   seek_track0                                 ; calls $00001BAE ; step heads to track 0, every 8 retries
                BEQ.B   .retrystep                                  ; retry with step to track L00001CE2
                BRA.B   .exit                                       ; jump to exit $00001D0E




                ;-------------------------- dma read track --------------------------
                ;-- IN: A0.L - MFM Track Buffer
                ;-- OUT: Z=0 - success, Z=1 - timeout
dma_read_track                                                          ; relocated address: $00001D36
                MOVEM.L D0/A0,-(A7)
                MOVE.W  #$0005,ld_ciab_20ms_countdown               ; $00001B04 ; CIAB Timer B 20ms timer ticks = 5 * 20 = 100ms (drive ready timeout value)
.drive_ready_loop
                TST.W   ld_ciab_20ms_countdown                      ; $00001B04
                BEQ.W   .exit_read_track                            ; if timeout jmp $00001DCA
                BTST.B  #$0005,$00bfe001                            ; Test Drive RDY bit
                BNE.B   .drive_ready_loop                           ; $00001D40 ; drive not ready then wait

                MOVE.W  #$4000,$00dff024                            ; DSKLEN - Disk DMA OFF
                MOVE.W  #$8010,$00dff096                            ; DMACON - Disk DMA ON
                MOVE.W  #$7f00,$00dff09e                            ; ADKCON - Clear MFM Disk Settings
                MOVE.W  #$9500,$00dff09e                            ; ADKCON - Set MFM Disk Settings (MFMPREC, FAST, WORDSYNC)
                MOVE.W  #$4489,$00dff07e                            ; DSKSYNC - Set Track Sync Mark (standard DOS Sync)
                MOVEA.L $0004(A7),A0                                ; MFM Track Buffer
                MOVE.W  #$4489,(A0)+                                ; Seed MFM Buffer with initial sync mark (decode bug fix bodge)
                MOVE.L  A0,$00dff020                                ; Set MFM Buffer for track read
                MOVE.W  #$0002,$00dff09c                            ; Clear DSKBLK interrupt flag
                MOVE.W  #$99ff,D0                                   ;
                MOVE.W  D0,$00dff024                                ; DSKLEN - Write value twice to start disk DMA
                MOVE.W  D0,$00dff024                                ; DSKLEN - Write value twice to start disk DMA

                MOVE.W  #$0032,ld_ciab_20ms_countdown               ; #$32 = 50, 50 x 20 = 1000 milliseconds: $00001B04
.wait_dskblk
                TST.W   ld_ciab_20ms_countdown                      ; test timeout
                BEQ.B   .end_dskblk_wait                            ; $00001DB6 ; if timeout then exit, jmp $00001D86

                MOVE.L  #$00000002,D0                               ; DSKBLK interrupt flag mask
                AND.W   $00dff01e,D0                                ; test for DSKBLK completed
                BEQ.B   .wait_dskblk                                ; $00001DA6 ; wait for DSKBLK completed
.end_dskblk_wait
                MOVE.W  #$0010,$00dff096                            ; Disable Disk DMA
                MOVE.W  #$4000,$00dff024                            ; Disable Disk DMA
         
                TST.W   ld_ciab_20ms_countdown                      ; Test Timeout Value
.exit_read_track
                MOVEM.L (A7)+,D0/A0
                RTS



                ;--------------------- decode mfm track buffer ----------------------
                ; IN: A0.L - mfm track buffer
                ; IN: A1.L - decoded track buffer address
decode_mfm_buffer
L00001DD0       MOVEM.L D0-D1/D5-D7/A0,-(A7)
L00001DD4       MOVE.B  D0,D7
L00001DD6       CLR.W   D6
L00001DD8       MOVE.W  #$33ff,D5
L00001DDC       SUBA.W  #$001c,A7
L00001DE0       CMP.W   #$4489,(A0)+
L00001DE4       DBEQ.W  D5,L00001DE0
L00001DE8       BNE.W   L00001E6C
L00001DEC       CMP.W   #$4489,(A0)+
L00001DF0       DBNE.W  D5,L00001DEC
L00001DF4       BEQ.W   L00001E6C
L00001DF8       SUBA.L  #$00000002,A0
L00001DFA       SUB.W   #$00000001,D5
L00001DFC       MOVEM.L A0-A1,-(A7)
L00001E00       LEA.L   $0008(A7),A1
L00001E04       MOVE.L  #$0000001c,D0
L00001E06       BSR.W   L00001E72
L00001E0A       MOVEM.L (A7)+,A0-A1
L00001E0E       MOVE.L  #$00000028,D0
L00001E10       BSR.W   L00001F06
L00001E14       CMP.L   $0014(A7),D0
L00001E18       BNE.B   L00001DE0
L00001E1A       CMP.B   $0001(A7),D7
L00001E1E       BNE.B   L00001E6C
L00001E20       LEA.L   $0038(A0),A0
L00001E24       MOVE.W  #$0400,D0
L00001E28       BSR.W   L00001F06
L00001E2C       CMP.L   $0018(A7),D0
L00001E30       BNE.B   L00001DE0
L00001E32       MOVE.B  $0002(A7),D0
L00001E36       BSET.L  D0,D6
L00001E38       MOVE.L  A1,-(A7)
L00001E3A       EXT.W   D0
L00001E3C       MULU.W  #$0200,D0
L00001E40       ADDA.W  D0,A1
L00001E42       MOVE.W  #$0200,D0
L00001E46       BSR.W   L00001E98
L00001E4A       MOVEA.L (A7)+,A1
L00001E4C       CMP.W   #$07ff,D6
L00001E50       BEQ.B   L00001E62
L00001E52       SUB.W   #$021c,D5
L00001E56       SUB.B   #$00000001,$0003(A7)
L00001E5A       BEQ.B   L00001DE0
L00001E5C       ADDA.L  #$00000008,A0
L00001E5E       SUB.W   #$00000004,D5
L00001E60       BRA.B   L00001DFC
L00001E62       ADDA.W  #$001c,A7
L00001E66       MOVEM.L (A7)+,D0-D1/D5-D7/A0
L00001E6A       RTS 

;L00001E6C       ANDSR.B #$00fb
L00001E6C       AND.B   #$fb,CCR
L00001E70       BRA.B   L00001E62
L00001E72       MOVEM.L D1-D3,-(A7)
L00001E76       LSR.W   #$00000002,D0
L00001E78       SUB.W   #$00000001,D0
L00001E7A       MOVE.L  #$55555555,D1
L00001E80       MOVE.L  (A0)+,D2
L00001E82       MOVE.L  (A0)+,D3
L00001E84       AND.L   D1,D2
L00001E86       AND.L   D1,D3
L00001E88       ADD.L   D2,D2
L00001E8A       ADD.L   D3,D2
L00001E8C       MOVE.L  D2,(A1)+
L00001E8E       DBF.W   D0,L00001E80
L00001E92       MOVEM.L (A7)+,D1-D3
L00001E96       RTS 

L00001E98       MOVE.L  D1,-(A7)
L00001E9A       BTST.B  #$0006,$00dff002
L00001EA2       BNE.B   L00001E9A
L00001EA4       MOVE.L  #$00000000,D1
L00001EA6       MOVE.L  D1,$00dff064
L00001EAC       MOVE.L  D1,$00dff060
L00001EB2       MOVE.L  #$ffffffff,$00dff044
L00001EBC       MOVE.W  #$5555,$00dff070
L00001EC4       ADDA.W  D0,A0
L00001EC6       SUBA.L  #$00000002,A0
L00001EC8       MOVE.L  A0,$00dff050
L00001ECE       ADDA.W  D0,A0
L00001ED0       MOVE.L  A0,$00dff04c
L00001ED6       ADDA.L  #$00000002,A0
L00001ED8       ADDA.W  D0,A1
L00001EDA       SUBA.W  #$00000002,A1
L00001EDC       MOVE.L  A1,$00dff054
L00001EE2       ADDA.W  #$00000002,A1
L00001EE4       MOVE.L  #$1dd80002,$00dff040
L00001EEE       LSL.W   #$00000005,D0
L00001EF0       ADD.W   #$00000001,D0
L00001EF2       MOVE.W  D0,$00dff058
L00001EF8       BTST.B  #$0006,$00dff002
L00001F00       BNE.B   L00001EF8
L00001F02       MOVE.L  (A7)+,D1
L00001F04       RTS 

L00001F06       MOVEM.L D1-D2/A0,-(A7)
L00001F0A       LSR.W   #$00000002,D0
L00001F0C       SUB.W   #$00000001,D0
L00001F0E       MOVE.L  #$00000000,D1
L00001F10       MOVE.L  (A0)+,D2
L00001F12       EOR.L   D2,D1
L00001F14       DBF.W   D0,L00001F10
L00001F18       AND.L   #$55555555,D1
L00001F1E       MOVE.L  D1,D0
L00001F20       MOVEM.L (A7)+,D1-D2/A0
L00001F24       RTS 



                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------
                ; END OF -- LOW LEVEL DISK ROUTINES
                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------









                ;--------------------------- init system --------------------------------
                ;-- 
init_system                                                             ;L00001F26
L00001F26       LEA.L   $00dff000,A6
L00001F2C       LEA.L   $00bfd100,A5
L00001F32       LEA.L   $00bfe101,A4

L00001F38       MOVE.L  #$00000000,D0

L00001F3A       MOVE.W  #$7fff,$009a(A6)
L00001F40       MOVE.W  #$1fff,$0096(A6)
L00001F46       MOVE.W  #$7fff,$009a(A6)

L00001F4C       LEA.L   L00001F58(PC),A0
L00001F50       MOVE.L  A0,$00000080
L00001F54       MOVEA.L A7,A0

L00001F56       TRAP    #$00000000

L00001F58       MOVEA.L A0,A7
L00001F5A       MOVE.W  #$0200,$0100(A6)
L00001F60       MOVE.W  D0,$0102(A6)
L00001F64       MOVE.W  D0,$0104(A6)
L00001F68       MOVE.W  D0,$0180(A6)
L00001F6C       MOVE.W  #$4000,$0024(A6)
L00001F72       MOVE.L  D0,$0040(A6)
L00001F76       MOVE.W  #$0041,$0058(A6)
L00001F7C       MOVE.W  #$8340,$0096(A6)
L00001F82       MOVE.W  #$7fff,$009e(A6)

L00001F88       MOVE.L  #$00000007,D1
L00001F8A       LEA.L   $0140(A6),A0

L00001F8E       MOVE.W  D0,(A0)
L00001F90       ADDA.L  #$00000008,A0
L00001F92       DBF.W   D1,L00001F8E

L00001F96       MOVE.L  #$00000003,D1
L00001F98       LEA.L   $00a8(A6),A0

L00001F9C       MOVE.W  D0,(A0)
L00001F9E       LEA.L   $0010(A0),A0
L00001FA2       DBF.W   D1,L00001F9C

L00001FA6       MOVE.B  #$7f,$0c00(A4)
L00001FAC       MOVE.B  D0,$0d00(A4)
L00001FB0       MOVE.B  D0,$0e00(A4)
L00001FB4       MOVE.B  D0,-$0100(A4)
L00001FB8       MOVE.B  #$03,$0100(A4)
L00001FBE       MOVE.B  D0,(A4)
L00001FC0       MOVE.B  #$ff,$0200(A4)
L00001FC6       MOVE.B  #$7f,$0c00(A5)
L00001FCC       MOVE.B  D0,$0d00(A5)
L00001FD0       MOVE.B  D0,$0e00(A5)
L00001FD4       MOVE.B  #$c0,-$0100(A5)
L00001FDA       MOVE.B  #$c0,$0100(A5)
L00001FE0       MOVE.B  #$ff,(A5)
L00001FE4       MOVE.B  #$ff,$0200(A5)

L00001FEA       LEA.L   L00002070(PC),A0
L00001FEE       MOVE.L  #$00000000,D0
L00001FF0       SUB.L   A0,D0
L00001FF2       MOVE.L  D0,$0026(A0)                                    ; set value of addr $00002096 to $FFFFDF90 below this routine.
L00001FF6       MOVE.L  A0,$00000004                                    ; A0 = $2070 ;This is an odd one($4.w is the reset PC counter)

L00001FFA       LEA.L   level1_interrupt_handler(PC),A0                 ; relocated addr: $0000209C
L00001FFE       MOVE.L  A0,$00000064                                    ; Level 1 Interrupt Vector

L00002002       LEA.L   level2_interrupt_handler(PC),A0                 ; relocated addr: $000020DA
L00002006       MOVE.L  A0,$00000068                                    ; Level 2 Interrupt Vector

L0000200A       LEA.L   level3_interrupt_handler(PC),A0                 ; relocated addr: $00002100
L0000200E       MOVE.L  A0,$0000006c                                    ; Level 3 Interrupt Vector

L00002012       LEA.L   level4_interrupt_handler(PC),A0                 ; relocated addr: $00002146
L00002016       MOVE.L  A0,$00000070                                    ; Level 4 Interrupt Vector

L0000201A       LEA.L   level5_interrupt_handler(PC),A0                 ; relocated addr: $0000215C
L0000201E       MOVE.L  A0,$00000074                                    ; Level 5 Interrupt Vector

L00002022       LEA.L   level6_interrupt_handler(PC),A0                 ; relocated addr: $00002182
L00002026       MOVE.L  A0,$00000078                                    ; Level 6 Interrupt Vector

L0000202A       MOVE.W  #$ff00,$0034(A6)
L00002030       MOVE.W  D0,$0036(A6)                                    ; D0.L = $FFFFDF90
L00002034       OR.B    #$ff,(A5)
L00002038       AND.B   #$87,(A5)
L0000203C       AND.B   #$87,(A5)
L00002040       OR.B    #$ff,(A5)
L00002044       MOVE.B  #$f0,$0500(A4)
L0000204A       MOVE.B  #$37,$0600(A4)
L00002050       MOVE.B  #$11,$0e00(A4)
L00002056       MOVE.B  #$91,$0500(A5)
L0000205C       MOVE.B  #$00,$0600(A5)
L00002062       MOVE.B  #$00,$0e00(A5)
L00002068       MOVE.B  #$1f,interrupt_flags_byte                       ; $0000209A  ; %00011111 - set 5 flags
L00002070       MOVE.W  #$7fff,$009c(A6)
L00002076       TST.B   $0c00(A4)
L0000207A       MOVE.B  #$8a,$0c00(A4)
L00002080       TST.B   $0c00(A5)
L00002084       MOVE.B  #$93,$0c00(A5)
L0000208A       MOVE.W  #$e078,$009a(A6)
;L00002090       MV2SR.W #$2000
L00002090       MOVE.W  #$2000,SR
L00002094       RTS 


L00002096       dc.w    $0000, $0000                            ; Set to the value $FFFFDF90 by init_system above







                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------
                ; INTERRUPT HANDLERS
                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------





interrupt_flags_byte                                            ; relocated addr: $0000209A
                dc.b    $1F
L0000209B       dc.b    $00

                ;-------------------------- level 1 interrupt handler --------------------------
                ;-- handler for level 1 interrupts as follows:-
                ;-- if SOFT (software) then clear SOFT bit in INTREQ.
                ;-- if TBE (serial) then clear TBE bit in INTREQ.
                ;-- if DSKBLK (diskblock) then set DSKBLK_FINISHED bit in Interrupt_flags_Byte
                ;-- 
level1_interrupt_handler                                        ; relocated addr: $0000209C
                MOVE.L  D0,-(A7)
                MOVE.W  $00dff01e,D0                            ; Read INTREQR

                BTST.L  #$0002,D0                               ; SOFT - Software Interrupt
                BNE.B   .level1_soft                            ; if SOFT = 1 then jmp $000020CE

                BTST.L  #$0001,D0                               ; DSKBLK - Disk Block Finished
                BNE.B   .level_dskblk                           ; if DSKBLK = 1 then jmp $000020BC
.level1_tbe
                MOVE.W  #$0001,$00dff09c                        ; Clear TBE serial port interrupt
                MOVE.L  (A7)+,D0
                RTE 
.level_dskblk
                BSET.B  #DSKBLK_FINISHED,interrupt_flags_byte   ; var addr: $0000209A
                MOVE.W  #$0002,$00dff09C                        ; Clear DSKBLK interrupt
                MOVE.L  (A7)+,D0
                RTE 
.level1_soft
                MOVE.W  #$0004,$00dff09c                        ; Clear SOFT Interrupt
                MOVE.L  (A7)+,D0
                RTE 




                ;-------------------------- level 2 interrupt handler --------------------------
                ;-- handler for level 2 interrupts as follows:-
                ;-- pretty much handles the 20ms timer ticks counters,
                ;-- ignores and clears off other level 2 interrupts
level2_interrupt_handler                                        ; relocated address: $000020DA
                MOVE.L  D0,-(A7)
                MOVE.B  $00bfed01,D0                            ; CIAA ICR, clears on read
                BPL.B   .not_ciaa_int                           ; MSB = 0 then not a CIAA interrupt, jmp $000020F4
.is_ciaa_int
                BSR.W   ciaa_interrupt_handler                  ; routine addr: $000021C0
                MOVE.W  #$0008,$00dff09c                        ; Clear PORTS bit of INTREQ
                MOVE.L  (A7)+,D0
                RTE 
.not_ciaa_int
                MOVE.W  #$0008,$00dff09c                        ; Clear PORTS bit of INTREQ
                MOVE.L  (A7)+,D0
                RTE 




                ;----------------------- level 3 interrupt handler -------------------------
                ;-- level 3 interrupt handler, operates as follows:-
                ;-- if COPER (copper) interrupt then clear COPER bit in INTREQ
                ;-- if VERTB (vertical blank) then increment frame_counter variable
                ;-- if BLIT (blit finished) then set BLIT_FINISHED bit of interrupt_flags_byte
                ;--
level3_interrupt_handler                                        ; relocated address: $00002100
                MOVE.L  D0,-(A7)
                MOVE.W  $00dff01e,D0                            ; Read INTREQR
                BTST.L  #$0004,D0                               ; COPER - Copper Interrupt
                BNE.B   .is_coper                               ; if COPER bit = 1 then jmp $00002138
.chk_vertb      
                BTST.L  #$0005,D0                               ; VERTB - Vertical Blank Interrupt
                BNE.B   .is_vertb                               ; if VERTB bit = 1 then jmp $00002126
.blt_finished
                BSET.B  #BLIT_FINISHED,interrupt_flags_byte     ; Set Bitter Finished Flag in $0000209A
                MOVE.W  #$0040,$00dff09c                        ; Clear Blitter Interrupt bit
                MOVE.L  (A7)+,D0
                RTE 
.is_vertb                                                       ; relocated address: $00002126
                ADD.W   #$0001,frame_counter                    ; increase frame counter variable - $00002144
                MOVE.W  #$0020,$00dff09c                        ; clear VERTB interrupt bit
                MOVE.L  (A7)+,D0
                RTE 
.is_coper                                                       ; relocated address: $00002138
                MOVE.W  #$0010,$00dff09c                        ; clear COPER interrupt bit
                MOVE.L  (A7)+,D0                            
                RTE                                             ; exit level 3 interrupt handler

frame_counter
                dc.w    $0000                                   ; relocated address: $00002144                                 




                ;----------------------- level 4 interrupt handler -----------------------
                ;-- handles level 4 interrupts as follows:-
                ;-- if audio interrupt occurs on any channel then clear the interrupt bit
                ;--
level4_interrupt_handler                                        ; relocated address: $00002146
                MOVE.L  D0,-(A7)
                MOVE.W  $00dff01e,D0                            ; Read INTREQR
                AND.W   #$0780,D0                               ; mask out interrupt bits, leaving aud0-aud3
                MOVE.W  D0,$00dff09a                            ; clear aud0-aud3 interrupt in INTREQ
                MOVE.L  (A7)+,D0
                RTE 




                ;----------------------- level 5 interrupt handler -----------------------
                ; handle level 5 interrupts by just clearing their bits in INTREQ
level5_interrupt_handler
                MOVE.L  D0,-(A7)
                MOVE.W  $00dff01e,D0
                BTST.L  #$000c,D0                                   
                BNE.B   .is_dsksyn                          ; if DSKSYN then jmp $00002176
.is_rbf
                MOVE.W  #$0800,$00dff09c                    ; clear RBF - Serial port buffer receive in INREQ
                MOVE.L  (A7)+,D0
                RTE 
.is_dsksyn
                MOVE.W  #$1000,$00dff09c                    ; clear DSKSYN bit in INTREQ
                MOVE.L  (A7)+,D0
                RTE 




                ;------------------- level 6 interrupt handler -----------------
                ;-- handle level 6 interrupts,
                ;-- If not a CIAB (EXTER) Interrupt then just clear the INTREQ bits
                ;-- else call 'level6_ciab' sub routine to handle Timer/FLG interrupts
                ;
level6_interrupt_handler                                        ; relocated address $00002182
                MOVE.L  D0,-(A7)
                MOVE.W  $00dff01e,D0                            ; read INTREQR
                BTST.L  #$000e,D0                               ; bit 14 INTEN - Master Interrupt (enable only)
                BNE.B   .inten_int                              ; if INTEN then jmp $000021B4
.chk_ciab_int
                MOVE.B  $00bfdd00,D0                            ; CIAB ICR - Interrupt Control Register (reading clears it also)                            
                BPL.B   .not_ciab_int                           ; if MSB = 0 then not a CIAB interrupt, jmp $000021A8
.is_ciab_int
                BSR.W   level6_ciab                             ; routine addr: $000021EC
                MOVE.W  #$2000,$00dff09c                        ; clear EXTERN - external interrupt (CIAB FLG)
                MOVE.L  (A7)+,D0
                RTE 
.not_ciab_int
                MOVE.W  #$2000,$00dff09c                        ; clear EXTERN - external interrupt (CIAB FLG)
                MOVE.L  (A7)+,D0
                RTE 
.inten_int
                MOVE.W  #$4000,$00dff09c                        ; Clear INTEN Bit 14 of INTREQ (strange as not an interrupt request bit)
                MOVE.L  (A7)+,D0
                RTE 




                ;--------------------- ciaa interrupt handler ----------------------
                ; called from level 2 interrupt handler when the interrupt was
                ; generated by the CIAA chip.
                ; IN: D0.b = CIAA ICR value (interrupt bits)
ciaa_interrupt_handler                                          ; relocated address $000021C0
                LSR.B   #$02,D0                                 ; shift out Timer B bit 2
                BCC.B   .chk_sp_int                             ; if not TimerB interrupt, jmp $000021C8
.is_timerA
                BSR.W   level2_ciaa_timerA                      ; relocated address: $00002228
.chk_sp_int
                LSR.B   #$02,D0                                 ; shift out SP bit bit 4 (kbd serial port full/empty)
                BCC.B   .exit                                   ; not SP interrupt, jmp $000021EA               
.is_sp_int
                MOVEM.L D1-D2/A0,-(A7)                          ; keyboard shenanigans????, maybe an ack signal back to keyboard, old code, D1 read then later restored
                MOVE.B  $00bfec01,D1                            ; D1 = serial data register (keyboard)
                MOVE.B  #$40,$00bfee01                          ; CIAA CRA (control reg), SSPMODE = 1 - Serial Port CNT is shift source
                MOVE.B  #$19,$00bfdf00                          ; CIAB CRB (control reg), RUNMODE = 1 (oneshot), START = 1 (Timer B), LOAD = 1 (force load)
                MOVEM.L (A7)+,D1-D2/A0
.exit
                RTS 




                ;------------------------------- level 6 CIAB -----------------------------
                ;-- Handles CIAB Level 6 Interrupt, called from Level 6 Interrupt Handler
                ;--
                ;-- If TimerA interrupt then set Timer A Interupt Flag
                ;-- If TimerB interrupt then set CIAA CRA (Control Register A) (Keyboard Ack?)
                ;-- If FLG Interrupt and Interrupt_flags_Byte Bits 3 & 4 are 0 then 
                ;--        -- Initiate a 6.5K DMA disk write
                ;--        -- Sets Interrupt_flags_Byte Bits 3 & 4 to 1
level6_ciab                                                 ; relocated address: $000021EC
                LSR.B   #$01,D0                             ; shift out Timer A interrupt bit
                BCC.B   .chk_timerB_int                     ; Not a Timer A interrupt, jmp $000021F6 
.timerA_int
                BSET.B  #$02,interrupt_flags_byte           ; Set Timer A Interrupt Flag
.chk_timerB_int
                LSR.B   #$01,D0                             ; shift out Timer B interrupt bit
                BCC.B   .chk_flg_int                        ; Not a Timer B interrupt, jmp $00002202
.timerB_int
                MOVE.B  #$00,$00bfee01                      ; CIAA CRA; SPMODE = 0 (input), INMODE = 0, RUNMODE = 0 (continuous), OUTMODE = 0 (pulse), PBON = 0, START = 0 (Timer A stop) 
.chk_flg_int
                LSR.B   #$03,D0                             ; shift out FLG interrupt bit
                BCC.B   .exit                               ; Not a FLG interrupt (DSKINDEX) then jmp $00002226 (exit)
.dskindex1_int
                BSET.B  #DISK_INDEX1,interrupt_flags_byte   ; Set DSKINDEX1 Interrupt Flag1, var addr: $0000209A
                BNE.B   .exit                               ; if DSKINDEX1 was 1, then jmp $00002226 (exit)
.dskindex2_int
                BSET.B  #DISK_INDEX2,interrupt_flags_byte   ; set DSKINDEX2 Interrupt Flag2 (if dskindex1 was 0), var addr: $0000209A
                BNE.B   .exit                               ; if DSKINDEX2 was 1, then jmp $00002226 (exit)
.dsk_write
                MOVE.W  #$da00,D0                           ; $DA00 - DMAEN = 1, WRITE = 1, LENGTH = $1A00 (6656 bytes - 6.5K) 
                MOVE.W  D0,$00dff024                        ; Set value twice to enable disk DMA
                MOVE.W  D0,$00dff024                        ; 
.exit
                RTS 




               ;--------------------------------- level 2 CIAA Timer A -----------------------------
               ;-- called from ciaa_interrupt_handler to handle CIAA TimerA interrupts as follows:-
               ;-- decrement then ld_ciab_20ms_countdown counter, clamping it at 0
               ;-- increment the ciab_tb_20ms_tick, no clamping so will eventually overflow
               ;--
level2_ciaa_timerA                                                      ; relocated address: $00002228
                TST.W   ld_ciab_20ms_countdown                          ; $00001B04
                BEQ.B   .increment_counter                              ; if countdown is 0 then skip decrement, jmp $00002232
.decrement_counter
                SUB.W   #$0001,ld_ciab_20ms_countdown                   ; $00001B04
.increment_counter
                ADD.W   #$0001,ciab_tb_20ms_tick                        ; $0000223A
                RTS 

ciab_tb_20ms_tick                                                       ; $0000223A ; CIAB - TIMER B - Underflow counter, increments every 20ms                
                dc.w $0000 






                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------
                ; END OF - INTERRUPT HANDLERS
                ;---------------------------------------------------------------------------------------------------
                ;---------------------------------------------------------------------------------------------------












L0000223C       dc.w $3033, $0000
L00002240       dc.w $00F0, $0002, $000F, $0F0D, $0000, $0000, $000F, $0F0D             ;................
L00002250       dc.w $0000, $0070 
L00002254       dc.w $F007, $0FF8, $0FF8, $F007, $F0F7, $08F8             ;...p............

L00002260       dc.w $0F08, $F7F7, $F717, $0818, $0FE8, $F7F7, $F047, $0FB8             ;.............G..
L00002270       dc.w $0FF8, $F1C7, $FD9F, $0260, $03E0, $FDDF, $FC5F, $0220             ;.......`....._. 
L00002280       dc.w $03E0, $FDDF, $FD1F, $0320, $02E0, $FDDF, $FDDF, $03E0             ;....... ........
L00002290       dc.w $0220, $FDDF, $F05F, $0E60, $0FA0, $F1DF, $F19F, $0820             ;. ..._.`....... 
L000022A0       dc.w $0FE0, $F7DF, $F65F, $0E20, $09E0, $F7DF, $FB9F, $07A0             ;....._. ........
L000022B0       dc.w $0460, $FBDF, $FDDF, $03E0, $0220, $FDDF, $FE1F, $01E0             ;.`....... ......
L000022C0       dc.w $01E0, $FE1F, $E003, $1FFC, $1FFC, $E003, $EE3B, $1E04             ;.............;..
L000022D0       dc.w $11FC, $EFFB, $EFC3, $1FC4, $103C, $EFFB, $E203, $13FC             ;.........<......
L000022E0       dc.w $1DFC, $EE03, $F47F, $0980, $0F80, $F67F, $F33F, $08C0             ;.............?..
L000022F0       dc.w $0FC0, $F73F, $F80F, $0430, $07F0, $FBCF, $FCC7, $03C8             ;...?...0........
L00002300       dc.w $0338, $FCF7, $FF3B, $00FC, $00C4, $FF3B, $E1CB, $1E2C             ;.8...;.....;...,
L00002310       dc.w $1E34, $E1DB, $E013, $11C4, $1FFC, $EE3B, $EC0B, $1C04             ;.4.........;....
L00002320       dc.w $13FC, $EFFB, $F7F7, $0FF8, $0808, $F7F7, $F80F, $07F0             ;................
L00002330       dc.w $07F0, $F80F


disk_logo
L00002334       dc.w $0000, $0000, $0200, $1301, $2402, $3503                           ;........$.5.
L00002340       dc.w $4602, $2203, $3304, $4405, $5505, $2006, $3007, $4007             ;F.".3.D.U. .0.@.
L00002350       dc.w $5007, $6106, $6601, $6B03, $0900, $04D4, $FC02, $0702             ;P.a.f.k.........
L00002360       dc.w $0202, $FF02, $FF0D, $FD0B, $FF04, $2B05, $0702, $59FD             ;..........+...Y.
L00002370       dc.w $021F, $FE09, $FB3A, $FF58, $FC1F, $02FE, $11F3, $02FF             ;.....:.X........
L00002380       dc.w $02F3, $185A, $FF25, $0EF2, $09F2, $155A, $FF05, $FF1B             ;...Z.%.....Z....
L00002390       dc.w $040E, $F209, $F215, $5AFF, $05FF, $1AFF, $0411, $F302             ;......Z.........
L000023A0       dc.w $FF02, $F318, $59FB, $1EFC, $09FB, $3A59, $F326, $FE38             ;....Y.....:Y.&.8
L000023B0       dc.w $FD00, $09B8, $FE02, $FE09, $0202, $FF02, $FF0D, $02FF             ;................
L000023C0       dc.w $0BFF, $2F04, $FF07, $FF5A, $FE02, $FF1F, $FE09, $FC3A             ;../....Z.......:
L000023D0       dc.w $FF59, $FD20, $02FE, $09FE, $06F3, $0302, $FD02, $F817             ;.Y. ............
L000023E0       dc.w $FF00, $0080, $09FE, $03FB, $02F9, $09FC, $02F8, $14FF             ;................
L000023F0       dc.w $601C, $0409, $FE03, $FB02, $F909, $FC02, $F814, $FF60             ;`..............`
L00002400       dc.w $1C04, $09FE, $06F3, $0302, $FD02, $F817, $FF59, $FB1F             ;.............Y..
L00002410       dc.w $FD09, $FC3A, $FF59, $F628, $FF02, $38FE, $0009, $B9FE             ;...:.Y.(..8.....
L00002420       dc.w $03FF, $0902, $02FF, $02FF, $0D02, $FF0B, $FF2F, $0508             ;............./..
L00002430       dc.w $5BFF, $02FF, $1FFE, $47FF, $59FD, $20FC, $11F3, $0302             ;[.....G.Y. .....
L00002440       dc.w $FF02, $02F8, $17FF, $7FFF, $0EF9, $03FC, $09FC, $0203             ;................
L00002450       dc.w $02FD, $14FF, $60FF, $1AFF, $03FF, $0EF9, $03FC, $09FC             ;....`...........
L00002460       dc.w $0203, $02FD, $14FF, $60FF, $1AFF, $03FF, $11F3, $0302             ;......`.........
L00002470       dc.w $FF02, $02F8, $17FF, $59FB, $1FFD, $47FF, $59F6, $6300             ;......Y...G.Y.c.
L00002480       dc.w $0AB5, $FE3A, $5AFD, $2002, $FF0C, $06F3, $05FD, $02F8             ;...:Z. .........
L00002490       dc.w $175A, $260C, $03F9, $02FB, $09FC, $0203, $FB14, $5A07             ;.Z&...........Z.
L000024A0       dc.w $1C03, $0C03, $F902, $FB09, $FC02, $03FB, $145A, $071C             ;.............Z..
L000024B0       dc.w $030C, $06F3, $05FD, $02F8, $175A, $FF23, $FE0C, $FE3A             ;.........Z.#...:

L000024C0       dc.w $0005, $AEFF, $0000, $0555, $0551, $7FFD, $FFFE, $7FFE             ;.......U.Q......
L000024D0       dc.w $7FFF, $7F7F, $7DBF, $7BDF, $73CF, $7FBF, $7C7F, $7FFF             ;....}.{.s...|...
L000024E0       dc.w $7FFE, $7FFD, $7FFE, $7FFF, $7FFE, $7FFD, $7FFF, $701F             ;..............p.
L000024F0       dc.w $7FFF, $3FFF, $0000, $81FF, $FC00, $07FF, $0FFF, $FFFF             ;..?.............
L00002500       dc.w $7FFF, $FD00, $FFFF, $9FFF, $7FFF, $DFFF, $FFFF, $7FFF             ;................
L00002510       dc.w $FFFF, $8000, $0000, $103C, $BF17, $4178, $80FC, $8000             ;.......<..Ax....
L00002520       dc.w $A000, $D800, $0000, $FFFF, $FFF8, $FFE7, $FF9F, $FF60             ;...............`
L00002530       dc.w $FCE0, $F900, $F600, $EC00, $CC00, $D800, $B800, $9000             ;................
L00002540       dc.w $7000, $6000, $2000, $6000, $5000, $B800, $B807, $D800             ;p.`. .`.P.......
L00002550       dc.w $C806, $EE03, $F704, $FB87, $FC83, $FF79, $FF9C, $FFE3             ;...........y....
L00002560       dc.w $FFFC, $FFFF, $0000, $FFFF, $0000, $FFFF, $FFC0, $F03F             ;...............?
L00002570       dc.w $0FC0, $F03F, $E077, $03F7, $0FF3, $1F10, $3810, $2390             ;...?.w......8.#.
L00002580       dc.w $0E20, $3860, $1BC0, $0780, $0000, $C180, $E860, $3010           ;. 8`.........`0.
L00002590       dc.w $9018, $C00C, $000C, $F006, $BF0E, $C7FE, $E01F, $7C01             ;..............|.
L000025A0       dc.w $8FF0, $F03F, $FFC0, $FFFF, $0000, $FFFF, $0000, $0038             ;...?...........8
L000025B0       dc.w $003F, $0000, $FFFF, $03FF, $FC0F, $03F0, $FC0F, $EE07             ;.?..............
L000025C0       dc.w $EFC0, $CFF0, $08F8, $081C, $09C4, $0470, $061C, $03D8             ;...........p....
L000025D0       dc.w $01E0, $0000, $0183, $0617, $080C, $1809, $3003, $3000           ;............0.0.
L000025E0       dc.w $600F, $70FD, $7FE3, $F807, $803E, $0FF1, $FC0F, $03FF             ;`.p......>......
L000025F0       dc.w $FFFF, $0000, $FFFF, $0000, $0020, $FFC0, $FFA0, $0000             ;......... ......
L00002600       dc.w $FFFF, $1FFF, $E7FF, $F9FF, $06FF, $073F, $009F, $006F             ;...........?...o
L00002610       dc.w $0037, $0033, $001B, $001D, $0009, $000E, $0006, $0004             ;.7.3............
L00002620       dc.w $0006, $000A, $001D, $E01D, $001B, $6013, $C077, $20EF             ;..........`..w .
L00002630       dc.w $E1DF, $C13F, $9EFF, $39FF, $C7FF, $3FFF, $FFFF, $0000             ;...?..9...?.....
L00002640       dc.w $2000, $F03F, $10C0, $17FF, $19FF, $17FF, $07FF, $17FF             ; ..?............
L00002650       dc.w $2FFF, $7FFF, $FFFF, $FFF9, $FFFD, $FFFA, $FFFF, $FFFE             ;/...............
L00002660       dc.w $FFFF, $0000, $3E00, $A100, $1E00, $FF00, $FFA0, $FFD0             ;....>...........
L00002670       dc.w $FFE8, $FFF4, $FFFA, $FFFC, $FFFF, $FFFE, $FFFF, $FFFE             ;................
L00002680       dc.w $3FFE, $BFFE, $FFFE, $FFFF, $FFFE, $7FFE, $0000, $1FFF             ;?...............
L00002690       dc.w $3551, $7FFD, $FFFD, $FFFC, $FFFD, $FDFD, $FBFD, $F1CD             ;5Q..............
L000026A0       dc.w $FDFD, $FC7D, $FFFD, $FFFC, $FFFE, $FFFF, $FFFE, $FFFD             ;...}............
L000026B0       dc.w $F01D, $F7FD, $FFFD, $7FFC, $0000, $FFFF, $FC00, $FFFF             ;................
L000026C0       dc.w $0FFF, $FFFF, $7FFF, $0000, $FFFF, $E000, $FFFF, $C000             ;................
L000026D0       dc.w $8000, $0000, $FFFF, $0000, $307E, $C1F4, $40DC, $C000             ;........0~..@...
L000026E0       dc.w $E000, $F800, $0000, $FFFF, $0000, $FFFF, $0000, $0007             ;................
L000026F0       dc.w $001F, $007B, $00E0, $03E0, $0500, $0A00, $1400, $2C00             ;...{..........,.
L00002700       dc.w $3800, $7800, $5000, $9000, $A000, $E000, $9000, $5800             ;8.x.P.........X.
L00002710       dc.w $5807, $280F, $1C0F, $0F03, $0500, $0380, $00F8, $007C             ;X.(............|
L00002720       dc.w $001C, $0003, $0000, $FFFF, $0000, $FFFF, $0000, $FFFF             ;................
L00002730       dc.w $0000, $003F, $0FFF, $FFC0, $F000, $C000, $0010, $00F0             ;...?............

L00002740       dc.w $07F0, $1FF0, $3FE0, $1FE0, $0F80, $0780, $0000, $4180             ;....?.........A.
L00002750       dc.w $E3E0, $FFF0, $FFE8, $FFF4, $0FFA, $00F2, $0002, $0001             ;................
L00002760       dc.w $8001, $7000, $0FC0, $003F, $0000, $FFFF, $0000, $001F             ;..p....?........
L00002770       dc.w $0000, $FFFF, $0000, $FFFF, $0000, $FC00, $FFF0, $03FF             ;................
L00002780       dc.w $000F, $0003, $0800, $0F00, $0FE0, $0FF8, $07FC, $07F8             ;................
L00002790       dc.w $01F0, $01E0, $0000, $0182, $07C7, $0FFF, $17FF, $2FFF           ;............../.
L000027A0       dc.w $5FF0, $4F00, $4000, $8000, $8001, $000E, $03F0, $FC00             ;_.O.@...........
L000027B0       dc.w $0000, $FFFF, $0000, $FFE0, $0000, $FFFF, $0000, $FFFF             ;................
L000027C0       dc.w $0000, $E000, $F800, $DE00, $0700, $07C0, $00A0, $0050             ;...............P
L000027D0       dc.w $0028, $0034, $001C, $001E, $000A, $0009, $0005, $0007             ;.(.4............
L000027E0       dc.w $0009, $001A, $E01A, $F014, $F038, $C0F0, $00A0, $01C0             ;.........8......
L000027F0       dc.w $1F00, $3E00, $3800, $C000, $0000, $FFFF, $0000, $3000             ;..>.8.........0.
L00002800       dc.w $107F, $0000, $0E7F, $08FF, $0FFF, $1FFF, $3FFF, $7FFF             ;............?...
L00002810       dc.w $FFFF, $0007, $FFFE, $0003, $0001, $0000, $FFFF, $0000             ;................
L00002820       dc.w $7F00, $A180, $1E40, $FF20, $FF90, $FFC8, $FFE4, $FFF2           ;.....@. ........
L00002830       dc.w $FFF9, $FFFC, $FFFE, $7FFE, $FFFE, $BFFE, $BFFF, $3FFF             ;..............?.
L00002840       dc.w $0000, $1AAA, $3FFE, $0002, $0003, $0002, $0202, $0402             ;....?...........
L00002850       dc.w $0E32, $0202, $0382, $0002, $0003, $0001, $0000, $0001             ;.2..............
L00002860       dc.w $0002, $0802, $0002, $0000, $03FF, $0000, $F000, $0000             ;................
L00002870       dc.w $8000, $FFFF, $0000, $FFFF, $0000, $307E, $01F4, $80DC             ;..........0~....
L00002880       dc.w $0000, $2000, $0000, $0800, $FFFF, $0000, $0007, $0018             ;.. .............
L00002890       dc.w $0063, $0080, $0360, $0600, $0C00, $1800, $3000, $2000             ;.c...`......0. .
L000028A0       dc.w $4000, $6000, $E000, $C000, $8000, $E000, $6800, $300F             ;@.`.........h.0.
L000028B0       dc.w $100F, $0907, $0607, $0303, $0099, $0060, $001F, $0003             ;...........`....
L000028C0       dc.w $0000, $FFFF, $0000, $FFFF, $0000, $003F, $0FC0, $F03F             ;...........?...?
L000028D0       dc.w $0FFF, $C3F7, $0FE7, $1FE3, $3FE0, $3FC0, $1F80, $0C00             ;........?.?.....
L000028E0       dc.w $0780, $0000, $4000, $2380, $DFE0, $EFF0, $FFF8, $FFFC             ;....@.#.........
L000028F0       dc.w $FFFE, $7FFF, $0FFF, $003F, $0000, $FFFF, $0000, $0010             ;.......?........
L00002900       dc.w $0000, $0010, $0000, $FFFF, $0000, $FC00, $03F0, $FC0F             ;................
L00002910       dc.w $FFF0, $EFC3, $E7F0, $C7F8, $07FC, $03FC, $01F8, $0030             ;...............0
L00002920       dc.w $01E0, $0000, $0002, $01C4, $07FB, $0FF7, $1FFF, $3FFF             ;..............?.
L00002930       dc.w $7FFF, $FFFE, $FFF0, $FC00, $0000, $FFFF, $0000, $0020             ;............... 
L00002940       dc.w $0000, $0020, $0000, $FFFF, $0000, $E000, $1800, $C600             ;... ............
L00002950       dc.w $0100, $06C0, $0060, $0030, $0018, $000C, $0004, $0002             ;.....`.0........
L00002960       dc.w $0006, $0007, $0003, $0001, $0007, $0016, $F00C, $F008             ;................
L00002970       dc.w $E090, $E060, $C0C0, $9900, $0600, $F800, $C000, $0000             ;...`............
L00002980       dc.w $FFFF, $0000, $3000, $1040, $00FF, $0180, $0700, $0000           ;....0..@........
L00002990       dc.w $1000, $2000, $8000, $0000, $FFFF, $0000, $4000, $7E00             ;.. .........@.~.
L000029A0       dc.w $E180, $00C0, $0060, $0030, $0018, $000C, $0006, $0003           ;.....`.0........
L000029B0       dc.w $0001, $0000, $3FFF, $7FFF, $FFFF, $0000, $0F81, $3F0B             ;....?.........?.

L000029C0       dc.w $3F3B, $3FFF, $1FFF, $07FF, $0000, $FFFF, $FFF8, $FFE7             ;?;?.............
L000029D0       dc.w $FF9F, $FF78, $FC80, $FB00, $F600, $EC00, $DC00, $D800             ;...x............
L000029E0       dc.w $B800, $B000, $7000, $6000, $7000, $B000, $B007, $DC0F             ;....p.`.p.......
L000029F0       dc.w $EE0F, $F707, $FB87, $FCE3, $FF61, $FF9C, $FFE3, $FFFC             ;.........a......
L00002A00       dc.w $FFFF, $0000, $FFFF, $0000, $FFFF, $FFC0, $F03F, $0FFF             ;.............?..
L00002A10       dc.w $FFFF, $FFF7, $0FF7, $1FF3, $3FF0, $7FF0, $7FE0, $3FF0             ;........?.....?.
L00002A20       dc.w $1FE0, $0780, $0000, $C180, $EBE0, $F7F0, $F7F8, $FFFC           ;................
L00002A30       dc.w $FFFE, $FFFF, $7FFF, $8FFF, $F03F, $FFC0, $FFFF, $0000             ;.........?......
L00002A40       dc.w $FFFF, $FFE0, $FFFF, $0000, $FFFF, $03FF, $FC0F, $FFF0             ;................
L00002A50       dc.w $FFFF, $EFFF, $EFF0, $CFF8, $0FFC, $0FFE, $07FE, $0FFC             ;................
L00002A60       dc.w $07F8, $01E0, $0000, $0183, $07D7, $0FEF, $1FEF, $3FFF           ;..............?.
L00002A70       dc.w $7FFF, $FFFF, $FFFE, $FFF1, $FC0F, $03FF, $FFFF, $0000             ;................
L00002A80       dc.w $FFFF, $001F, $FFFF, $0000, $FFFF, $1FFF, $E7FF, $F9FF             ;................
L00002A90       dc.w $1EFF, $013F, $00DF, $006F, $0037, $003B, $001B, $001D             ;...?...o.7.;....
L00002AA0       dc.w $000D, $000E, $0006, $000E, $000D, $E00D, $F03B, $F077             ;.............;.w
L00002AB0       dc.w $E0EF, $E1DF, $C73F, $86FF, $39FF, $C7FF, $3FFF, $FFFF             ;.....?..9...?...
L00002AC0       dc.w $0000, $C000, $F000, $E000, $C000, $0000, $FFFC, $FFFE             ;................
L00002AD0       dc.w $FFFF, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002AE0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002AF0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B00       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B10       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B20       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B30       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B40       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B50       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B60       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B70       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B80       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002B90       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002BA0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002BB0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002BC0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002BD0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002BE0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002BF0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002C00       dc.w $464F, $524D, $0000, $A0CE, $494C, $424D, $424D, $4844             ;FORM....ILBMBMHD
L00002C10       dc.w $0000, $0014, $0140, $0100, $0000, $0000, $0500, $0100             ;.....@..........
L00002C20       dc.w $0000, $0101, $0140, $0100, $434D, $4150, $0000, $0060             ;.....@..CMAP...`
L00002C30       dc.w $0000, $0050, $2010, $3010, $0070, $3010, $8030, $10A0             ;...P .0..p0..0..

L00002C40       dc.w $4010, $B050, $10D0, $6010, $E070, $00F0, $8000, $F090             ;@..P..`..p......
L00002C50       dc.w $00F0, $A000, $F0B0, $00F0, $C000, $F0E0, $00F0, $F000             ;................
L00002C60       dc.w $8020, $0070, $2000, $6020, $0000, $0000, $1010, $1020             ;. .p .` ....... 
L00002C70       dc.w $2020, $3030, $3040, $4040, $5050, $5060, $6070, $7070             ;  000@@@PPP``ppp
L00002C80       dc.w $8080, $8090, $9090, $A0A0, $A0B0, $B0B0, $C0D0, $D0E0             ;................
L00002C90       dc.w $4450, $5053, $0000, $006E, $0002, $0005, $4111, $0000             ;DPPS...n....A...
L00002CA0       dc.w $0000, $0000, $0000, $0168, $0000, $0140, $00C8, $0002             ;.......h...@....
L00002CB0       dc.w $005A, $0002, $0000, $0002, $0000, $0002, $0000, $0000             ;.Z..............
L00002CC0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002CD0       dc.w $0000, $0000, $0000, $0000, $0000, $0000, $0004, $0069             ;...............i
L00002CE0       dc.w $F494, $0001, $0000, $0000, $0000, $0000, $0000, $0000             ;................
L00002CF0       dc.w $0000, $0000, $8402, $0000, $DB56, $0000, $0000, $FFFF             ;.........V......
L00002D00       dc.w $24AA, $0000, $8402, $4352, $4E47, $0000, $0008, $1376             ;$.....CRNG.....v
L00002D10       dc.w $0A00, $0001, $0000, $4352, $4E47, $0000, $0008, $12F2             ;......CRNG......
L00002D20       dc.w $0AAA, $0001, $0000, $4352, $4E47, $0000, $0008, $0000             ;......CRNG......
L00002D30       dc.w $0AAA, $0001, $0000, $4352, $4E47, $0000, $0008, $0000             ;......CRNG......
L00002D40       dc.w $0AAA, $0001, $0000, $4352, $4E47, $0000, $0008, $0000             ;......CRNG......
L00002D50       dc.w $0000, $0001, $0000, $4352, $4E47, $0000, $0008, $0000             ;......CRNG......
L00002D60       dc.w $0000, $0001, $0000, $4341, $4D47, $0000, $0004, $0000             ;......CAMG......
L00002D70       dc.w $4000, $424F, $4459, $0000, $9F5C, $FB00, $0201, $C380             ;@.BODY...\......
L00002D80       dc.w $FD00, $0018, $EF00, $0101, $40FB, $00FB, $0002, $0181             ;........@.......
L00002D90       dc.w $80FD, $0000, $88EF, $0001, $0140, $FB00, $FB00, $0201             ;.........@......
L00002DA0       dc.w $8580, $FE00, $0102, $E8EF, $0001, $01C0, $FB00, $FA00             ;................
L00002DB0       dc.w $0046, $FD00, $0102, $70EF, $0001, $01C0, $FB00, $FB00             ;.F....p.........
L00002DC0       dc.w $0201, $C780, $FE00, $0102, $F8EF, $0001, $01C0, $FB00             ;................
L00002DD0       dc.w $FA00, $1BC3, $70CB, $5800, $01D6, $6A81, $CCCE, $408F             ;....p.X...j...@.
L00002DE0       dc.w $F57E, $001A, $BE00, $0559, $AA00, $0FCF, $C1FD, $5CFC             ;.~.....Y......\.
L00002DF0       dc.w $00FA, $001B, $187F, $0890, $0001, $C819, $81F0, $F07F             ;................
L00002E00       dc.w $8079, $8000, $1CC3, $0006, $6066, $000F, $C601, $8338             ;.y......`f.....8
L00002E10       dc.w $FC00, $FA00, $1B3C, $8008, $E000, $01E0, $0701, $FF00             ;.....<..........
L00002E20       dc.w $7F80, $7E00, $003F, $0000, $0780, $1C00, $0FF6, $2080             ;..~..?........ .
L00002E30       dc.w $FCFC, $00FA, $00FF, $FF19, $F700, $0001, $FFFF, $01FF             ;................
L00002E40       dc.w $FF80, $7F7F, $FC00, $1FFE, $0007, $FFFC, $000F, $F9C0             ;................
L00002E50       dc.w $FFF8, $FC00, $FA00, $00E7, $FD00, $0301, $F000, $01FD             ;................
L00002E60       dc.w $0006, $6000, $0010, $0000, $04FE, $0004, $07FE, $0080             ;..`.............
L00002E70       dc.w $04FC, $00FA, $001B, $1931, $96DA, $0005, $EBD5, $81E6             ;.......1........
L00002E80       dc.w $6721, $1FFA, $BE00, $2D5D, $0002, $AF56, $000F, $E7C0             ;g!....-]...V....
L00002E90       dc.w $FAB4, $FC00, $FA00, $1B18, $3E11, $1400, $05EC, $3380             ;........>.....3.
L00002EA0       dc.w $F878, $3F00, $3CC2, $000E, $6600, $0730, $CE00, $0FE3             ;.x?.<...f..0....
L00002EB0       dc.w $00C6, $78FC, $00FA, $001B, $7FC0, $11E0, $0007, $F00E             ;..x.............

L00002EC0       dc.w $00FF, $803F, $003F, $0000, $3F80, $0007, $C038, $000F             ;...?.?..?....8..
L00002ED0       dc.w $FB61, $41F0, $FC00, $FA00, $1B7F, $FFEE, $0000, $03FF             ;.aA.............
L00002EE0       dc.w $FE01, $FFFF, $C0FE, $7FF8, $000F, $FC00, $07FF, $F800             ;................
L00002EF0       dc.w $0FFC, $817F, $F0FC, $00FA, $0000, $7EFD, $0004, $07E0             ;..........~.....
L00002F00       dc.w $0000, $80FE, $0006, $3000, $0008, $0000, $02FE, $0003             ;......0.........
L00002F10       dc.w $0FFF, $0140, $FB00, $FA00, $093D, $9B2D, $9B00, $07ED             ;...@.....=.-....
L00002F20       dc.w $FF81, $DFFE, $FF0E, $BFFC, $003F, $FF00, $056F, $FE00             ;.........?...o..
L00002F30       dc.w $0FFF, $C35F, $FCFC, $00FA, $001B, $3E1C, $2215, $0003             ;..._......>."...
L00002F40       dc.w $E6FF, $805F, $FFFF, $FE7F, $FC00, $0FFC, $0007, $3FFE             ;..._..........?.
L00002F50       dc.w $000F, $FF80, $5FF0, $FC00, $FA00, $093F, $E023, $E000             ;...._......?.#..
L00002F60       dc.w $07F7, $0000, $60FE, $000D, $7802, $0030, $0000, $03B0             ;....`...x..0....
L00002F70       dc.w $0000, $0F80, $61A0, $FB00, $FA00, $093F, $FFDC, $0000           ;....a......?....
L00002F80       dc.w $01F8, $0001, $E0FE, $0000, $78FC, $0007, $03C0, $0000             ;........x.......
L00002F90       dc.w $0F80, $0220, $FB00, $FA00, $003C, $FD00, $1607, $FFFC             ;... .....<......
L00002FA0       dc.w $007F, $FFFF, $FE3F, $F800, $0FFC, $0001, $FFF0, $0007             ;.....?..........
L00002FB0       dc.w $FF82, $7FF0, $FC00, $FA00, $093F, $FFFF, $F600, $00DF             ;.........?......
L00002FC0       dc.w $FF81, $DFFE, $FF0E, $93FC, $001F, $FF00, $06FF, $FE00             ;................
L00002FD0       dc.w $07BF, $C4FF, $FCFC, $00FA, $001B, $3FFF, $FFEA, $0000             ;..........?.....
L00002FE0       dc.w $DFFF, $804F, $FFFF, $FE13, $FC00, $2FFD, $0006, $FFFE             ;...O....../.....
L00002FF0       dc.w $000F, $BF85, $6FF0, $FC00, $FA00, $093C, $0000, $0180             ;....o......<....
L00003000       dc.w $03E0, $0000, $20FE, $000D, $6C02, $0030, $0000, $0180             ;.... ...l..0....
L00003010       dc.w $0000, $0DC0, $6580, $FB00, $FA00, $003C, $FD00, $0403             ;....e......<....
L00003020       dc.w $E000, $01B0, $FE00, $00EC, $FC00, $0701, $8000, $000D           ;................
L00003030       dc.w $C000, $10FB, $00FA, $001B, $3FFF, $FFE0, $0003, $FFFE             ;........?.......
L00003040       dc.w $007F, $FFFF, $FE7F, $F800, $0FFC, $0001, $FFF8, $0003             ;................
L00003050       dc.w $FF84, $7FF0, $FC00, $FA00, $0819, $FFFF, $FE00, $06DF             ;................
L00003060       dc.w $FF81, $FDFF, $0E7F, $FD00, $7FFF, $0004, $FFFE, $0003             ;................
L00003070       dc.w $3FF1, $7FFC, $FC00, $FA00, $1B19, $FFFF, $FE00, $00CF             ;?...............
L00003080       dc.w $FF00, $6FFF, $FFFE, $19F9, $002F, $FF00, $01BF, $FC00             ;..o....../......
L00003090       dc.w $0F1F, $99FF, $F0FC, $00FA, $0009, $7E00, $0001, $C005             ;..........~.....
L000030A0       dc.w $2000, $C008, $FE00, $0D80, $0200, $6000, $000F, $0003             ; .........`.....
L000030B0       dc.w $000C, $C029, $88FB, $00FA, $0000, $7EFD, $0008, $0330             ;...)......~....0
L000030C0       dc.w $0001, $9000, $0001, $E6FB, $0004, $4000, $000C, $E0F9             ;..........@.....
L000030D0       dc.w $00FA, $001B, $7FFF, $FFF8, $0007, $FFFF, $007F, $FFFF             ;................
L000030E0       dc.w $FEDF, $F800, $0FFC, $0001, $FFFC, $0003, $FF88, $7FF0             ;................
L000030F0       dc.w $FC00, $FA00, $09CB, $FFFF, $FC00, $07FF, $FF81, $FBFC             ;................
L00003100       dc.w $FF0C, $005F, $FF00, $05FF, $FE00, $0BDF, $F0FB, $FCFC             ;..._............
L00003110       dc.w $00FA, $001B, $18FF, $FFFC, $0004, $EFFF, $007F, $FFFF             ;................
L00003120       dc.w $FE1F, $FC00, $1FFF, $0001, $FFFC, $0007, $9FC0, $FFF0             ;................
L00003130       dc.w $FC00, $FA00, $0934, $0000, $03C0, $0508, $00C0, $0CFE             ;.....4..........

L00003140       dc.w $00FF, $03FD, $0007, $0E20, $0300, $0C30, $3084, $FB00             ;....... ...00...
L00003150       dc.w $FA00, $00F7, $FD00, $0B02, $1000, $0180, $0000, $01E0           ;................
L00003160       dc.w $0000, $60FB, $0002, $0C60, $01FA, $00FA, $0009, $EFFF             ;..`....`........
L00003170       dc.w $FFFC, $0006, $FFFF, $007F, $FEFF, $0E9F, $FC00, $1FFC             ;................
L00003180       dc.w $0001, $FFFC, $0003, $FFD0, $7FF0, $FC00, $FB00, $0001             ;................
L00003190       dc.w $FDFF, $1700, $06FB, $FF41, $FBFF, $FFFE, $7E7F, $005F             ;.......A....~.._
L000031A0       dc.w $FE00, $0BEF, $FD00, $0FF7, $F07F, $FCFC, $00FB, $001C             ;................
L000031B0       dc.w $018D, $FFFF, $FE00, $0DFF, $FF80, $7DFF, $FFFC, $1FFC           ;..........}.....
L000031C0       dc.w $001F, $FE00, $07FF, $FE00, $03EF, $D17D, $F0FC, $00FB             ;...........}....
L000031D0       dc.w $000A, $01B1, $8000, $01E0, $0F0C, $00C0, $06FE, $000D           ;................
L000031E0       dc.w $0183, $0000, $0100, $0C10, $0300, $0C28, $2002, $FB00           ;...........( ...
L000031F0       dc.w $FA00, $0072, $FA00, $0801, $8000, $0003, $E000, $0060             ;...r...........`
L00003200       dc.w $FB00, $030C, $1001, $80FB, $00FB, $001C, $01CF, $FFFF             ;................
L00003210       dc.w $FE00, $0CFF, $FF00, $7FFF, $FFFE, $1FFC, $001F, $FC00             ;................
L00003220       dc.w $03FF, $FC00, $03FF, $C07F, $F0FC, $00FA, $0008, $9F3F             ;...............?
L00003230       dc.w $FFFF, $8016, $FBFF, $41FD, $FF0E, $7FFE, $005F, $FC00             ;......A......_..
L00003240       dc.w $0BFF, $FD00, $07EF, $F07F, $FCFC, $00FB, $000A, $038F             ;................
L00003250       dc.w $FFFF, $FE00, $0DFD, $FF80, $7DFE, $FF0E, $1F3D, $001F             ;........}....=..
L00003260       dc.w $FC00, $07FF, $FE00, $03FB, $D1FF, $F0FC, $00FB, $001A             ;................
L00003270       dc.w $03B1, $C000, $01E0, $1F06, $00C0, $0200, $0001, $00C3             ;................
L00003280       dc.w $0000, $0300, $0C00, $0300, $0C1C, $20FA, $00FA, $0000             ;.......... .....
L00003290       dc.w $30FA, $0001, $0180, $FE00, $03E0, $0000, $60FB, $0003           ;0...........`...
L000032A0       dc.w $0C00, $0180, $FB00, $FB00, $1C03, $8FFF, $FFFE, $001C           ;................
L000032B0       dc.w $FFFF, $007F, $FFFF, $FE1F, $FC00, $1FFC, $0003, $FFFC             ;................
L000032C0       dc.w $0003, $FFC0, $7FF0, $FC00, $0200, $4020, $FD00, $200F             ;..........@ .. .
L000032D0       dc.w $3FFF, $FF40, $95FF, $FF81, $7FFF, $FFFE, $FFFE, $84FF             ;?..@............
L000032E0       dc.w $FC00, $47FF, $FE08, $03FB, $E97F, $FC00, $0020, $0484             ;..G.......... ..
L000032F0       dc.w $07CA, $271B, $1C4D, $630B, $0FFE, $FF05, $800F, $FDFF             ;..'..Mc.........
L00003300       dc.w $CC7F, $FEFF, $139F, $FD90, $1FFC, $308F, $FFFF, $0843             ;..........0....C
L00003310       dc.w $F7C3, $FFF1, $E435, $1988, $22FE, $000C, $8000, $0423             ;.....5.."......#
L00003320       dc.w $B0C0, $0000, $E017, $0200, $C0FE, $000D, $0180, $0108           ;................
L00003330       dc.w $A003, $000C, $0003, $030C, $0C10, $FE00, $0382, $2010             ;.............. .
L00003340       dc.w $00FA, $0000, $30FA, $0001, $0180, $FE00, $0360, $0000           ;....0........`..
L00003350       dc.w $40FB, $0003, $0C00, $0180, $FB00, $FE00, $0480, $0004           ;@...............
L00003360       dc.w $238F, $FEFF, $1C00, $14FF, $FF00, $7FFF, $FFFE, $1FFC             ;#...............
L00003370       dc.w $081F, $FC00, $03FF, $FC03, $03FF, $C07F, $F000, $8220             ;............... 
L00003380       dc.w $1000, $FB00, $0903, $2FDF, $FFFF, $E001, $FFFF, $80FD             ;....../.........
L00003390       dc.w $FF13, $7FFF, $807F, $FC00, $07FF, $FE00, $0BFF, $E9FF             ;................
L000033A0       dc.w $FC00, $0040, $0000, $0700, $1004, $0300, $8120, $0FFE             ;...@......... ..
L000033B0       dc.w $FF1C, $8006, $FFFF, $607F, $FFFF, $FE9F, $FF88, $9FFC             ;......`.........

L000033C0       dc.w $005B, $FFFD, $8283, $FDE1, $FFF0, $8180, $0010, $0AFD             ;.[..............
L000033D0       dc.w $000B, $0400, $0310, $2000, $00E8, $4700, $00E0, $FE00             ;...... ...G.....
L000033E0       dc.w $0D01, $8001, $8000, $0340, $1C00, $0380, $0402, $10FB             ;.......@........
L000033F0       dc.w $0000, $04FA, $0000, $30FA, $0001, $0180, $FE00, $0360             ;......0........`


batman_end:                                                                             ; end of 'BATMAN' file


