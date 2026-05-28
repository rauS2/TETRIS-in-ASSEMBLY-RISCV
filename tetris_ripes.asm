# =============================================================================
# TETRIS para Ripes - RISC-V Assembly
# =============================================================================
# Periféricos:
#   LED_MATRIX : base 0xF000000C, 10 col x 20 lin
#                pixel[row][col] = MEM[base + (row*10 + col)*4]  (RGB 32-bit)
#   KEYBOARD   : KEY_DATA   0xF0000000  (código da tecla)
#                KEY_STATUS 0xF0000004  (1 = nova tecla disponível)
#                KEY_STATE  0xF0000008  (1 = pressionada / 0 = solta)
#
# Controles: A=esq, D=dir, S=desce, W=rotaciona, SPACE=drop
# =============================================================================

.equ LED_BASE,    0xF000000C
.equ KBD_DATA,    0xF0000000
.equ KBD_STATUS,  0xF0000004
.equ KBD_STATE,   0xF0000008
.equ BW,          10
.equ BH,          20

# Cores RGB
.equ C_EMPTY,  0x000000
.equ C_CYAN,   0x00FFFF
.equ C_YELLOW, 0xFFFF00
.equ C_PURPLE, 0x9900CC
.equ C_GREEN,  0x00FF00
.equ C_RED,    0xFF0000
.equ C_BLUE,   0x0044FF
.equ C_ORANGE, 0xFF8800
.equ C_GHOST,  0x303030

# Scancodes ASCII
.equ K_A,     0x61
.equ K_D,     0x64
.equ K_S,     0x73
.equ K_W,     0x77
.equ K_SPC,   0x20

# =============================================================================
.data

# Tabuleiro: 20*10 = 200 int32 (0=vazio, caso contrário = cor RGB)
board: .space 800

# Peça ativa: 4 blocos, cada um com (col, row)
px: .word 0,0,0,0   # colunas dos 4 blocos
py: .word 0,0,0,0   # linhas dos 4 blocos

# Peça fantasma (shadow drop)
gx: .word 0,0,0,0
gy: .word 0,0,0,0

cur_type:  .word 0   # tipo atual  (0-6)
cur_rot:   .word 0   # rotação     (0-3)
cur_color: .word 0   # cor atual
next_type: .word 0   # próxima peça
score:     .word 0
level:     .word 1
game_over: .word 0
tick:      .word 0
speed:     .word 25  # ticks até cair
seed:      .word 6789

# ---------------------------------------------------------
# Tabela de formas: 7 peças * 4 rotações * 4 blocos * 2 ints (dc,dr)
# = 7*4*8 = 224 words
# Cada rotação tem 8 words: dc0,dr0, dc1,dr1, dc2,dr2, dc3,dr3
# ---------------------------------------------------------
shapes:
# 0: I (CIANO)
  .word -1,0,  0,0,  1,0,  2,0    # rot0
  .word  0,-2, 0,-1, 0,0,  0,1    # rot1
  .word -1,0,  0,0,  1,0,  2,0    # rot2
  .word  0,-2, 0,-1, 0,0,  0,1    # rot3
# 1: O (AMARELO)
  .word  0,0,  1,0,  0,1,  1,1
  .word  0,0,  1,0,  0,1,  1,1
  .word  0,0,  1,0,  0,1,  1,1
  .word  0,0,  1,0,  0,1,  1,1
# 2: T (ROXO)
  .word  0,0, -1,0,  1,0,  0,1
  .word  0,0,  0,-1, 0,1,  1,0
  .word  0,0, -1,0,  1,0,  0,-1
  .word  0,0,  0,-1, 0,1, -1,0
# 3: S (VERDE)
  .word  0,0,  1,0, -1,1,  0,1
  .word  0,0,  0,1,  1,0,  1,-1
  .word  0,0,  1,0, -1,1,  0,1
  .word  0,0,  0,1,  1,0,  1,-1
# 4: Z (VERMELHO)
  .word -1,0,  0,0,  0,1,  1,1
  .word  1,0,  0,1,  1,-1, 0,0
  .word -1,0,  0,0,  0,1,  1,1
  .word  1,0,  0,1,  1,-1, 0,0
