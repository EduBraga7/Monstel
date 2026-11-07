class_name Geo
extends RefCounted
## Geometria compartilhada entre simulação e tela (unidades = pixels de referência).
## Cada andar tem FLOOR_W de largura; x=0 é a parede esquerda; os poços do elevador ficam à esquerda.

const FLOOR_W := 1000.0
const FLOOR_H := 240.0
const SHAFT_XS := [64.0, 142.0, 220.0]     # centro de cada poço (até 3)
const SHAFT_W := 66.0
const STREET_X := 1040.0                   # calçada, à direita da torre
const DOOR_X := 960.0                      # porta de entrada do saguão
const SERVICE_X := 972.0                   # escada de serviço (equipe)
const WALK_SPEED := 150.0                  # px/s base

# Saguão
const DESK_XS := [690.0, 560.0, 430.0]
const PAY_X := 640.0
const QUEUE_X0 := 820.0                    # frente da fila de recepção
const QUEUE_DX := 34.0                     # fila cresce para a direita
const WAIT_ROOM_X := 780.0                 # onde espera quem aguarda quarto limpo

# Espera do elevador: encosta no último poço construído
const ELEV_WAIT_DX := 30.0

# Suítes
const BED_XS := [450.0, 590.0, 730.0, 870.0]

# Facilidades
const SEAT_XS := [600.0, 720.0, 840.0, 930.0, 530.0, 470.0]
const FAC_WAIT_X0 := 420.0
const FAC_WAIT_DX := 30.0

## Primeiro ponto da fila do elevador, dado o número de poços construídos.
static func elev_wait_x0(shafts: int) -> float:
	return float(SHAFT_XS[clampi(shafts, 1, 3) - 1]) + 92.0

static func shaft_x(idx: int) -> float:
	return float(SHAFT_XS[clampi(idx, 0, 2)])
