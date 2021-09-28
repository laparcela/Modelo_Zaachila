extensions [
  gis
  palette
  csv
]

patches-own [
  TipoRaster
  tipoDeUso ;; Uso de suelo
  probSupervivencia ;; Permeabilidad de los parches, que en ultima instancia determina la calidad de la Matriz
  probReproduccion ;; Parches con mayor probSupervivencia tienen mayor probabilidad de reproduccion
  probMovimiento ;;Parches con menor probSupervivencia tienen mayor probabilidad de que los agentes se muevan
  nuevosIndividuos ;;creacion de nuevos individuos
  Permeabilidad ;; solo aplica para los parches de agricultura, para diferenciar entre los de calidad "alta" y los de calidad "baja"
  ]


globals [
  raster-dataset
  area-cuadro
  longitud-step
]

turtles-own [
  vivo?
  edad
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ca
  cargarMapa
    set-default-shape turtles "beetle"
  crearbichos
  calcularVariablesGlobales
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  if not any? turtles [stop]
  if ticks = 180 [; representa un ciclo de vida de las hembras adultas (donde cada tick = 1 dia).
    stop
  ]

  ask patches [
    sprout nuevosIndividuos [
      set vivo? true
      set edad 0
  ]
 ]

  actualizar-valores

  ask turtles with [vivo? = false] [die]
  ask turtles [
    foreach shuffle ["mortalidad" "movimiento" "reproduccion"] [proceso -> run proceso]
  ]
  overabundance-mortality
  ask turtles [set edad edad + 1]

 tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;; PROCESOS SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to cargarMapa ;; usa el mapa de uso de suelo elaborado por Urrutia-cardenas (2019)
  set raster-dataset gis:load-dataset "/home/lorena/Documents/UNAM/Tesis/versiones_de_corrección/mapa_raster_final.asc"
  gis:set-world-envelope ( gis:envelope-of raster-dataset )
  gis:apply-raster raster-dataset TipoRaster
  ask patches [initTipoDeUso]
  initEscenarioCoberturaUrbana
  initHabitat
  colorear
end



to initTipoDeUso
  set tipoDeUso "Nada"  ;; para los cuadritos que sobran del mapa
  if tipoRaster = 1 [ set tipoDeUso "Urbano" ]
  if tipoRaster = 2 [ set tipoDeUso "AgriculturaTemporal" ]
  if tipoRaster = 3 [ set tipoDeUso "AgriculturaRiego" ]
  if tipoRaster = 4 [ set tipoDeUso "Pastizal" ]
  if tipoRaster = 5 [ set tipoDeUso "Bosque" ]
  if tipoRaster = 6 [ set tipoDeUso "CuerposDeAgua" ]
  if tipoRaster = 7 [ set tipoDeUso "Otros"]
end



to initEscenarioCoberturaUrbana ;; Calcula el porcentaje de suelo urbano que hay en el poligono con base en la tasa de expansion y los años de proyeccion
  let numParchesUrbano count patches with [ tipoDeUso = "Urbano" ]
  let numTotalParchesUrbanoDeseado round ( numParchesUrbano + ( count patches with [ tipoDeUso != "Nada"] * anos-proyeccion * ( tasa-anual-aumento-urbano / 100 ) ) )
  while [ numParchesUrbano < numTotalParchesUrbanoDeseado ] [
    let numParchesQueFaltaConvertir numTotalParchesUrbanoDeseado - numParchesUrbano
    let parchesQueSePuedenConvertirAUrbano patches with [( tipoDeUso = "AgriculturaTemporal" or tipoDeUso = "AgriculturaRiego" or tipoDeUso = "Pastizal" ) and any? neighbors4 with [ tipoDeUso = "Urbano" ]] ;;Procuramos que no se creen nuevas zonas urbanas, sino que solo se expandan las ya existentes a parches vecinos.
      ifelse ( numParchesQueFaltaConvertir < count parchesQueSePuedenConvertirAUrbano )[
        ask n-of numParchesQueFaltaConvertir parchesQueSePuedenConvertirAUrbano [
        set tipoDeUso "Urbano"
      ]
    ]
    [
      ask parchesQueSePuedenConvertirAUrbano [
      set tipoDeUso "Urbano"
      ]
    ]
    set numParchesUrbano count patches with [ tipoDeUso = "Urbano" ]
  ]
end



to initHabitat
    ask patches with [ tipoDeUso = "Urbano" ][
    set probSupervivencia prob-supervivencia-urbano
    set probReproduccion prob-reproduccion-urbano
    set probMovimiento prob-movimiento-urbano
  ]
    ask patches with [ tipoDeUso = "Nada" ][
    set probSupervivencia prob-supervivencia-nada
    set probReproduccion prob-reproduccion-nada
  ]
    ask patches with [ tipoDeUso = "Bosque" ][
    set probSupervivencia prob-supervivencia-bosque
    set probReproduccion prob-reproduccion-bosque
    set probMovimiento prob-movimiento-bosque
  ]
    ask patches with [ tipoDeUso = "CuerposDeAgua" ][
    set probSupervivencia prob-supervivencia-agua
    set probReproduccion prob-reproduccion-agua
    set probMovimiento prob-movimiento-agua
  ]
    ask patches with [ tipoDeUso = "Pastizal" ][
    set probSupervivencia prob-supervivencia-pastizal
    set probReproduccion prob-reproduccion-pastizal
    set probMovimiento prob-movimiento-pastizal

  ]
    if calidad-matriz = "actual" [
    ask patches with [ tipoDeUso = "AgriculturaTemporal" ][
      ifelse random-float 1.00 < 0.32 [
        set probSupervivencia prob-supervivencia-agricultura-calidad-baja
        set Permeabilidad "calidad baja"
        set probReproduccion prob-reproduccion-agricultura-calidad-baja
        set probMovimiento prob-movimiento-agricultura-calidad-baja
      ][
        set probSupervivencia prob-supervivencia-agricultura-calidad-alta
        set Permeabilidad "calidad alta"
        set probReproduccion prob-reproduccion-agricultura-calidad-alta
        set probMovimiento prob-movimiento-agricultura-calidad-alta
      ]
    ]
    ask patches with [ tipoDeUso = "AgriculturaRiego" ][
      ifelse random-float 1.00 < 0.63 [
        set probSupervivencia prob-supervivencia-agricultura-calidad-baja
        set Permeabilidad "calidad baja"
        set probReproduccion prob-reproduccion-agricultura-calidad-baja
        set probMovimiento prob-movimiento-agricultura-calidad-baja
      ][
        set probSupervivencia prob-supervivencia-agricultura-calidad-alta
        set Permeabilidad "calidad alta"
        set probReproduccion prob-reproduccion-agricultura-calidad-alta
        set probMovimiento prob-movimiento-agricultura-calidad-alta
      ]
    ]
  ]
    if calidad-matriz = "alta" [
    ask patches with [ tipoDeUso = "AgriculturaTemporal" or tipoDeUso = "AgriculturaRiego" ][
      set probSupervivencia prob-supervivencia-agricultura-calidad-alta
      set Permeabilidad "calidad alta"
      set probReproduccion prob-reproduccion-agricultura-calidad-alta
      set probMovimiento prob-movimiento-agricultura-calidad-alta
    ]
  ]
    if calidad-matriz = "baja" [
    ask patches with [ tipoDeUso = "AgriculturaTemporal" or tipoDeUso = "AgriculturaRiego" ][
      set probSupervivencia prob-supervivencia-agricultura-calidad-baja
      set Permeabilidad "calidad baja"
      set probReproduccion prob-reproduccion-agricultura-calidad-baja
      set probMovimiento prob-movimiento-agricultura-calidad-baja
    ]
  ]
    if calidad-matriz = "contrastante" [
    ask patches with [ tipoDeUso = "AgriculturaTemporal"][
      set probSupervivencia prob-supervivencia-agricultura-calidad-alta
      set Permeabilidad "calidad alta"
      set probReproduccion prob-reproduccion-agricultura-calidad-alta
      set probMovimiento prob-movimiento-agricultura-calidad-alta

    ]
    ask patches with [ tipoDeUso = "AgriculturaRiego" ][
      set probSupervivencia prob-supervivencia-agricultura-calidad-baja
      set Permeabilidad "calidad baja"
      set probReproduccion prob-reproduccion-agricultura-calidad-baja
      set probMovimiento prob-movimiento-agricultura-calidad-baja
    ]
  ]
end


to colorear
  if colorear-por = "tipo de uso" [
    ask patches [ actualizarColorTipoDeUso ]
  ]
  if colorear-por = "probabilidad supervivencia" [
    ask patches [ actualizarColorProbSuper ]
  ]
end

to actualizarColorTipoDeUso
  if tipoDeUso = "Nada"                [ set pcolor gray - 5 ]
  if tipoDeUso = "Urbano"              [ set pcolor gray + 3 ]
  if tipoDeUso = "AgriculturaTemporal" [ set pcolor yellow + 2 ]
  if tipoDeUso = "AgriculturaRiego"    [ set pcolor lime + 1 ]
  if tipoDeUso = "Pastizal"            [ set pcolor orange + 2 ]
  if tipoDeUso = "Bosque"              [ set pcolor green - 3 ]
  if tipoDeUso = "CuerposDeAgua"       [ set pcolor sky ]
  if tipoDeUso = "Otros"               [ set pcolor magenta + 1 ]
end

to actualizarColorProbSuper
set pcolor palette:scale-gradient [[215 25 28] [253 174 97] [255 255 191] [171 217 233] [44 123 182 ]] probSupervivencia 0 1
end


to crearbichos
ask n-of 18000 patches with [ tipoDeUso = one-of ["AgriculturaTemporal" "AgriculturaRiego" "Pastizal" "Bosque"] ] [
  sprout poblacion-inicial [
    set color red
    set size 20
    set edad 0]
 ]
end


to calcularVariablesGlobales
  set area-cuadro 1000000 *( 182 / count patches with [ tipoDeUso != "Nada" ] ) ;; en metros cuadrados
  set longitud-step sqrt( area-cuadro ) ;; en metros
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;; PROCESOS GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to mortalidad
  if random-float 1.00 > probSupervivencia [
    set vivo? false
  ]
end

to movimiento
  ;; Hay diferentes formas en que los escarabajos se pueden mover... ahorita solo estamos modelando
  ;; las dinamicas de movimiento que encontramos reportadas en la literatura para los coprofagos, pero
  ;; se dejan abajo otras opciones de movimiento como futuros experimentos.

   if random-float 1.00 < probMovimiento [move-to one-of patches in-radius (tasa-movimiento / longitud-step)]

 ;; 1. caminata aleatoria 4 direcciones / saltos discretos ( distancia = step ) /  solo puede saltar de un patch vecino a otro
;  ask turtles [
;    move-to one-of neighbors
;    set pcolor yellow
;  ]
;  ;; 2. caminata aleatoria 360 grados / saltos discretos ( distancia = step ) / solo puede saltar de un patch a otro / ( creo que este movimiento es equivalente a "move-to one-of neighbors4"
;  ask turtles [
;    set heading random 360
;    fd 1
;    set pcolor orange
;  ]
;  ;; 3. caminata aleatoria 360 grados / saltos discretos ( distancia = tasa-movimiento ) / se mueve una distancia fija que no depende de los patches
;  ask turtles [
;    set heading random 360
;    fd tasa-movimiento / longitud-step
;    set pcolor green
;  ]
  ;; 4. caminata aleatoria 360 grados / saltos continuos ( distancia calculada a partir de una distribución normal con media igual a "tasa-de-movimiento" ) / se mueven una distancia variable que no depende de los pathces
;  ask turtles [
;    set heading random 360
;    fd random-normal ( tasa-movimiento / longitud-step ) 0.1
;    set pcolor violet
;  ]
;  ;; 5. vuelo lèvy 360 grados / saltos continuos ( distancia calculada a partir de ley de potencias ) / (no se si está bien implementado jeje)
;  ask turtles [
;    set heading random 360
;    fd ( tasa-movimiento / longitud-step ) * (random-float 1) ^ (-1 / 2.18)
;    set pcolor black
;  ]
;
end

to reproduccion
  if random-float 1.00 < probReproduccion [
    set nuevosIndividuos nuevosIndividuos + 1
  ]
end

to overabundance-mortality
  ask patches [
    if count turtles-here > capacidad-carga [
      ask n-of (count turtles-here - capacidad-carga) turtles-here [die]
    ]
  ]
end

to actualizar-valores
  ask patches [set nuevosIndividuos 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
233
10
1295
485
-1
-1
1.0
1
10
1
1
1
0
0
0
1
0
1053
0
465
1
1
1
ticks
30.0

BUTTON
27
499
94
532
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
106
499
169
532
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
971
580
1084
625
Bichos en temporal
count turtles-on patches with [tipoDeUso = \"AgriculturaTemporal\"]
17
1
11

PLOT
531
551
731
701
Populations
Time
Number alive
0.0
120.0
0.0
10.0
true
false
"" ""
PENS
"Total" 1.0 0 -16777216 true "" "plot count turtles"
"Urbano" 1.0 0 -7500403 true "" "plot count turtles-on patches with [ tipoDeUso = \"Urbano\" ]"
"Bosque" 1.0 0 -13210332 true "" "plot count turtles-on patches with [ tipoDeUso = \"Bosque\" ]"
"Agricultura Temporal" 1.0 0 -987046 true "" "plot count turtles-on patches with [ tipoDeUso = \"AgriculturaTemporal\"]"
"Agricultura Riego" 1.0 0 -5509967 true "" "plot count turtles-on patches with [ tipoDeUso = \"AgriculturaRiego\" ] "
"Pastizal" 1.0 0 -612749 true "" "plot count turtles-on patches with [ tipoDeUso = \"Pastizal\" ]"
"calidad alta" 1.0 0 -2674135 true "" "plot count turtles-on patches with [Permeabilidad = \"calidad alta\"]"
"calidad baja" 1.0 0 -955883 true "" "plot count turtles-on patches with [Permeabilidad = \"calidad baja\"]"

TEXTBOX
7
166
174
186
Expansion Urbana
12
0.0
1

SLIDER
5
189
219
222
tasa-anual-aumento-urbano
tasa-anual-aumento-urbano
0
8
0.48
0.01
1
%
HORIZONTAL

SLIDER
6
229
219
262
anos-proyeccion
anos-proyeccion
0
15
0.0
1
1
años
HORIZONTAL

TEXTBOX
7
12
174
32
Calidad de la Matriz
12
0.0
1

CHOOSER
5
32
144
77
calidad-matriz
calidad-matriz
"actual" "baja" "alta" "contrastante"
2

TEXTBOX
6
87
173
107
Representacion visual
12
0.0
1

CHOOSER
6
111
144
156
colorear-por
colorear-por
"tipo de uso" "probabilidad supervivencia"
1

TEXTBOX
8
272
175
305
Caracteristicas de Escarabajos
12
0.0
1

BUTTON
152
117
223
151
NIL
colorear
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
263
513
430
533
MONITORES
14
0.0
1

SLIDER
1304
27
1592
60
prob-supervivencia-agricultura-calidad-alta
prob-supervivencia-agricultura-calidad-alta
0.0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
1304
63
1592
96
prob-supervivencia-agricultura-calidad-baja
prob-supervivencia-agricultura-calidad-baja
0.0
1
0.3
0.01
1
NIL
HORIZONTAL

TEXTBOX
263
545
413
575
Porcentajes del tipo de uso de suelo 
12
0.0
1

MONITOR
263
583
338
628
% urbano
count patches with [ tipoDeUso = \"Urbano\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

MONITOR
430
639
504
684
% pastizal
count patches with [ tipoDeUso = \"Pastizal\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

MONITOR
429
583
503
628
% agua
count patches with [ tipoDeUso = \"CuerposDeAgua\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

MONITOR
263
639
338
684
% temporal
count patches with [ tipoDeUso = \"AgriculturaTemporal\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

MONITOR
347
639
422
684
% riego
count patches with [ tipoDeUso = \"AgriculturaRiego\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

MONITOR
346
583
421
628
% bosque
count patches with [ tipoDeUso = \"Bosque\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

TEXTBOX
969
507
1256
539
Bichos sobrevivientes en cada tipo de uso de suelo
12
0.0
1

MONITOR
970
530
1084
575
Bichos en bosque
count turtles-on patches with [tipoDeUso = \"Bosque\"]
17
1
11

MONITOR
1090
580
1204
625
Bichos en riego
count turtles-on patches with [tipoDeUso = \"AgriculturaRiego\"]
17
1
11

MONITOR
1090
530
1204
575
Bichos en pastizal
count turtles-on patches with [tipoDeUso = \"Pastizal\"]
17
1
11

TEXTBOX
971
680
1121
698
Numero total de bichos
12
0.0
1

MONITOR
971
698
1064
743
# bichos
count turtles
17
1
11

MONITOR
392
695
503
740
area cuadro (ha)
area-cuadro / 10000
10
1
11

MONITOR
264
695
384
740
longitud step (m)
longitud-step
4
1
11

SLIDER
1304
98
1592
131
prob-supervivencia-bosque
prob-supervivencia-bosque
0
1
0.9
0.01
1
NIL
HORIZONTAL

SLIDER
1304
133
1592
166
prob-supervivencia-pastizal
prob-supervivencia-pastizal
0
1
0.6
0.01
1
NIL
HORIZONTAL

SLIDER
1304
203
1592
236
prob-supervivencia-nada
prob-supervivencia-nada
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1304
168
1592
201
prob-supervivencia-urbano
prob-supervivencia-urbano
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
7
308
195
341
tasa-movimiento
tasa-movimiento
0
1000
46.0
1
1
m/tick
HORIZONTAL

SLIDER
7
350
195
383
poblacion-inicial
poblacion-inicial
0
100
0.0
1
1
ind/parche
HORIZONTAL

SLIDER
1304
238
1592
271
prob-supervivencia-agua
prob-supervivencia-agua
0
1
0.1
0.01
1
NIL
HORIZONTAL

MONITOR
971
630
1084
675
Calidad alta
count turtles-on patches with [Permeabilidad = \"calidad alta\"]
17
1
11

MONITOR
1090
630
1204
675
Calidad baja
count turtles-on patches with [Permeabilidad = \"calidad baja\"]
17
1
11

TEXTBOX
1305
10
1455
28
Supervivencia \n
12
0.0
1

SLIDER
8
391
197
424
capacidad-carga
capacidad-carga
0
100
3.0
1
1
ind/parche
HORIZONTAL

MONITOR
163
640
253
685
% calidad alta
count patches with [ Permeabilidad = \"calidad alta\" ] / count patches with [ tipoDeUso != \"Nada\" ] * 100
3
1
11

PLOT
735
551
948
701
Edad
Edad
freq
0.0
100.0
0.0
10.0
true
true
"clear-plot" ""
PENS
"default" 1.0 0 -16777216 true "" "histogram [edad] of turtles"

TEXTBOX
1304
273
1429
291
Reproduccion\n
12
0.0
1

SLIDER
1303
289
1593
322
prob-reproduccion-agricultura-calidad-alta
prob-reproduccion-agricultura-calidad-alta
0
1
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
1303
324
1593
357
prob-reproduccion-agricultura-calidad-baja
prob-reproduccion-agricultura-calidad-baja
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1303
359
1593
392
prob-reproduccion-bosque
prob-reproduccion-bosque
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1303
394
1593
427
prob-reproduccion-pastizal
prob-reproduccion-pastizal
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1303
429
1593
462
prob-reproduccion-urbano
prob-reproduccion-urbano
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1303
464
1593
497
prob-reproduccion-agua
prob-reproduccion-agua
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1303
499
1593
532
prob-reproduccion-nada
prob-reproduccion-nada
0
1
0.0
0.01
1
NIL
HORIZONTAL

TEXTBOX
1303
534
1428
552
Movimiento
12
0.0
1

SLIDER
1303
550
1594
583
prob-movimiento-agricultura-calidad-alta
prob-movimiento-agricultura-calidad-alta
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
1303
585
1594
618
prob-movimiento-agricultura-calidad-baja
prob-movimiento-agricultura-calidad-baja
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
1303
620
1594
653
prob-movimiento-bosque
prob-movimiento-bosque
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
1303
655
1594
688
prob-movimiento-pastizal
prob-movimiento-pastizal
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
1303
690
1594
723
prob-movimiento-urbano
prob-movimiento-urbano
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
1303
725
1594
758
prob-movimiento-agua
prob-movimiento-agua
0
1
0.1
0.01
1
NIL
HORIZONTAL

MONITOR
177
585
235
630
Patches
count patches with [tipoDeUso != \"Nada\" and tipoDeUSo != \"Agua\"]
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

beetle
true
0
Polygon -7500403 true true 135 60 150 75 165 75 180 60 180 75 195 90 120 90 135 75 135 60
Polygon -7500403 true true 150 150 150 150 105 135 105 105 135 90 180 90 210 105 210 135 165 150
Line -16777216 false 210 135 165 150
Line -16777216 false 105 135 150 150
Polygon -7500403 true true 150 135 105 150 105 210 150 225 165 225 210 210 210 150 165 135 150 135
Circle -7500403 true true 345 180 28
Line -16777216 false 210 135 165 150
Line -16777216 false 105 135 150 150
Line -16777216 false 120 150 120 210
Line -16777216 false 135 150 135 210
Line -16777216 false 195 150 195 210
Line -16777216 false 180 150 180 210
Line -16777216 false 165 165 165 210
Line -16777216 false 150 165 150 210
Polygon -7500403 true true 105 180 75 210 75 210 105 195
Polygon -7500403 true true 90 195 90 255 75 210
Polygon -7500403 true true 225 195 225 255 240 210
Polygon -7500403 true true 210 180 240 210 240 210 210 195
Polygon -7500403 true true 60 165 60 165 60 195 60 195 75 165 75 165
Polygon -7500403 true true 75 165 60 165 105 150
Polygon -7500403 true true 255 165 255 165 255 195 255 195 240 165 240 165
Polygon -7500403 true true 90 105 75 105 105 120
Polygon -7500403 true true 240 165 255 165 210 150
Polygon -7500403 true true 225 105 240 105 210 120
Polygon -7500403 true true 75 105 75 60 75 105
Polygon -7500403 true true 225 105 240 60 240 105
Polygon -7500403 true true 90 105 75 60 75 105
Line -16777216 false 135 90 180 90

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment-coordinates" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "exports/" behaviorspace-run-number "-world-"date-and-time ".csv")
export-view (word "exports/" behaviorspace-run-number "-view-" date-and-time ".png")
export-plot "Populations" (word "exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv")</final>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="46"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="82"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.26"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHA-A3P3B3U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B3U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B3U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B3U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHA-A3P3B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P3B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHA-A3P6B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P6B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P6B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HA/A3P6B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P3B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P6B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P3B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A3P6B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHA-A3P3B3U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B3U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B3U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B3U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHA-A3P3B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P3B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHA-A3P6B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P6B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P6B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HA/A3P6B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHA-A3P3B3U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B3U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B3U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B3U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHA-A3P3B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P3B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHA-A3P6B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P6B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P6B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HA/A3P6B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P3B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P6B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P3B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VBHAB-A3P6B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VB/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P3B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P6B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P3B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A3P6B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHA-A3P3B3U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B3U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B3U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B3U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHA-A3P3B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P3B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHA-A3P6B6U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P6B6U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P6B6U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HA/A3P6B6U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P3B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P6B9U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B9U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P3B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P3B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacC15VAHAB-A3P6B1U2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/C15/VA/HAB/A3P6B1U2/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVBHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MBCAVAHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MB/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;baja&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P3B3U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P3B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3P6B6U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P6B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P3B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-world ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-world-" date-and-time ".csv" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3P6B1U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A3A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A3A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A6A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A6A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A6A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A6A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A6A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A6A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A9A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A9A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A9A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A9A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHA-A9A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HA/A9A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A3A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A3A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A6A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A6A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A6A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A6A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A9A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A9A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A9A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A9A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A3A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A3A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A6A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A6A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A6A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A6A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A6A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A6A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A9A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A9A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A9A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A9A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHA-A9A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HA/A9A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A3A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )
export-plot "Populations" ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A3P3B9U1/exports/" behaviorspace-run-number "-poblacion-" date-and-time ".csv" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A6A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A6A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A6A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A6A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A9A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A9A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A9A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A9A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A3A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A3A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A6A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A6A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A6A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A6A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A6A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A6A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A9A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A9A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A9A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A9A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHA-A9A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HA/A9A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A3A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A3A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A6A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A6A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A6A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A6A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A9A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A9A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A9A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A9A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A3A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A3A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A6A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A6A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A6A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A6A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A6A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A6A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A9A3P3B3U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A9A3P3B3U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A9A3P3B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A9A3P3B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHA-A9A3P6B6U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HA/A9A3P6B6U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A3A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A3A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A6A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A6A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A6A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A6A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A9A3P3B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A9A3P3B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A9A3P6B1U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A9A3P6B1U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A9A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A9A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVAHAB-A9A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VA/HAB/A9A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A9A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A9A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MACAVBHAB-A9A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MA/CA/VB/HAB/A9A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;alta&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A9A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A9A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVBHAB-A9A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VB/HAB/A9A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A9A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A9A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MCCAVAHAB-A9A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/MC/CA/VA/HAB/A9A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;contrastante&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A9A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A9A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A9A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VB/HAB/A9A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png")</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A9A3P6B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A9A3P6B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A9A3P3B9U1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view ( word "/srv/home/lorena/netlogo/tesis/resultados/Mac/CA/VA/HAB/A9A3P3B9U1/exports/" behaviorspace-run-number "-view-" date-and-time ".png" )</final>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVAHAB-A9" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="625"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="MacCAVBHAB-A9" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Bosque"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "Pastizal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaTemporal"]</metric>
    <metric>count turtles-on patches with [tipoDeUso = "AgriculturaRiego"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad alta"]</metric>
    <metric>count turtles-on patches with [Permeabilidad = "calidad baja"]</metric>
    <enumeratedValueSet variable="prob-reproduccion-urbano">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colorear-por">
      <value value="&quot;tipo de uso&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calidad-matriz">
      <value value="&quot;actual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-alta">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agricultura-calidad-baja">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-pastizal">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agua">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-agua">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-alta">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-bosque">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-movimiento">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-alta">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-agricultura-calidad-baja">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poblacion-inicial">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-agricultura-calidad-baja">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-urbano">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacidad-carga">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-nada">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-supervivencia-pastizal">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="anos-proyeccion">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-pastizal">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tasa-anual-aumento-urbano">
      <value value="0.48"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-movimiento-bosque">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-reproduccion-bosque">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
