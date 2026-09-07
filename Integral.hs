-- ST0244 - Paradigmas de Programacion - EAFIT
-- Practica I: de los pixeles a la integral (area bajo la curva)
-- Parte I: Haskell (paradigma funcional)
--
-- Integrantes: Jeronimo Mejia Jaramillo
--              Sebastian
--
-- Idea general del programa:
--
--     archivo PBM -> bytes -> pixeles -> f(x) -> M -> area
--
-- Lo importante del paradigma funcional esta en estas dos lineas:
--
--     alturas img = map (f img) [0 .. ancho img - 1]
--     area        = sum
--
-- La lista M no se llena con un ciclo: se obtiene aplicando la funcion f a
-- todo el dominio con map. Y el area no se acumula en una variable que va
-- cambiando: se obtiene sumando la lista. En el programa no hay ni un solo
-- dato que cambie de valor.
--
-- Compilar y ejecutar:
--     ghc -O2 -o integral Integral.hs
--     ./integral ../curva_binaria_P4.pbm

module Main where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import Data.Char (isDigit, isSpace)
import System.Environment (getArgs)

-- ---------------------------------------------------------------------------
-- Tamanos del dibujo en consola
-- ---------------------------------------------------------------------------

anchoConsola :: Int
anchoConsola = 100      -- columnas de texto que ocupa cada dibujo

altoConsola :: Int
altoConsola = 28        -- filas de texto que ocupa el dibujo de la imagen

filasGrafica :: Int
filasGrafica = 16       -- filas de texto que ocupa la grafica de alturas

-- ---------------------------------------------------------------------------
-- 1. El tipo Imagen
-- ---------------------------------------------------------------------------
-- Guarda todo lo que hay que saber de la imagen: su ancho, su alto, cuantos
-- bytes ocupa cada fila y los bytes con los pixeles.
--
-- bytesPorFila hace falta porque cada fila se completa hasta llenar el ultimo
-- byte. Con ancho 567 se necesitan 71 bytes por fila (71 * 8 = 568 bits) y el
-- bit que sobra se ignora.

data Imagen = Imagen
  { ancho        :: Int
  , alto         :: Int
  , bytesPorFila :: Int
  , datos        :: BS.ByteString
  }

-- ---------------------------------------------------------------------------
-- 2. Leer el archivo PBM P4
-- ---------------------------------------------------------------------------
-- Un archivo P4 se ve asi:
--
--     P4
--     # comentario (puede o no estar)
--     567 319
--     <bytes con los pixeles>
--
-- Despues del alto hay UN solo caracter separador y ahi empiezan los bytes.
-- Como esos bytes no son texto, el archivo se lee con ByteString y no con
-- String.

-- Salta espacios, saltos de linea y comentarios que empiecen por '#'.
saltarBlancos :: BS.ByteString -> BS.ByteString
saltarBlancos bs
  | BS.null bs = bs
  | isSpace c  = saltarBlancos (BS.tail bs)
  | c == '#'   = saltarBlancos (BS.drop 1 (BC.dropWhile (/= '\n') bs))
  | otherwise  = bs
  where c = BC.head bs

-- Lee un numero y devuelve tambien lo que queda del archivo despues de el.
leerNumero :: BS.ByteString -> (Int, BS.ByteString)
leerNumero bs =
  let limpio = saltarBlancos bs
      (digitos, resto) = BC.span isDigit limpio
  in (read (BC.unpack digitos), resto)

-- Arma la Imagen a partir del contenido del archivo.
leerPBM :: BS.ByteString -> Imagen
leerPBM bs =
  let sinP4 = BS.drop 2 bs                 -- se salta el "P4" del principio
      (w, resto1) = leerNumero sinP4       -- ancho
      (h, resto2) = leerNumero resto1      -- alto
      pixeles = BS.drop 1 resto2           -- se salta el separador
  in Imagen { ancho = w
            , alto = h
            , bytesPorFila = (w + 7) `div` 8
            , datos = pixeles
            }

-- ---------------------------------------------------------------------------
-- 3. Saber si un pixel es negro
-- ---------------------------------------------------------------------------
-- En el formato P4 cada byte guarda 8 pixeles, uno por bit, y un bit en 1
-- significa negro. El pixel x = 0 esta en el bit de mas a la izquierda del
-- primer byte de su fila, por eso la posicion del bit se cuenta al reves.
--
--     indiceByte  = y * bytesPorFila + (x div 8)
--     posicionBit = 7 - (x mod 8)
--
-- Para saber si ese bit esta en 1 se divide el byte entre 2^posicionBit (eso
-- corre el bit hasta la derecha) y se mira si el resultado es impar.
--
-- Ejemplo: el pixel (10, 0) esta en el byte 1 (10 div 8) y en el bit 5
-- (7 - 10 mod 8). Si ese byte vale 32, entonces 32 div 2^5 = 1 y 1 mod 2 = 1,
-- o sea que el pixel es negro.

esNegro :: Imagen -> Int -> Int -> Bool
esNegro img x y = (valor `div` (2 ^ posicionBit)) `mod` 2 == 1
  where indiceByte  = y * bytesPorFila img + (x `div` 8)
        posicionBit = 7 - (x `mod` 8)
        valor = fromIntegral (BS.index (datos img) indiceByte) :: Int

-- ---------------------------------------------------------------------------
-- 4. La funcion f(x)
-- ---------------------------------------------------------------------------
-- f(x) es la cantidad de pixeles negros seguidos de la columna x, contando
-- desde abajo hasta el primer pixel blanco.
--
-- La lista [alto-1, alto-2 .. 0] son las filas de abajo hacia arriba,
-- takeWhile se queda con los pixeles negros hasta el primer blanco y length
-- los cuenta. No hace falta un contador ni un ciclo.