# 5: J (AZUL)
  .word -1,0,  0,0,  1,0, -1,1
  .word  0,-1, 0,0,  0,1,  1,1
  .word -1,0,  0,0,  1,0,  1,-1
  .word -1,-1, 0,-1, 0,0,  0,1
# 6: L (LARANJA)
  .word -1,0,  0,0,  1,0,  1,1
  .word  0,-1, 0,0,  0,1, -1,1
  .word -1,0,  0,0,  1,0, -1,-1
  .word  1,-1, 0,-1, 0,0,  0,1

colors:
  .word C_CYAN, C_YELLOW, C_PURPLE, C_GREEN, C_RED, C_BLUE, C_ORANGE

# Coluna inicial de spawn (centro) para cada peça
spawn_col:
  .word 4, 4, 4, 4, 4, 4, 4

# =============================================================================
.text
.globl _start

# Registradores salvos globalmente como convenção desta implementação:
# s0-s11 usados livremente dentro de funções longas; ra sempre salvo/restaurado.

_start:
    li   sp, 0x00080000
    call clear_board
    call rand7
    sw   a0, next_type, t0
    call do_spawn
    # Loop principal
.Lmain:
    lw   t0, game_over
    bnez t0, .Lgameover
    call read_kbd
    lw   t0, tick
    addi t0, t0, 1
    sw   t0, tick, t1
    lw   t1, speed
    blt  t0, t1, .Lno_fall
    sw   zero, tick, t1
    call try_fall
.Lno_fall:
    call draw_all
    call busy_wait
    j    .Lmain
.Lgameover:
    call flash_red
    j    .Lgameover

# =============================================================================
# UTILITÁRIOS DE MEMÓRIA MAPEADA
# =============================================================================

# set_pixel(a0=col, a1=row, a2=color)
set_pixel:
    li   t0, BW
    mul  t1, a1, t0
    add  t1, t1, a0
    slli t1, t1, 2
    li   t0, LED_BASE
    add  t0, t0, t1
    sw   a2, 0(t0)
    ret

# board_get(a0=col, a1=row) -> a0=value
board_get:
    li   t0, BW
    mul  t1, a1, t0
    add  t1, t1, a0
    slli t1, t1, 2
    la   t0, board
    add  t0, t0, t1
    lw   a0, 0(t0)
    ret

# board_set(a0=col, a1=row, a2=value)
board_set:
    li   t0, BW
    mul  t1, a1, t0
    add  t1, t1, a0
    slli t1, t1, 2
    la   t0, board
    add  t0, t0, t1
    sw   a2, 0(t0)
    ret

# =============================================================================
# clear_board
# =============================================================================
clear_board:
    la   t0, board
    li   t1, 200
.Lcb:
    sw   zero, 0(t0)
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, .Lcb
    ret

# =============================================================================
# rand7: gera número aleatório 0-6 em a0 (LCG)
# =============================================================================
rand7:
    la   t0, seed
    lw   t1, 0(t0)
    li   t2, 1664525
    mul  t1, t1, t2
    li   t2, 1013904223
    add  t1, t1, t2
    sw   t1, 0(t0)
    li   t2, 7
    remu a0, t1, t2
    ret

# =============================================================================
# load_cells: carrega piece_x/piece_y com a rotação atual do tipo atual
# usa: cur_type, cur_rot; escreve em px[], py[]
# a3=col_origem, a4=row_origem
# =============================================================================
load_cells:
    la   t0, cur_type
    lw   t0, 0(t0)          # tipo
    li   t1, 4*8*4          # bytes por peça (4 rot * 8 words * 4)
    mul  t1, t0, t1
    la   t0, shapes
    add  t0, t0, t1         # base da peça

    la   t1, cur_rot
    lw   t1, 0(t1)
    li   t2, 8*4            # bytes por rotação
    mul  t2, t1, t2
    add  t0, t0, t2         # ponteiro para os 8 words desta rotação

    la   t3, px
    la   t4, py
    li   t5, 0
