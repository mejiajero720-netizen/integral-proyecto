PRACTICA I - DE LOS PIXELES A LA INTEGRAL: AREA BAJO UNA CURVA
ST0244 Paradigmas de Programacion - Universidad EAFIT
Profesor: Alexander Narvaez Berrio


INTEGRANTES

Jeronimo Mejia Jaramillo
Sebastian Cardona


QUE HACE

Lee la imagen binaria curva_binaria_P4.pbm, mide la altura de pixeles negros
de cada columna, guarda esas alturas en M y las suma. Esa suma es el area bajo
la curva. Esta resuelto dos veces: en Haskell (funcional) y en Prolog (logico).
Los dos programas dan el mismo resultado.


ENTORNO

Sistema operativo: Ubuntu 24.04
Haskell: GHC 9.4.7 (solo base y bytestring, que ya vienen con GHC)
Prolog: SWI-Prolog 9.0.4

No hay que instalar librerias adicionales. La salida es solo texto ASCII.


ESTRUCTURA DEL REPOSITORIO

README.txt
Haskell/Integral.hs
Prolog/integral.pl
curva_binaria_P4.pbm


COMO EJECUTAR HASKELL

cd Haskell
ghc -O2 -o integral Integral.hs
./integral ../curva_binaria_P4.pbm

Tambien sirve sin compilar: runghc Integral.hs ../curva_binaria_P4.pbm


COMO EJECUTAR PROLOG

cd Prolog
swipl -q -g main -t halt integral.pl ../curva_binaria_P4.pbm

-q quita el mensaje de bienvenida, -g main dice por donde empieza el programa
y -t halt cierra el interprete al terminar. Si no se pasa la ruta, los dos
programas usan ../curva_binaria_P4.pbm por defecto.


RESULTADO

AREA = 108660 pixeles cuadrados

Imagen de 567 x 319 pixeles, 71 bytes por fila, 567 columnas (567 rectangulos
en la suma de Riemann). Altura minima 95 px, altura maxima 239 px.


COMO SE CALCULA

1. Cada byte del PBM guarda 8 pixeles, uno por bit. Un bit en 1 es negro.
2. Para el pixel (x, y): indice del byte = y * bytesPorFila + x div 8, y la
   posicion del bit = 7 - (x mod 8). Se divide el byte entre 2 elevado a esa
   posicion y si el resultado es impar, el pixel es negro.
3. f(x) = cantidad de pixeles negros seguidos de la columna x, contando desde
   abajo hasta el primer blanco.
4. M = [f(0), f(1), ..., f(n-1)], una altura por columna.
5. Cada columna es un rectangulo de base 1 pixel, entonces el area es la suma
   de M (suma de Riemann con dx = 1).


ESTRATEGIA PARA MOSTRAR LA IMAGEN EN CONSOLA

La imagen es mucho mas grande que una terminal, asi que se reduce por muestreo.

Imagen binaria: se divide en una rejilla de 100 x 28 bloques y de cada bloque
se mira un solo pixel representativo (x = cx * ancho div 100, y = cy * alto
div 28). Si es negro se escribe # y si no un espacio. Se muestrea en vez de
promediar porque la region bajo la curva es una mancha negra continua, sin
detalles finos, asi que la silueta se conserva igual y el codigo queda simple.

Vector de alturas: se muestrean 100 columnas repartidas por todo el dominio y
cada altura se convierte a un numero de filas entre 0 y 16 con una regla de
tres: nivel = altura * 16 div maximo. Se imprime de arriba hacia abajo. Todo
el calculo es con enteros, no hay decimales en ninguna parte.


DIFERENCIA ENTRE LOS DOS PARADIGMAS

Haskell lo ve como transformaciones de datos:
    alturas img = map (f img) [0 .. ancho img - 1]
    area = sum
M sale de aplicar f a todo el dominio y el area de sumar la lista. Ningun dato
cambia de valor en el programa.

Prolog lo ve como relaciones. Se define f(X, Alto, BytesPorFila, Altura), que
se lee "Altura es la altura de la columna X", y despues se le piden todas las
soluciones:
    findall(Altura, (between(0, MaxX, X), f(X, Alto, BytesPorFila, Altura)), M),
    sum_list(M, Area).
El programa solo declara la condicion, el motor de Prolog busca los valores.

La formula es la misma en los dos casos, lo que cambia es la forma de
expresarla en el computador.
