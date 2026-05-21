.data
pos_linha: .word 5
pos_col:   .word 3

# Constantes 
led_base:    .word 0xf000000c
led_width:   .word 10
kbd_data:    .word 0xf00003dc
kbd_status:  .word 0xf00003e0
kbd_state:   .word 0xf00003e4

.text
main:
    # Carrega base da matrix
    la   t0, led_base
    lw   s0, 0(t0)
    la   t0, led_width
    lw   s1, 0(t0)

    jal  ra, desenhar_L

game_loop:
    la   t0, kbd_status
    lw   t0, 0(t0)
    lw   t1, 0(t0)
    beqz t1, game_loop

    la   t0, kbd_data
    lw   t0, 0(t0)
    lw   t1, 0(t0)

    la   t0, kbd_state
    lw   t0, 0(t0)
    lw   t2, 0(t0)
    beqz t2, game_loop

    li   t2, 0x77
    beq  t1, t2, btn_cima

    li   t2, 0x73
    beq  t1, t2, btn_baixo

    li   t2, 0x61
    beq  t1, t2, btn_esquerda

    li   t2, 0x64
    beq  t1, t2, btn_direita

    j    game_loop

# ---- Movimentos ----
btn_cima:
    jal  ra, apagar_L
    la   t0, pos_linha
    lw   t1, 0(t0)
    addi t1, t1, -1
    li   t2, 0
    blt  t1, t2, _cima_sem_mover
    sw   t1, 0(t0)
_cima_sem_mover:
    jal  ra, desenhar_L
    j    game_loop

btn_baixo:
    jal  ra, apagar_L
    la   t0, pos_linha
    lw   t1, 0(t0)
    addi t1, t1, 1
    li   t2, 21                 # 24 - 3 linhas do L
    bgt  t1, t2, _baixo_sem_mover
    sw   t1, 0(t0)
_baixo_sem_mover:
    jal  ra, desenhar_L
    j    game_loop

btn_esquerda:
    jal  ra, apagar_L
    la   t0, pos_col
    lw   t1, 0(t0)
    addi t1, t1, -1
    li   t2, 0
    blt  t1, t2, _esq_sem_mover
    sw   t1, 0(t0)
_esq_sem_mover:
    jal  ra, desenhar_L
    j    game_loop

btn_direita:
    jal  ra, apagar_L
    la   t0, pos_col
    lw   t1, 0(t0)
    addi t1, t1, 1
    li   t2, 8                  # 10 - 2 colunas do L
    bgt  t1, t2, _dir_sem_mover
    sw   t1, 0(t0)
_dir_sem_mover:
    jal  ra, desenhar_L
    j    game_loop

# ============================================================
desenhar_L:
    addi sp, sp, -4
    sw   ra, 0(sp)
    li   a2, 0xFFFFFF

    lw   a0, pos_linha
    lw   a1, pos_col
    jal  ra, gravar_pixel

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 1
    jal  ra, gravar_pixel

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 2
    jal  ra, gravar_pixel

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 2
    addi a1, a1, 1
    jal  ra, gravar_pixel

    lw   ra, 0(sp)
    addi sp, sp, 4
    jalr zero, ra, 0

apagar_L:
    addi sp, sp, -4
    sw   ra, 0(sp)
    li   a2, 0x000000

    lw   a0, pos_linha
    lw   a1, pos_col
    jal  ra, gravar_pixel

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 1
    jal  ra, gravar_pixel

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 2
    jal  ra, gravar_pixel

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 2
    addi a1, a1, 1
    jal  ra, gravar_pixel

    lw   ra, 0(sp)
    addi sp, sp, 4
    jalr zero, ra, 0

# ============================================================
# gravar_pixel
# a0=linha, a1=coluna, a2=cor | s0=base, s1=largura
# ============================================================
gravar_pixel:
    mul  t3, a0, s1
    add  t3, t3, a1
    slli t3, t3, 2
    add  t4, s0, t3
    sw   a2, 0(t4)
    jalr zero, ra, 0