f :: Imagen -> Int -> Int
f img x = length (takeWhile (esNegro img x) [alto img - 1, alto img - 2 .. 0])

-- ---------------------------------------------------------------------------
-- 5. La lista de alturas M y el area
-- ---------------------------------------------------------------------------
--     M = [f(0), f(1), ..., f(n-1)]
--     A = suma de f(x) * dx,  y como dx = 1, A = suma de f(x)

alturas :: Imagen -> [Int]
alturas img = map (f img) [0 .. ancho img - 1]

area :: [Int] -> Int
area = sum

-- ---------------------------------------------------------------------------
-- 6. Dibujar la imagen en consola
-- ---------------------------------------------------------------------------
-- La imagen mide 567 x 319 pixeles y no cabe en una terminal, asi que hay que
-- reducirla. La estrategia es MUESTREO: se divide la imagen en una rejilla de
-- 100 x 28 bloques y de cada bloque se mira UN pixel representativo. Si ese
-- pixel es negro se escribe '#', si no un espacio.
--
-- El pixel que le toca al bloque (cx, cy) se calcula con una regla de tres:
--
--     x = cx * ancho div 100        y = cy * alto div 28
--
-- Funciona bien porque la region bajo la curva es una mancha negra continua,
-- no un dibujo con detalles finos: al muestrear se conserva la silueta.

dibujarImagen :: Imagen -> String
dibujarImagen img =
  unlines [ [ pixelDelBloque cx cy | cx <- [0 .. anchoConsola - 1] ]
          | cy <- [0 .. altoConsola - 1] ]
  where pixelDelBloque cx cy =
          let x = (cx * ancho img) `div` anchoConsola
              y = (cy * alto img) `div` altoConsola
          in if esNegro img x y then '#' else ' '

-- ---------------------------------------------------------------------------
-- 7. Dibujar la funcion de alturas M[x] = f(x)
-- ---------------------------------------------------------------------------
-- M tiene 567 alturas, una por columna, y tampoco caben en la pantalla. Se usa
-- el mismo muestreo: se escogen 100 columnas repartidas por todo el dominio.
--
-- Despues cada altura se convierte a un numero de filas entre 0 y 16 con otra
-- regla de tres, usando la altura maxima como referencia:
--
--     nivel = altura * 16 div maximo
--
-- La grafica se imprime de la fila de arriba hacia la de abajo: en la fila r
-- se pinta '#' si la columna llega hasta esa fila.

dibujarAlturas :: [Int] -> String
dibujarAlturas m =
  unlines [ [ if nivel >= fila then '#' else ' ' | nivel <- niveles ]
          | fila <- [filasGrafica, filasGrafica - 1 .. 1] ]
  where n = length m
        maximo = maximum m
        niveles = [ (m !! ((i * n) `div` anchoConsola) * filasGrafica) `div` maximo
                  | i <- [0 .. anchoConsola - 1] ]

-- ---------------------------------------------------------------------------
-- 8. Diez valores x_i -> f(x_i) repartidos por todo el dominio
-- ---------------------------------------------------------------------------

muestras :: [Int] -> [(Int, Int)]
muestras m = [ (posicion i, m !! posicion i) | i <- [0 .. 9] ]
  where posicion i = (i * (length m - 1)) `div` 9

-- ---------------------------------------------------------------------------
-- Programa principal
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  let ruta = case args of
               (r:_) -> r
               []    -> "../curva_binaria_P4.pbm"

  contenido <- BS.readFile ruta
  let img = leerPBM contenido
      m = alturas img       -- M = map f [0 .. ancho-1]
      a = area m            -- A = sum M

  putStrLn ("Archivo: " ++ ruta)
  putStrLn ("Imagen : " ++ show (ancho img) ++ " x " ++ show (alto img)
            ++ " pixeles  (" ++ show (bytesPorFila img) ++ " bytes por fila)")
  putStrLn ""

  putStrLn "IMAGEN BINARIA (un pixel muestreado por bloque)"
  putStrLn (replicate anchoConsola '-')
  putStr (dibujarImagen img)
  putStrLn (replicate anchoConsola '-')
  putStrLn ""

  putStrLn "VECTOR DE ALTURAS  M[x] = f(x)"
  putStrLn (replicate anchoConsola '-')
  putStr (dibujarAlturas m)
  putStrLn (replicate anchoConsola '-')
  putStrLn ("f(x) minimo = " ++ show (minimum m) ++ " px    f(x) maximo = "
            ++ show (maximum m) ++ " px")
  putStrLn ""

  putStrLn "ALGUNOS VALORES  x_i -> f(x_i)"
  mapM_ (\(i, (x, h)) -> putStrLn ("  x_" ++ show i ++ " = " ++ show x
                                   ++ "  ->  f(x_" ++ show i ++ ") = "
                                   ++ show h ++ " pixeles"))
        (zip [0 :: Int ..] (muestras m))
  putStrLn ""

  putStrLn "SUMA DE RIEMANN"
  putStrLn "  Cada columna es un rectangulo de base dx = 1 pixel"
  putStrLn ("  A = suma de f(x) para x entre 0 y " ++ show (ancho img - 1))
  putStrLn ("  Numero de rectangulos (columnas) = " ++ show (length m))
  putStrLn ("  AREA = " ++ show a ++ " pixeles cuadrados")
