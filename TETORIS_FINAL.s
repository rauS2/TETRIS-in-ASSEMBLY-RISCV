# =============================================================================
# Tetris — RISC-V 32-bit para Ripes
# LED Matrix 10x20  |  Keyboard via KB_STATE (bitmask)
#
# Endereços Ripes:
#    LED_BASE   = 0xf0000000
#    KB_STATE   = 0xf0000328
# Controles:
#    A/D = Mover a peça Esquerda/Direita
#    Q/E = Girar a peça Esquerda/Direita
#    S/SPC. = Forçar a peça a cair Devagar/Rapido
#    SPC. = Quando eh Game Over, o Jogo Reseta

.equ LED_W,      10
.equ LED_H,      20

.equ KB_STATE,   0xf0000328   # bitmask teclas pressionadas agora

# Bits do KB_STATE
.equ BIT_W,     0x01   # bit0
.equ BIT_A,     0x02   # bit1
.equ BIT_S,     0x04   # bit2
.equ BIT_D,     0x08   # bit3
.equ BIT_Q,     0x10   # bit4
.equ BIT_E,     0x20   # bit5
.equ BIT_SPACE, 0x40   # bit6
.equ BIT_R,     0x40000000   # bit30

.equ GRAV_START,  3000
.equ GRAV_MIN,     300
.equ GRAV_STEP,    150
.equ INPUT_LOCK,  1000

# --- Paleta de Cores (0x00RRGGBB) ---
.equ COR_FUNDO,     0x00000000
.equ COR_I,         0x0000FFFF
.equ COR_O,         0x00FFFF00
.equ COR_T,         0x00800080
.equ COR_S,         0x0000FF00
.equ COR_Z,         0x00FF0000
.equ COR_J,         0x000000FF
.equ COR_L,         0x00FFA500

# =============================================================================
.data

board:
.zero 800   # board[20][10] — 0=vazio, !=0=cor

# Offsets relativos (em bytes) dos 4 blocos de cada tetromino a partir de (X, Y)
piece_data:
# --- I ---
.word  0,0,  0,1,  0,2,  0,3
.word  0,0,  1,0,  2,0,  3,0
.word  0,0,  0,1,  0,2,  0,3
.word  0,0,  1,0,  2,0,  3,0
# --- O ---
.word  0,0,  0,1,  1,0,  1,1
.word  0,0,  0,1,  1,0,  1,1
.word  0,0,  0,1,  1,0,  1,1
.word  0,0,  0,1,  1,0,  1,1
# --- T ---
.word  0,0,  0,1,  0,2,  1,1
.word  0,0,  1,0,  2,0,  1,1
.word  1,0,  1,1,  1,2,  0,1
.word  0,1,  1,1,  2,1,  1,0
# --- S ---
.word  0,1,  0,2,  1,0,  1,1
.word  0,0,  1,0,  1,1,  2,1
.word  0,1,  0,2,  1,0,  1,1
.word  0,0,  1,0,  1,1,  2,1
# --- Z ---
.word  0,0,  0,1,  1,1,  1,2
.word  0,1,  1,0,  1,1,  2,0
.word  0,0,  0,1,  1,1,  1,2
.word  0,1,  1,0,  1,1,  2,0
# --- J ---
.word  0,0,  1,0,  1,1,  1,2
.word  0,0,  0,1,  1,0,  2,0
.word  0,0,  0,1,  0,2,  1,2
.word  0,1,  1,1,  2,0,  2,1
# --- L ---
.word  0,2,  1,0,  1,1,  1,2
.word  0,0,  1,0,  2,0,  2,1
.word  0,0,  0,1,  0,2,  1,0
.word  0,0,  0,1,  1,1,  2,1

# Mapeamento de cores correspondente aos índices de piece_data
CORES:
.word COR_I   # I  ciano
.word COR_O   # O  amarelo
.word COR_T   # T  roxo
.word COR_S   # S  verde
.word COR_Z   # Z  vermelho
.word COR_J   # J  azul
.word COR_L   # L  laranja

.text
.globl main

main:
    li   sp, 0x00080000
    li   s4, 7919            # semente RNG
    li   s5, GRAV_START      # contador de gravidade
    li   s6, 0               # input_lock
    li   s10, GRAV_START     # grav_speed = delay atual

    la   t0, board
    li   t1, 200
_zb:
    beqz t1, _zb_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    j    _zb
