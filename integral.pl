% ST0244 - Paradigmas de Programacion - EAFIT
% Practica I: de los pixeles a la integral (area bajo la curva)
% Parte II: Prolog (paradigma logico)
%
% Integrantes: Jeronimo Mejia Jaramillo
%              Sebastian
%
% Este programa no es la traduccion linea por linea del de Haskell. En Prolog
% no se escribe una secuencia de pasos, se escriben RELACIONES: se describe
% que tiene que cumplirse y el motor de Prolog busca los valores que lo
% cumplen.
%
% La relacion mas importante del programa es
%
%     f(X, Alto, BytesPorFila, Altura)
%
% que se lee "Altura es la altura de la columna X de esta imagen". Una vez
% escrita esa relacion, no se le ordena al programa recorrer las columnas: se
% le piden todas las soluciones con findall/3 y se suman con sum_list/2.
%
% Ejecutar:
%     swipl -q -g main -t halt integral.pl ../curva_binaria_P4.pbm

:- dynamic byte/2.      % byte(Indice, Valor): un hecho por cada byte de la imagen

% Tamanos de los dibujos en consola
ancho_consola(100).     % columnas de texto que ocupa cada dibujo
alto_consola(28).       % filas de texto del dibujo de la imagen
filas_grafica(16).      % filas de texto de la grafica de alturas

% ---------------------------------------------------------------------------
% 1. Leer el archivo PBM P4
% ---------------------------------------------------------------------------
% Un archivo P4 se ve asi:
%
%     P4
%     # comentario (puede o no estar)
%     567 319
%     <bytes con los pixeles>
%
% Se lee en modo octeto, o sea que cada elemento de la lista Bytes es un numero
% entre 0 y 255 y no un caracter.
%
% Los bytes de la imagen se guardan como hechos byte(Indice, Valor) en la base
% de datos de Prolog. Se hace asi porque consultar un hecho es inmediato,
% mientras que buscar la posicion N de una lista con nth0/3 obliga a recorrerla
% desde el principio; con mas de 20000 bytes el programa se demoraria muchisimo.

leer_pbm(Ruta, Ancho, Alto, BytesPorFila) :-
    read_file_to_codes(Ruta, Bytes, [encoding(octet)]),
    cabecera(Bytes, Ancho, Alto, Pixeles),
    BytesPorFila is (Ancho + 7) // 8,
    retractall(byte(_, _)),
    guardar_bytes(Pixeles, 0).

% guardar_bytes(+ListaDeBytes, +IndiceInicial)
guardar_bytes([], _).
guardar_bytes([Valor | Resto], Indice) :-
    assertz(byte(Indice, Valor)),
    Indice1 is Indice + 1,
    guardar_bytes(Resto, Indice1).

% cabecera(+Bytes, -Ancho, -Alto, -Pixeles)
% Despues del alto hay UN solo caracter separador y ahi empiezan los pixeles.
cabecera([0'P, 0'4 | Resto0], Ancho, Alto, Pixeles) :-
    saltar_blancos(Resto0, Resto1),
    numero(Resto1, Ancho, Resto2),
    saltar_blancos(Resto2, Resto3),
    numero(Resto3, Alto, Resto4),
    Resto4 = [_Separador | Pixeles].