.Llc:
    li   t6, 4
    bge  t5, t6, .Llc_done
    lw   a5, 0(t0)          # dc
    lw   a6, 4(t0)          # dr
    add  a5, a5, a3
    add  a6, a6, a4
    slli t1, t5, 2
    add  t2, t3, t1
    sw   a5, 0(t2)
    add  t2, t4, t1
    sw   a6, 0(t2)
    addi t0, t0, 8
    addi t5, t5, 1
    j    .Llc
.Llc_done:
    ret

# =============================================================================
# collision: verifica colisão das células em px[]/py[] com paredes/board
# retorna a0=1 colisão, a0=0 livre
# Ignora y<0 (blocos acima do topo são permitidos durante spawn)
# =============================================================================
collision:
    la   t0, px
    la   t1, py
    li   t2, 0
.Lcol:
    li   t3, 4
    bge  t2, t3, .Lcol_ok
    slli t4, t2, 2
    add  t5, t0, t4; lw t5, 0(t5)   # col
    add  t6, t1, t4; lw t6, 0(t6)   # row
    bltz t5, .Lcol_hit
    li   a5, BW; bge t5, a5, .Lcol_hit
    li   a5, BH; bge t6, a5, .Lcol_hit
    bltz t6, .Lcol_next          # acima do topo: ok
    # Verificar board
    li   a5, BW
    mul  a6, t6, a5
    add  a6, a6, t5
    slli a6, a6, 2
    la   a5, board; add a5, a5, a6; lw a5, 0(a5)
    bnez a5, .Lcol_hit
.Lcol_next:
    addi t2, t2, 1
    j    .Lcol
.Lcol_ok:
    li   a0, 0; ret
.Lcol_hit:
    li   a0, 1; ret

# =============================================================================
# do_spawn: coloca a próxima peça como atual e gera nova "next"
# =============================================================================
do_spawn:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   t0, next_type; lw t1, 0(t0)
    la   t0, cur_type;  sw t1, 0(t0)

    call rand7
    la   t0, next_type; sw a0, 0(t0)

    # Cor
    la   t0, cur_type; lw t1, 0(t0)
    la   t0, colors; slli t2, t1, 2; add t0, t0, t2; lw t2, 0(t0)
    la   t0, cur_color; sw t2, 0(t0)

    # Reset rotação
    la   t0, cur_rot; sw zero, 0(t0)

    # Posição inicial
    la   t0, cur_type; lw t1, 0(t0)
    la   t0, spawn_col; slli t2, t1, 2; add t0, t0, t2; lw a3, 0(t0)
    li   a4, 1          # row inicial

    call load_cells

    # Game over se colidir ao spawnar
    call collision
    beqz a0, .Lspawn_ok
    la   t0, game_over; li t1, 1; sw t1, 0(t0)
.Lspawn_ok:
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# try_fall: move a peça para baixo; se não puder, fixa e spawna nova
# =============================================================================
try_fall:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   t0, py
    li   t1, 0
.Ltf_sh:
    li   t2, 4; bge t1, t2, .Ltf_chk
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, 1; sw t5, 0(t4)
    addi t1, t1, 1; j .Ltf_sh
.Ltf_chk:
    call collision
    beqz a0, .Ltf_ok

    # Reverter
    la   t0, py; li t1, 0
.Ltf_rev:
    li   t2, 4; bge t1, t2, .Ltf_lock
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, -1; sw t5, 0(t4)
    addi t1, t1, 1; j .Ltf_rev
.Ltf_lock:
    call lock_piece
    call check_lines
    call do_spawn
.Ltf_ok:
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# lock_piece: escreve peça atual no tabuleiro
# =============================================================================
lock_piece:
    la   t0, px; la t1, py
    la   t2, cur_color; lw t2, 0(t2)
    li   t3, 0
.Llp:
    li   t4, 4; bge t3, t4, .Llp_done
    slli t5, t3, 2
    add  t6, t0, t5; lw t6, 0(t6)   # col
    add  a5, t1, t5; lw a5, 0(a5)   # row
    bltz a5, .Llp_next
    mv   a0, t6; mv a1, a5; mv a2, t2
    call board_set
.Llp_next:
    addi t3, t3, 1; j .Llp