_zb_done:

    call limpa_tela
    call rng
    call nova_peca
    call desenha

# Polling loop e handler de input
game_loop:

    beqz s6, _lock_zero
    addi s6, s6, -1
_lock_zero:

    bnez s6, check_gravity

    li   t0, KB_STATE
    lw   t1, 0(t0)
    beqz t1, check_gravity

    li   t0, BIT_R
    and  t2, t1, t0
    bnez t2, main

    li   t0, BIT_SPACE
    and  t2, t1, t0
    bnez t2, acao_hard

    li   t0, BIT_Q
    and  t2, t1, t0
    bnez t2, acao_rot_ccw

    li   t0, BIT_E
    and  t2, t1, t0
    bnez t2, acao_rot_cw

    li   t0, BIT_W
    and  t2, t1, t0
    bnez t2, acao_rot_cw

    li   t0, BIT_A
    and  t2, t1, t0
    bnez t2, acao_esq

    li   t0, BIT_D
    and  t2, t1, t0
    bnez t2, acao_dir

    li   t0, BIT_S
    and  t2, t1, t0
    bnez t2, acao_soft

check_gravity:
    addi s5, s5, -1
    bnez s5, game_loop

    mv   s5, s10

    call apaga
    addi s1, s1, 1
    call colisao
    beqz a0, _grav_ok
    addi s1, s1, -1
    call fixa
    j    game_loop
_grav_ok:
    call desenha
    j    game_loop

acao_esq:
    li   s6, INPUT_LOCK
    call apaga
    addi s0, s0, -1
    call colisao
    beqz a0, _esq_ok
    addi s0, s0, 1
_esq_ok:
    call desenha
    j    game_loop

acao_dir:
    li   s6, INPUT_LOCK
    call apaga
    addi s0, s0, 1
    call colisao
    beqz a0, _dir_ok
    addi s0, s0, -1
_dir_ok:
    call desenha
    j    game_loop

acao_rot_cw:
    li   s6, INPUT_LOCK
    call apaga
    addi s3, s3, 1
    andi s3, s3, 3
    call colisao
    beqz a0, _rotcw_ok
    addi s3, s3, -1
    andi s3, s3, 3
_rotcw_ok:
    call desenha
    j    game_loop

acao_rot_ccw:
    li   s6, INPUT_LOCK
    call apaga
    addi s3, s3, -1
    andi s3, s3, 3
    call colisao
    beqz a0, _rotccw_ok
    addi s3, s3, 1
    andi s3, s3, 3
_rotccw_ok:
    call desenha
    j    game_loop

acao_hard:
    li   s6, INPUT_LOCK
    call apaga
_hd_loop:
    addi s1, s1, 1
    call colisao
    beqz a0, _hd_loop
    addi s1, s1, -1
    call fixa
    j    game_loop

acao_soft:
    li   s6, INPUT_LOCK
    call apaga
    addi s1, s1, 1
    call colisao
    beqz a0, _sft_ok
    addi s1, s1, -1
    call fixa
    j    game_loop
_sft_ok:
    call desenha
    j    game_loop

fixa:
    addi sp, sp, -16
    sw   ra,  0(sp)
    sw   s7,  4(sp)
    sw   s8,  8(sp)
    sw   s9, 12(sp)

    la   t0, CORES
    slli t1, s2, 2
    add  t0, t0, t1
    lw   s7, 0(t0)

    call offs_peca
    mv   s9, a0
    li   s8, 4

_fix_lp:
    beqz s8, _fix_done
    lw   t0, 0(s9)
    lw   t1, 4(s9)
    addi s9, s9, 8
    add  a0, s1, t0
    add  a1, s0, t1

    bltz a0, _fix_skip
    li   t2, LED_H
    bge  a0, t2, _fix_skip
    bltz a1, _fix_skip
    li   t2, LED_W
    bge  a1, t2, _fix_skip

    li   t2, LED_W
    mul  t3, a0, t2
    add  t3, t3, a1
    slli t3, t3, 2
    la   t2, board
    add  t2, t2, t3
    sw   s7, 0(t2)

    mv   a2, s7
    jal  ra, gravar_pixel
_fix_skip:
    addi s8, s8, -1
    j    _fix_lp

_fix_done:
    call checa_linhas
    call rng
    call nova_peca
    call desenha

    lw   s7,  4(sp)
    lw   s8,  8(sp)
    lw   s9, 12(sp)
    lw   ra,  0(sp)
    addi sp, sp, 16
    ret

