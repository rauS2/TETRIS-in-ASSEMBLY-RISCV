# =============================================================================
# Tetris básico para Ripes - LED Matrix 10x20 + Keyboard
# Controles: A = esquerda, D = direita, S = desce, W = reseta topo
#
# Estratégia de input:
#   Lê KEY_STATE (offset 0x08) — bitmask de teclas PRESSIONADAS AGORA.
#   Não depende de buffer. Funciona no modo run contínuo (triângulo preto).
#
#   KEY_STATE bits:  bit0=W  bit1=A  bit2=S  bit3=D
#
#   - Pressionar → bit sobe → peça move
#   - Soltar     → bit cai  → peça para
# =============================================================================
.data

.equ COR_PECA,  0x0000FF00
.equ COR_FUNDO, 0x00000000

.equ LED_BASE,    0xf0000008
.equ LED_WIDTH,   10
.equ LED_HEIGHT,  20

.equ KEY_STATE,   0xf0000008   # bitmask: bit0=W bit1=A bit2=S bit3=D

.equ BIT_W, 0x01   # bit 0
.equ BIT_A, 0x02   # bit 1
.equ BIT_S, 0x04   # bit 2
.equ BIT_D, 0x08   # bit 3

# Delay entre frames (ajuste conforme necessário)
# Valor maior = movimento mais lento
.equ DELAY_TICKS, 2500

.text
.globl main

# -----------------------------------------------------------------------------
main:
    li   sp, 0x00080000     # inicializa stack pointer

    li   s0, 5              # X inicial (centro)
    li   s1, 0              # Y inicial (topo)

    # Desenha peça inicial
    mv   a0, s0
    mv   a1, s1
    li   a2, COR_PECA
    call desenha_pixel

loop_jogo:
    # --- Lê estado atual das teclas ---
    li   t0, KEY_STATE
    lw   s2, 0(t0)          # s2 = bitmask das teclas pressionadas agora

    # Se nenhuma tecla pressionada, só aguarda
    beqz s2, loop_delay

    # --- Apaga posição atual ---
    mv   a0, s0
    mv   a1, s1
    li   a2, COR_FUNDO
    call desenha_pixel

    # --- Testa cada bit ---

    # W (bit0) → reseta para topo
    andi t0, s2, BIT_W
    bnez t0, faz_topo

    # A (bit1) → esquerda
    andi t0, s2, BIT_A
    bnez t0, faz_esquerda

    # S (bit2) → baixo
    andi t0, s2, BIT_S
    bnez t0, faz_baixo

    # D (bit3) → direita
    andi t0, s2, BIT_D
    bnez t0, faz_direita

    j    desenha_nova_pos

faz_esquerda:
    beqz s0, desenha_nova_pos
    addi s0, s0, -1
    j    desenha_nova_pos

faz_direita:
    li   t0, LED_WIDTH
    addi t0, t0, -1
    beq  s0, t0, desenha_nova_pos
    addi s0, s0, 1
    j    desenha_nova_pos

faz_baixo:
    li   t0, LED_HEIGHT
    addi t0, t0, -1
    beq  s1, t0, desenha_nova_pos
    addi s1, s1, 1
    j    desenha_nova_pos

faz_topo:
    li   s0, 5
    li   s1, 0
    j    desenha_nova_pos

desenha_nova_pos:
    mv   a0, s0
    mv   a1, s1
    li   a2, COR_PECA
    call desenha_pixel

loop_delay:
    # Delay simples para controlar velocidade do movimento
    li   t0, DELAY_TICKS
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop

    j    loop_jogo


# =============================================================================
# FUNÇÃO: desenha_pixel
# Entradas: a0 = X, a1 = Y, a2 = Cor
# =============================================================================
desenha_pixel:
    li   t2, LED_WIDTH
    mul  t3, a1, t2
    add  t3, t3, a0
    slli t3, t3, 2

    li   t4, LED_BASE
    add  t4, t4, t3

    sw   a2, 0(t4)
    ret