% Salta espacios, saltos de linea y comentarios que empiecen por '#'.
saltar_blancos([C | R], Resto) :- code_type(C, space), !, saltar_blancos(R, Resto).
saltar_blancos([0'# | R], Resto) :- !, saltar_linea(R, R1), saltar_blancos(R1, Resto).
saltar_blancos(L, L).

saltar_linea([0'\n | R], R) :- !.
saltar_linea([_ | R], Resto) :- saltar_linea(R, Resto).
saltar_linea([], []).

% numero(+Lista, -N, -Resto): lee los digitos del principio y los vuelve numero.
numero(L, N, Resto) :-
    digitos(L, Digitos, Resto),
    number_codes(N, Digitos).

digitos([C | R], [C | Ds], Resto) :- code_type(C, digit), !, digitos(R, Ds, Resto).
digitos(L, [], L).

% ---------------------------------------------------------------------------
% 2. Cuando un pixel es negro
% ---------------------------------------------------------------------------
% Cada byte guarda 8 pixeles, uno por bit, y un bit en 1 significa negro. El
% pixel X = 0 esta en el bit de mas a la izquierda de su fila, por eso la
% posicion del bit se cuenta al reves:
%
%     indice del byte  = Y * BytesPorFila + X // 8
%     posicion del bit = 7 - (X mod 8)
%
% Para saber si ese bit esta en 1 se divide el byte entre 2^posicion (con eso
% el bit queda de ultimo) y se mira si el resultado es impar.

pixel_negro(BytesPorFila, X, Y) :-
    Indice is Y * BytesPorFila + X // 8,
    byte(Indice, Valor),
    Posicion is 7 - (X mod 8),
    (Valor // 2^Posicion) mod 2 =:= 1.

% ---------------------------------------------------------------------------
% 3. La relacion f(X, Alto, BytesPorFila, Altura)
% ---------------------------------------------------------------------------
% Altura es la cantidad de pixeles negros seguidos de la columna X, contando
% desde la base de la imagen (Y = Alto - 1) hacia arriba, hasta el primer
% pixel blanco.

f(X, Alto, BytesPorFila, Altura) :-
    YBase is Alto - 1,
    contar_negros(X, BytesPorFila, YBase, Altura).

% contar_negros(+X, +BytesPorFila, +Y, -Altura)
% Caso 1: ya no quedan filas, entonces la altura es 0.
contar_negros(_, _, Y, 0) :-
    Y < 0, !.
% Caso 2: el pixel es negro, entonces la altura es 1 mas la del resto de arriba.
contar_negros(X, BytesPorFila, Y, Altura) :-
    pixel_negro(BytesPorFila, X, Y), !,
    Y1 is Y - 1,
    contar_negros(X, BytesPorFila, Y1, Resto),
    Altura is Resto + 1.
% Caso 3: el pixel es blanco, entonces el conteo se detiene.
contar_negros(_, _, _, 0).

% ---------------------------------------------------------------------------
% 4. La lista de alturas M y el area
% ---------------------------------------------------------------------------
% Aqui esta la diferencia con Haskell. En vez de aplicar una funcion a cada
% elemento del dominio, se le pregunta a Prolog por TODAS las alturas que
% cumplen la relacion f para algun X entre 0 y Ancho-1.
%
%     M = [f(0), f(1), ..., f(n-1)]
%     A = suma de f(x) * dx,  y como dx = 1, A = suma de f(x)

alturas(Ancho, Alto, BytesPorFila, M) :-
    MaxX is Ancho - 1,
    findall(Altura,
            ( between(0, MaxX, X),
              f(X, Alto, BytesPorFila, Altura) ),
            M).

area(M, Area) :-
    sum_list(M, Area).

% ---------------------------------------------------------------------------
% 5. Dibujar la imagen en consola
% ---------------------------------------------------------------------------
% La imagen (567 x 319) no cabe en una terminal, asi que se reduce por
% MUESTREO: se divide en una rejilla de 100 x 28 bloques y de cada bloque se
% mira un solo pixel representativo. Si es negro se escribe '#' y si no un
% espacio. El pixel de cada bloque sale de una regla de tres:
%
%     X = CX * Ancho // 100        Y = CY * Alto // 28
%
% Sirve porque la region bajo la curva es una mancha negra continua, asi que
% al muestrear se conserva la silueta.

dibujar_imagen(Ancho, Alto, BytesPorFila) :-
    ancho_consola(AC),
    alto_consola(HC),
    AC1 is AC - 1,
    HC1 is HC - 1,
    forall(between(0, HC1, CY),
           ( Y is (CY * Alto) // HC,
             findall(Codigo,
                     ( between(0, AC1, CX),
                       X is (CX * Ancho) // AC,
                       caracter_pixel(BytesPorFila, X, Y, Codigo) ),
                     Codigos),
             string_codes(Linea, Codigos),
             writeln(Linea) )).

caracter_pixel(BytesPorFila, X, Y, 0'#) :- pixel_negro(BytesPorFila, X, Y), !.
caracter_pixel(_, _, _, 0' ).

% ---------------------------------------------------------------------------
% 6. Dibujar la funcion de alturas M[x] = f(x)
% ---------------------------------------------------------------------------
% M tiene 567 alturas y tampoco caben en la pantalla, asi que se muestrean 100
% columnas repartidas por todo el dominio. Cada altura se convierte a un numero
% de filas entre 0 y 16 con otra regla de tres:
%
%     Nivel = Altura * 16 // Maximo
%
% La grafica se imprime de arriba hacia abajo: en la fila R se pinta '#' si la
% columna llega hasta esa fila.

dibujar_alturas(M) :-
    ancho_consola(AC),
    filas_grafica(FG),
    length(M, N),
    max_list(M, Maximo),
    AC1 is AC - 1,
    findall(Nivel,
            ( between(0, AC1, I),
              X is (I * N) // AC,
              nth0(X, M, Altura),
              Nivel is (Altura * FG) // Maximo ),
            Niveles),
    forall(between(1, FG, R),
           ( Fila is FG - R + 1,          % se dibuja de la fila de arriba hacia abajo
             findall(Codigo,
                     ( member(Nivel, Niveles),
                       caracter_barra(Nivel, Fila, Codigo) ),
                     Codigos),
             string_codes(Linea, Codigos),
             writeln(Linea) )).

caracter_barra(Nivel, Fila, 0'#) :- Nivel >= Fila, !.
caracter_barra(_, _, 0' ).

% ---------------------------------------------------------------------------
% 7. Diez valores x_i -> f(x_i) repartidos por todo el dominio
% ---------------------------------------------------------------------------

muestras(M, Pares) :-
    length(M, N),
    findall(X-Altura,
            ( between(0, 9, I),
              X is (I * (N - 1)) // 9,
              nth0(X, M, Altura) ),
            Pares).

% ---------------------------------------------------------------------------
% Programa principal
% ---------------------------------------------------------------------------

main :-
    current_prolog_flag(argv, Argv),
    ( Argv = [Ruta | _] -> true ; Ruta = '../curva_binaria_P4.pbm' ),
    main(Ruta).

main(Ruta) :-
    leer_pbm(Ruta, Ancho, Alto, BytesPorFila),
    alturas(Ancho, Alto, BytesPorFila, M),
    area(M, Area),
    ancho_consola(AC),

    format("Archivo: ~w~n", [Ruta]),
    format("Imagen : ~d x ~d pixeles  (~d bytes por fila)~n~n",
           [Ancho, Alto, BytesPorFila]),

    format("IMAGEN BINARIA (un pixel muestreado por bloque)~n"),
    linea(AC),
    dibujar_imagen(Ancho, Alto, BytesPorFila),
    linea(AC), nl,

    format("VECTOR DE ALTURAS  M[x] = f(x)~n"),
    linea(AC),
    dibujar_alturas(M),
    linea(AC),
    min_list(M, Minimo),
    max_list(M, Maximo),
    format("f(x) minimo = ~d px    f(x) maximo = ~d px~n~n", [Minimo, Maximo]),

    format("ALGUNOS VALORES  x_i -> f(x_i)~n"),
    muestras(M, Pares),
    forall(nth0(I, Pares, X-Altura),
           format("  x_~d = ~d  ->  f(x_~d) = ~d pixeles~n", [I, X, I, Altura])),
    nl,

    format("SUMA DE RIEMANN~n"),
    MaxX is Ancho - 1,
    length(M, NumeroColumnas),
    format("  Cada columna es un rectangulo de base dx = 1 pixel~n"),
    format("  A = suma de f(x) para x entre 0 y ~d~n", [MaxX]),
    format("  Numero de rectangulos (columnas) = ~d~n", [NumeroColumnas]),
    format("  AREA = ~d pixeles cuadrados~n", [Area]).

% Imprime una linea de N guiones.
linea(N) :-
    forall(between(1, N, _), write('-')),
    nl.