nova_peca:
    addi sp, sp, -4
    sw   ra, 0(sp)

    srli t0, s4, 16
    andi t0, t0, 7
    li   t1, 7
    blt  t0, t1, _np_ok
    li   t0, 0
_np_ok:
    mv   s2, t0
    li   s0, 3
    li   s1, 0
    li   s3, 0
    mv   s5, s10

    call colisao
    beqz a0, _nova_ok

    # ── GAME OVER ──
    # Pinta a tela de vermelho
    li   a0, 0
_go_r:
    li   t0, LED_H
    bge  a0, t0, _go_halt
    li   a1, 0
_go_c:
    li   t0, LED_W
    bge  a1, t0, _go_nr
    li   a2, 0xFF0000
    jal  ra, gravar_pixel
    addi a1, a1, 1
    j    _go_c
_go_nr:
    addi a0, a0, 1
    j    _go_r

    # Drena SPACE caso já esteja pressionado antes do game over
_go_halt:
    li   t0, KB_STATE
    lw   t1, 0(t0)
    li   t0, BIT_SPACE
    and  t2, t1, t0
    bnez t2, _go_halt      # SPACE ainda pressionado → espera soltar

    # Agora aguarda o jogador pressionar SPACE para reiniciar
_go_wait_r:
    li   t0, KB_STATE
    lw   t1, 0(t0)
    li   t0, BIT_SPACE
    and  t2, t1, t0
    beqz t2, _go_wait_r    # SPACE ainda solto → continua esperando

    j    main              # SPACE pressionado → reinicia o jogo

_nova_ok:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

rng:
    lui  t0, 0x6C07
    addi t0, t0, 0x65
    mul  s4, s4, t0
    addi s4, s4, 1
    ret

colisao:
    addi sp, sp, -4
    sw   ra, 0(sp)

    call offs_peca
    mv   t5, a0
    li   t4, 4
    li   a0, 0

_col_lp:
    beqz t4, _col_done
    lw   t0, 0(t5)
    lw   t1, 4(t5)
    addi t5, t5, 8
    add  t2, s1, t0
    add  t3, s0, t1

    li   t6, LED_H
    bge  t2, t6, _col_hit
    bltz t3, _col_hit
    li   t6, LED_W
    bge  t3, t6, _col_hit
    bltz t2, _col_skip

    li   t6, LED_W
    mul  t6, t2, t6
    add  t6, t6, t3
    slli t6, t6, 2
    la   a0, board
    add  a0, a0, t6
    lw   a0, 0(a0)
    bnez a0, _col_hit2
    li   a0, 0

_col_skip:
    addi t4, t4, -1
    j    _col_lp
_col_hit:
    li   a0, 1
    j    _col_done
_col_hit2:
    li   a0, 1
_col_done:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

checa_linhas:
    addi sp, sp, -8
    sw   ra,  0(sp)
    sw   s11, 4(sp)

    li   s11, LED_H
    addi s11, s11, -1

_cl_lp:
    bltz s11, _cl_done

    li   t4, 0
    li   t3, 0
_cl_cnt:
    li   t0, LED_W
    bge  t3, t0, _cl_check
    mul  t1, s11, t0
    add  t1, t1, t3
    slli t1, t1, 2
    la   t2, board
    add  t2, t2, t1
    lw   t0, 0(t2)
    beqz t0, _cl_nc
    addi t4, t4, 1
_cl_nc:
    addi t3, t3, 1
    j    _cl_cnt

_cl_check:
    li   t0, LED_W
    blt  t4, t0, _cl_prox

    li   t0, GRAV_STEP
    sub  s10, s10, t0
    li   t0, GRAV_MIN
    bge  s10, t0, _cl_noclamp
    mv   s10, t0
_cl_noclamp:

    mv   t6, s11
_cl_shift:
    beqz t6, _cl_zero
    addi t6, t6, -1

    li   t0, LED_W
    mul  t1, t6, t0
    slli t1, t1, 2
    la   t2, board
    add  t2, t2, t1

    addi a3, t6, 1
    mul  t1, a3, t0
    slli t1, t1, 2
    la   t3, board
    add  t3, t3, t1

    li   t1, 0
