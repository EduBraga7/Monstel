class_name Balance
extends RefCounted
## Constantes globais de balanceamento. Ajuste aqui o ritmo do jogo.

# --- Tempo -------------------------------------------------------------------
const DT := 0.1                    # passo fixo da simulação (segundos de jogo)
const DAY_LEN := 150.0             # duração de um "dia" (segundos de jogo)
const START_HOUR := 17.0           # o jogo começa ao entardecer
const DAY_START_HOUR := 6.0        # o "dia" vira às 6h (relatório + salários)
const NIGHT_START := 19.0
const NIGHT_END := 5.5

# --- Economia ----------------------------------------------------------------
const START_MONEY := 180.0
const MAX_FLOORS := 25             # andares totais contando o saguão (índice 0)
const FLOOR_COST_BASE := 60.0
const FLOOR_COST_GROWTH := 1.42    # crescimento do custo por andar construído...
const FLOOR_COST_KNEE := 8         # ...até este andar; depois fica mais íngreme
const FLOOR_COST_GROWTH_LATE := 1.55
const MAX_PER_TYPE := {
	&"suite": 99, &"bar": 2, &"buffet": 2, &"spa": 2, &"boutique": 2, &"gym": 2,
	&"housekeeping": 1, &"marketing": 1,
}

# --- Chegadas ----------------------------------------------------------------
const ARRIVAL_BASE_PER_MIN := 1.2
const ARRIVAL_PER_LEVEL_PER_MIN := 0.4
const ARRIVAL_PER_BED_PER_MIN := 0.5
const MAX_RECEPTION_QUEUE := 10
const REP_MULT_MIN := 0.6
const REP_MULT_SLOPE := 0.25       # por estrela acima de 1
const NIGHT_ARRIVAL_MULT := 1.25
const DAY_ARRIVAL_MULT := 0.85
const RUSH_MULT := 2.5
const RUSH_LEN := 60.0

# --- Preços (0 barato, 1 justo, 2 luxo) ---------------------------------------
const PRICE_DEMAND := [1.2, 1.0, 0.8]       # multiplica as chegadas (suítes)
const PRICE_FAC_USE := [1.25, 1.0, 0.75]    # chance de usar facilidades
const PRICE_REVENUE := [0.75, 1.0, 1.35]
const PRICE_SAT := [0.45, 0.0, -0.4]

# --- Hóspedes ----------------------------------------------------------------
const STAY_BASE := 40.0
const CHECKIN_BASE := 5.0
const MANAGER_DESK_SPEED := 0.8
const SELF_CLEAN_TIME := 20.0
const MAID_CLEAN_TIME := 8.0
const MAID_TRAVEL_SPEED := 3.0     # andares/s da equipe pela escada de serviço
const ROOM_WAIT_MAX := 40.0
const ELEV_GIVEUP := 90.0
const PAY_TIME := 1.2
const FLY_SPEED := 2.2             # andares/s dos fantasmas
const FAC_USE_FAV := 0.75
const FAC_USE_OTHER := 0.30

# --- Satisfação --------------------------------------------------------------
const SAT_BASE := 3.4
const REP_START := 3.0
const REP_ALPHA := 0.09
const RECEPTION_TOL := 8.0
const ELEVATOR_TOL := 10.0
const FAC_TOL := 9.0
const COMFORT_SAT_STEP := 0.3
const TIP_RATE := 0.12

# --- Progressão --------------------------------------------------------------
const XP_BASE := 12.0
const XP_GROWTH := 1.55
const WAGE_LEVEL_STEP := 0.25      # +25% de salário por nível de treino
const WAGE_FLOOR_STEP := 0.12      # +12% de salário por andar construído (hotel maior, folha maior)
const ARREARS_SPEED := 0.8         # equipe com salário atrasado trabalha mais devagar

# --- Eventos -----------------------------------------------------------------
const VIP_GAP_MIN := 420.0         # segundos de jogo entre VIPs
const VIP_GAP_MAX := 780.0
const VIP_RATE_MULT := 6.0
const INSP_GAP_MIN := 900.0
const INSP_GAP_MAX := 1500.0

# --- Offline -----------------------------------------------------------------
const OFFLINE_CAP_H := 8.0
const OFFLINE_EFFICIENCY := 0.5