.Llp_done:
    ret

# =============================================================================
# check_lines: verifica e limpa linhas completas
# =============================================================================
check_lines:
    addi sp, sp, -4
    sw   ra, 0(sp)

    li   s0, BH-1           # linha atual (de baixo para cima)
.Lcl_outer:
    bltz s0, .Lcl_upd

    # Contar células preenchidas na linha s0
    li   t1, 0              # coluna
    li   t2, 1              # cheio
.Lcl_inner:
    li   t3, BW; bge t1, t3, .Lcl_chk
    mv   a0, t1; mv a1, s0
    call board_get
    bnez a0, .Lcl_in_next
    li   t2, 0              # encontrou vazio
.Lcl_in_next:
    addi t1, t1, 1; j .Lcl_inner
.Lcl_chk:
    beqz t2, .Lcl_not_full

    # Linha cheia: deslocar tudo acima para baixo
    mv   t3, s0             # linha destino
.Lcl_shift:
    beqz t3, .Lcl_zero_top
    addi t4, t3, -1         # linha fonte
    li   t5, 0
.Lcl_cpy:
    li   t6, BW; bge t5, t6, .Lcl_shift_next
    mv   a0, t5; mv a1, t4
    call board_get
    mv   a2, a0
    mv   a0, t5
    # a1 = row destino = t3
    mv   a5, t3
    mv   a1, a5
    call board_set
    addi t5, t5, 1; j .Lcl_cpy
.Lcl_shift_next:
    addi t3, t3, -1; j .Lcl_shift
.Lcl_zero_top:
    li   t5, 0
.Lcl_zt:
    li   t6, BW; bge t5, t6, .Lcl_outer  # não decrementar s0
    mv   a0, t5; li a1, 0; li a2, 0
    call board_set
    addi t5, t5, 1; j .Lcl_zt

.Lcl_not_full:
    addi s0, s0, -1; j .Lcl_outer

.Lcl_upd:
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# move_left / move_right
# =============================================================================
move_left:
    addi sp, sp, -4; sw ra, 0(sp)
    la   t0, px; li t1, 0
.Tml_sh:
    li   t2, 4; bge t1, t2, .Tml_chk
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, -1; sw t5, 0(t4)
    addi t1, t1, 1; j .Tml_sh
.Tml_chk:
    call collision; beqz a0, .Tml_ok
    la   t0, px; li t1, 0
.Tml_rev:
    li   t2, 4; bge t1, t2, .Tml_ok
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, 1; sw t5, 0(t4)
    addi t1, t1, 1; j .Tml_rev
.Tml_ok:
    lw   ra, 0(sp); addi sp, sp, 4; ret

move_right:
    addi sp, sp, -4; sw ra, 0(sp)
    la   t0, px; li t1, 0
.Tmr_sh:
    li   t2, 4; bge t1, t2, .Tmr_chk
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, 1; sw t5, 0(t4)
    addi t1, t1, 1; j .Tmr_sh
.Tmr_chk:
    call collision; beqz a0, .Tmr_ok
    la   t0, px; li t1, 0
.Tmr_rev:
    li   t2, 4; bge t1, t2, .Tmr_ok
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, -1; sw t5, 0(t4)
    addi t1, t1, 1; j .Tmr_rev