_cl_cp:
    li   t0, LED_W
    bge  t1, t0, _cl_shift
    lw   t0, 0(t2)
    sw   t0, 0(t3)
    addi t2, t2, 4
    addi t3, t3, 4
    addi t1, t1, 1
    j    _cl_cp

_cl_zero:
    la   t2, board
    li   t1, 0
_cl_zt:
    li   t0, LED_W
    bge  t1, t0, _cl_redesenha
    sw   zero, 0(t2)
    addi t2, t2, 4
    addi t1, t1, 1
    j    _cl_zt

_cl_redesenha:
    call redesenha
    j    _cl_lp

_cl_prox:
    addi s11, s11, -1
    j    _cl_lp

_cl_done:
    lw   s11, 4(sp)
    lw   ra,  0(sp)
    addi sp, sp, 8
    ret

redesenha:
    addi sp, sp, -4
    sw   ra, 0(sp)

    li   a0, 0
_rd_l:
    li   t0, LED_H
    bge  a0, t0, _rd_done
    li   a1, 0
_rd_c:
    li   t0, LED_W
    bge  a1, t0, _rd_next
    li   t2, LED_W
    mul  t3, a0, t2
    add  t3, t3, a1
    slli t3, t3, 2
    la   t4, board
    add  t4, t4, t3
    lw   a2, 0(t4)
    jal  ra, gravar_pixel
    addi a1, a1, 1
    j    _rd_c
_rd_next:
    addi a0, a0, 1
    j    _rd_l
_rd_done:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

# Renderiza os 4 blocos da peça atual
# Args: s2=tipo, s3=rot, s0=col, s1=linha
desenha:
    addi sp, sp, -16
    sw   ra,  0(sp)
    sw   s7,  4(sp)
    sw   s8,  8(sp)
    sw   s9, 12(sp)

    la   t0, CORES
    slli t1, s2, 2
    add  t0, t0, t1
    lw   s7, 0(t0)

    call offs_peca
    mv   s9, a0
    li   s8, 4

_dp_lp:
    beqz s8, _dp_done
    lw   t0, 0(s9)
    lw   t1, 4(s9)
    addi s9, s9, 8
    add  a0, s1, t0
    add  a1, s0, t1
    bltz a0, _dp_skip
    li   t2, LED_H
    bge  a0, t2, _dp_skip
    bltz a1, _dp_skip
    li   t2, LED_W
    bge  a1, t2, _dp_skip
    mv   a2, s7
    jal  ra, gravar_pixel
_dp_skip:
    addi s8, s8, -1
    j    _dp_lp
_dp_done:
    lw   ra,  0(sp)
    lw   s7,  4(sp)
    lw   s8,  8(sp)
    lw   s9, 12(sp)
    addi sp, sp, 16
    ret

apaga:
    addi sp, sp, -12
    sw   ra,  0(sp)
    sw   s8,  4(sp)
    sw   s9,  8(sp)

    call offs_peca
    mv   s9, a0
    li   s8, 4

_ep_lp:
    beqz s8, _ep_done
    lw   t0, 0(s9)
    lw   t1, 4(s9)
    addi s9, s9, 8
    add  a0, s1, t0
    add  a1, s0, t1
    bltz a0, _ep_skip
    li   t2, LED_H
    bge  a0, t2, _ep_skip
    bltz a1, _ep_skip
    li   t2, LED_W
    bge  a1, t2, _ep_skip
    li   a2, COR_FUNDO
    jal  ra, gravar_pixel
_ep_skip:
    addi s8, s8, -1
    j    _ep_lp
_ep_done:
    lw   ra,  0(sp)
    lw   s8,  4(sp)
    lw   s9,  8(sp)
    addi sp, sp, 12
    ret

offs_peca:
    slli t0, s2, 2
    add  t0, t0, s3
    slli t0, t0, 5
    la   a0, piece_data
    add  a0, a0, t0
    ret

# gravar_pixel
# a0=linha, a1=coluna, a2=cor | s0=base, s1=largura
gravar_pixel:
    li   t2, LED_W
    mul  t3, a0, t2
    add  t3, t3, a1
    slli t3, t3, 2
    li   t4, 0xf0000000
    add  t4, t4, t3
    sw   a2, 0(t4)
    jalr zero, ra, 0

limpa_tela:
    li   t0, 0xf0000000
    li   t1, 200
_lt_lp:
    beqz t1, _lt_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    j    _lt_lp
_lt_done:
    ret