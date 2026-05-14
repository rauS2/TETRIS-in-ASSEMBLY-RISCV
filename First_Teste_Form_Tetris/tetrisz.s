.data
pos_linha:  .word 5
pos_col:    .word 3

.text
main:
    # s0 = base LED Matrix
    li   s0, 0xf0000010
    # s1 = cols (10)
    li   s1, 10

    jal  ra, desenhar_L

game_loop:
    # Lê cada direção separadamente
    li   t0, 0xf0000000
    lw   t1, 0(t0)       # UP
    bnez t1, btn_cima

    lw   t1, 4(t0)       # DOWN
    bnez t1, btn_baixo

    lw   t1, 8(t0)       # LEFT
    bnez t1, btn_esquerda

    lw   t1, 12(t0)      # RIGHT
    bnez t1, btn_direita

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
    li   t2, 17          # 20 linhas - 3 pixels de altura do L
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
    li   t2, 8           # 10 colunas - 2 pixels de largura do L
    bgt  t1, t2, _dir_sem_mover
    sw   t1, 0(t0)
_dir_sem_mover:
    jal  ra, desenhar_L
    j    game_loop

# ============================================================
# desenhar_L e apagar_L usam pilha para preservar ra
# ============================================================
desenhar_L:
    addi sp, sp, -4
    sw   ra, 0(sp)

    li   t0, 0xFFFFFF

    lw   a0, pos_linha
    lw   a1, pos_col
    jal  ra, gravar_pixel       # topo vertical

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 1
    jal  ra, gravar_pixel       # meio vertical

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 2
    jal  ra, gravar_pixel       # base vertical (canto do L)

    lw   a0, pos_linha
    lw   a1, pos_col
    addi a0, a0, 2
    addi a1, a1, 1
    jal  ra, gravar_pixel       # base horizontal

    lw   ra, 0(sp)
    addi sp, sp, 4
    jalr zero, ra, 0

apagar_L:
    addi sp, sp, -4
    sw   ra, 0(sp)

    li   t0, 0x000000

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
# Entradas: a0 = linha, a1 = coluna, t0 = cor (RGB 24-bit)
# s0 = base LED Matrix, s1 = cols
# ============================================================
gravar_pixel:
    mul  t3, a0, s1      # linha * 10
    add  t3, t3, a1      # + coluna
    slli t3, t3, 2       # * 4 bytes
    add  t4, s0, t3      # endereço final
    sw   t0, 0(t4)       # escreve cor
    jalr zero, ra, 0