.Tmr_ok:
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# rotate_piece: tenta rodar; aplica wall-kick ±1 col se necessário
# =============================================================================
rotate_piece:
    addi sp, sp, -40; sw ra, 0(sp)
    # Salvar estado atual
    la   t0, px
    lw   t1, 0(t0);  sw t1,  4(sp)
    lw   t1, 4(t0);  sw t1,  8(sp)
    lw   t1, 8(t0);  sw t1, 12(sp)
    lw   t1, 12(t0); sw t1, 16(sp)
    la   t0, py
    lw   t1, 0(t0);  sw t1, 20(sp)
    lw   t1, 4(t0);  sw t1, 24(sp)
    lw   t1, 8(t0);  sw t1, 28(sp)
    lw   t1, 12(t0); sw t1, 32(sp)
    la   t0, cur_rot; lw t1, 0(t0); sw t1, 36(sp)

    # Calcular centro como col/row médios
    la   t0, px
    lw   t1, 0(t0); lw t2, 4(t0); lw t3, 8(t0); lw t4, 12(t0)
    add  t1, t1, t2; add t1, t1, t3; add t1, t1, t4
    li   t2, 4; div a3, t1, t2

    la   t0, py
    lw   t1, 0(t0); lw t2, 4(t0); lw t3, 8(t0); lw t4, 12(t0)
    add  t1, t1, t2; add t1, t1, t3; add t1, t1, t4
    li   t2, 4; div a4, t1, t2

    # Incrementar rotação
    la   t0, cur_rot; lw t1, 0(t0); addi t1, t1, 1; li t2, 4; remu t1, t1, t2; sw t1, 0(t0)

    call load_cells
    call collision; beqz a0, .Lrp_ok

    # Wall kick +1
    la   t0, px; li t1, 0
.Lrp_k1:
    li   t2, 4; bge t1, t2, .Lrp_k1c
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, 1; sw t5, 0(t4)
    addi t1, t1, 1; j .Lrp_k1
.Lrp_k1c:
    call collision; beqz a0, .Lrp_ok

    # Wall kick -2 (volta ao original)
    la   t0, px; li t1, 0
.Lrp_k2:
    li   t2, 4; bge t1, t2, .Lrp_k2c
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, -2; sw t5, 0(t4)
    addi t1, t1, 1; j .Lrp_k2
.Lrp_k2c:
    call collision; beqz a0, .Lrp_ok

    # Reverter tudo
    la   t0, cur_rot; lw t1, 36(sp); sw t1, 0(t0)
    la   t0, px
    lw   t1,  4(sp); sw t1, 0(t0)
    lw   t1,  8(sp); sw t1, 4(t0)
    lw   t1, 12(sp); sw t1, 8(t0)
    lw   t1, 16(sp); sw t1, 12(t0)
    la   t0, py
    lw   t1, 20(sp); sw t1, 0(t0)
    lw   t1, 24(sp); sw t1, 4(t0)
    lw   t1, 28(sp); sw t1, 8(t0)
    lw   t1, 32(sp); sw t1, 12(t0)
.Lrp_ok:
    lw   ra, 0(sp); addi sp, sp, 40; ret

# =============================================================================
# hard_drop: drop instantâneo
# =============================================================================
hard_drop:
    addi sp, sp, -4; sw ra, 0(sp)
.Lhd_loop:
    la   t0, py; li t1, 0
.Lhd_sh:
    li   t2, 4; bge t1, t2, .Lhd_chk
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, 1; sw t5, 0(t4)
    addi t1, t1, 1; j .Lhd_sh
.Lhd_chk:
    call collision; beqz a0, .Lhd_loop

    la   t0, py; li t1, 0
.Lhd_rev:
    li   t2, 4; bge t1, t2, .Lhd_fix
    slli t3, t1, 2; add t4, t0, t3; lw t5, 0(t4); addi t5, t5, -1; sw t5, 0(t4)
    addi t1, t1, 1; j .Lhd_rev
.Lhd_fix:
    call lock_piece
    call check_lines
    call do_spawn
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# read_kbd: lê tecla e executa ação
# =============================================================================
read_kbd:
    addi sp, sp, -4; sw ra, 0(sp)
    li   t0, KBD_STATUS; lw t1, 0(t0); beqz t1, .Lrk_done
    li   t0, KBD_STATE;  lw t1, 0(t0); beqz t1, .Lrk_done
    li   t0, KBD_DATA;   lw t0, 0(t0)
    li   t1, K_A;   beq t0, t1, .Lrk_left
    li   t1, K_D;   beq t0, t1, .Lrk_right
    li   t1, K_S;   beq t0, t1, .Lrk_down
    li   t1, K_W;   beq t0, t1, .Lrk_rot
    li   t1, K_SPC; beq t0, t1, .Lrk_drop
    j    .Lrk_done
.Lrk_left:  call move_left;     j .Lrk_done
.Lrk_right: call move_right;    j .Lrk_done
.Lrk_down:  call try_fall;      j .Lrk_done
.Lrk_rot:   call rotate_piece;  j .Lrk_done
.Lrk_drop:  call hard_drop
.Lrk_done:
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# draw_all: renderiza tabuleiro + fantasma + peça ativa
# =============================================================================
draw_all:
    addi sp, sp, -4; sw ra, 0(sp)

    # --- 1. Tabuleiro fixo ---
    li   s0, 0              # row
.Lda_row:
    li   t0, BH; bge s0, t0, .Lda_ghost
    li   s1, 0              # col
.Lda_col:
    li   t0, BW; bge s1, t0, .Lda_col_done
    mv   a0, s1; mv a1, s0
    call board_get
    mv   a2, a0
    mv   a0, s1; mv a1, s0
    call set_pixel
    addi s1, s1, 1; j .Lda_col
.Lda_col_done:
    addi s0, s0, 1; j .Lda_row

    # --- 2. Calcular e desenhar fantasma ---
.Lda_ghost:
    # Copiar px/py para gx/gy
    la   t0, px; la t1, py; la t2, gx; la t3, gy
    li   t4, 0
.Ldg_cp:
    li   t5, 4; bge t4, t5, .Ldg_drop
    slli t5, t4, 2
    add  a5, t0, t5; lw a5, 0(a5); add a6, t2, t5; sw a5, 0(a6)
    add  a5, t1, t5; lw a5, 0(a5); add a6, t3, t5; sw a5, 0(a6)
    addi t4, t4, 1; j .Ldg_cp

.Ldg_drop:
    # Descer gx/gy até colidir (sem mexer em px/py)
    # Truque: temporariamente troca px/py com gx/gy para usar collision
    la   t0, px; la t1, py; la t2, gx; la t3, gy

.Ldg_loop:
    # Trocar px/py <-> gx/gy
    li   t4, 0
.Ldg_swap_in:
    li   t5, 4; bge t4, t5, .Ldg_try
    slli t5, t4, 2
    add  a5, t0, t5; lw a6, 0(a5)
    add  a7, t2, t5; lw s2, 0(a7)
    sw   s2, 0(a5); sw a6, 0(a7)
    add  a5, t1, t5; lw a6, 0(a5)
    add  a7, t3, t5; lw s2, 0(a7)
    sw   s2, 0(a5); sw a6, 0(a7)
    addi t4, t4, 1; j .Ldg_swap_in

.Ldg_try:
    # Agora px/py = ghost; descer 1
    la   t5, py; li t4, 0
.Ldg_shift:
    li   t6, 4; bge t4, t6, .Ldg_chk
    slli a5, t4, 2; add a6, t5, a5; lw a7, 0(a6); addi a7, a7, 1; sw a7, 0(a6)
    addi t4, t4, 1; j .Ldg_shift
.Ldg_chk:
    call collision
    # Restaurar px/py <-> gx/gy (swap de volta)
    li   t4, 0
.Ldg_swap_out:
    li   t5, 4; bge t4, t5, .Ldg_swp_done
    slli t5, t4, 2
    add  a5, t0, t5; lw a6, 0(a5)
    add  a7, t2, t5; lw s2, 0(a7)
    sw   s2, 0(a5); sw a6, 0(a7)
    add  a5, t1, t5; lw a6, 0(a5)
    add  a7, t3, t5; lw s2, 0(a7)
    sw   s2, 0(a5); sw a6, 0(a7)
    addi t4, t4, 1; j .Ldg_swap_out
.Ldg_swp_done:
    # Se houve colisão no passo, desfazer o +1 em gy
    beqz a0, .Ldg_loop
    # Reverter +1 de gy
    la   t3, gy; li t4, 0
.Ldg_rev:
    li   t5, 4; bge t4, t5, .Ldg_draw
    slli t5, t4, 2; add a5, t3, t5; lw a6, 0(a5); addi a6, a6, -1; sw a6, 0(a5)
    addi t4, t4, 1; j .Ldg_rev

.Ldg_draw:
    # Desenhar fantasma (apenas onde board=0 e não sobrepõe peça)
    li   t4, 0
.Ldg_px:
    li   t5, 4; bge t4, t5, .Lda_piece
    slli t5, t4, 2
    la   t6, gx; add t6, t6, t5; lw s1, 0(t6)   # col
    la   t6, gy; add t6, t6, t5; lw s0, 0(t6)   # row

    bltz s0, .Ldg_skip
    li   t6, BH; bge s0, t6, .Ldg_skip
    bltz s1, .Ldg_skip
    li   t6, BW; bge s1, t6, .Ldg_skip

    # Não desenhar se board tem algo
    mv   a0, s1; mv a1, s0; call board_get; bnez a0, .Ldg_skip

    # Não desenhar se sobrepõe peça atual
    mv   a0, s1; mv a1, s0; call is_piece_xy; bnez a0, .Ldg_skip

    mv   a0, s1; mv a1, s0; li a2, C_GHOST; call set_pixel

.Ldg_skip:
    addi t4, t4, 1; j .Ldg_px

    # --- 3. Peça ativa ---
.Lda_piece:
    la   t0, cur_color; lw s3, 0(t0)   # cor
    li   t4, 0
.Ldp:
    li   t5, 4; bge t4, t5, .Lda_done
    slli t5, t4, 2
    la   t6, px; add t6, t6, t5; lw s1, 0(t6)
    la   t6, py; add t6, t6, t5; lw s0, 0(t6)
    bltz s0, .Ldp_skip
    li   t6, BH; bge s0, t6, .Ldp_skip
    bltz s1, .Ldp_skip
    li   t6, BW; bge s1, t6, .Ldp_skip
    mv   a0, s1; mv a1, s0; mv a2, s3; call set_pixel
.Ldp_skip:
    addi t4, t4, 1; j .Ldp

.Lda_done:
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# is_piece_xy(a0=col, a1=row) -> a0: 1 se é célula da peça ativa
# =============================================================================
is_piece_xy:
    mv   t0, a0; mv t1, a1
    la   t2, px; la t3, py; li t4, 0
.Lipxy:
    li   t5, 4; bge t4, t5, .Lipxy_no
    slli t5, t4, 2
    add  a5, t2, t5; lw a5, 0(a5)
    add  a6, t3, t5; lw a6, 0(a6)
    bne  a5, t0, .Lipxy_next
    beq  a6, t1, .Lipxy_yes
.Lipxy_next:
    addi t4, t4, 1; j .Lipxy
.Lipxy_yes:
    li   a0, 1; ret
.Lipxy_no:
    li   a0, 0; ret

# =============================================================================
# flash_red: pisca tela em vermelho (game over)
# =============================================================================
flash_red:
    addi sp, sp, -4; sw ra, 0(sp)
    li   s0, 0
.Lfr_r:
    li   t0, BH; bge s0, t0, .Lfr_wait
    li   s1, 0
.Lfr_c:
    li   t0, BW; bge s1, t0, .Lfr_cr
    mv   a0, s1; mv a1, s0; li a2, C_RED; call set_pixel
    addi s1, s1, 1; j .Lfr_c
.Lfr_cr:
    addi s0, s0, 1; j .Lfr_r
.Lfr_wait:
    li   t0, 50000
.Lfr_dl: addi t0, t0, -1; bnez t0, .Lfr_dl
    li   s0, 0
.Lfr_r2:
    li   t0, BH; bge s0, t0, .Lfr_w2
    li   s1, 0
.Lfr_c2:
    li   t0, BW; bge s1, t0, .Lfr_cr2
    mv   a0, s1; mv a1, s0; li a2, C_EMPTY; call set_pixel
    addi s1, s1, 1; j .Lfr_c2
.Lfr_cr2:
    addi s0, s0, 1; j .Lfr_r2
.Lfr_w2:
    li   t0, 50000
.Lfr_dl2: addi t0, t0, -1; bnez t0, .Lfr_dl2
    lw   ra, 0(sp); addi sp, sp, 4; ret

# =============================================================================
# busy_wait: delay curto entre frames
# =============================================================================
busy_wait:
    li   t0, 2000
.Lbw: addi t0, t0, -1; bnez t0, .Lbw
    ret
