{-# LANGUAGE TemplateHaskell #-}
module Blokus
    ( boardSize
    , corners
    , Polyomino(..)
    , polyominoes
    , polyominoTiles
    , D8(..)
    , compose
    , compose'
    , act
    , Player(..)
    , players
    , Block(..), shape, center, direction
    , Game(..), board, history, currentIndex, currentBlock
    , blockTiles
    , isBlockInbound
    , isValidBlock
    , placeBlock
    , Dir(..)
    , add
    , trans
    , available
    , currentPlayer
    ) where
import qualified Data.Map as M
import Data.Maybe (fromMaybe)
import Lens.Micro.Platform

boardSize :: Int
boardSize = 20

-- | Vector of two integers
type V2 = (Int, Int)

corners :: [V2]
corners = [(-1, -1), (boardSize, -1), (boardSize, boardSize), (-1, boardSize)]

-- | Polyomino names
data Polyomino = I1 | I2 | I3 | L3 | I4 | L4 | N4 | O4 | T4 | F | I | L | N | P | T | U | V | W | X | Y | Z
    deriving (Eq, Show, Read)

polyominoes :: [Polyomino]
polyominoes = [I1, I2, I3, L3, I4, L4, N4, O4, T4, F, I, L, N, P, T, U, V, W, X, Y, Z]

-- | Tiles of a polyomino
polyominoTiles :: Polyomino -> [V2]
polyominoTiles I1 = [(0, 0)]
polyominoTiles I2 = [(0, 0), (1, 0)]
polyominoTiles I3 = [(-1, 0), (0, 0), (1, 0)]
polyominoTiles L3 = [(0, 0), (1, 0), (0, 1)]
polyominoTiles I4 = [(-1, 0), (0, 0), (1, 0), (2, 0)]
polyominoTiles L4 = [(-1, 0), (0, 0), (1, 0), (1, 1)]
polyominoTiles N4 = [(0, 0), (1, 0), (-1, 1), (0, 1)]
polyominoTiles O4 = [(0, 0), (1, 0), (0, 1), (1, 1)]
polyominoTiles T4 = [(-1, 0), (0, 0), (1, 0), (0, 1)]
polyominoTiles F = [(0, -1), (-1, 0), (0, 0), (1, 0), (1, 1)]
polyominoTiles I = [(-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0)]
polyominoTiles L = [(-2, 0), (-1, 0), (0, 0), (1, 0), (1, 1)]
polyominoTiles N = [(-2, 0), (-1, 0), (0, 0), (0, 1), (1, 1)]
polyominoTiles P = [(-1, 0), (0, 0), (1, 0), (0, 1), (1, 1)]
polyominoTiles T = [(-1, -1), (0, -1), (1, -1), (0, 0), (0, 1)]
polyominoTiles U = [(-1, 0), (0, 0), (1, 0), (-1, 1), (1, 1)]
polyominoTiles V = [(-1, -1), (0, -1), (1, -1), (1, 0), (1, 1)]
polyominoTiles W = [(-1, -1), (0, -1), (0, 0), (1, 0), (1, 1)]
polyominoTiles X = [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
polyominoTiles Y = [(-2, 0), (-1, 0), (0, 0), (1, 0), (0, 1)]
polyominoTiles Z = [(0, -1), (1, -1), (0, 0), (-1, 1), (0, 1)]


-- | Dihedral group for rotation
data D8 = D8 Int Int
    deriving (Eq, Show)

-- | Composition of two D8 group elements
compose :: D8 -> D8 -> D8
compose (D8 s1 0) (D8 s2 t2) = D8 (mod (s1 + s2) 4) t2
compose (D8 s1 1) (D8 s2 t2) = D8 (mod (s1 - s2) 4) (1 - t2)
compose (D8 s1 t1) x = compose (D8 s1 $ mod t1 2) x

compose' :: D8 -> D8 -> D8
compose' = flip compose

-- | D8 acting on a coordinate
act :: D8 -> V2 -> V2
act (D8 0 0) z = z
act (D8 1 0) (x, y) = (-y, x)
act (D8 2 0) (x, y) = (-x, -y)
act (D8 3 0) (x, y) = (y, -x)
act (D8 s 1) z = (-x, y) where (x, y) = act (D8 s 0) z
act (D8 s t) z = act (D8 (mod s 4) (mod t 2)) z

-- | Player (color)
data Player = Blue | Green | Red | Yellow | Def
    deriving (Eq, Show)

players :: [Player]
players = [Blue, Green, Red, Yellow]

-- | Block, a instantiated polyomino
data Block = Block
    { _shape :: Polyomino
    , _center :: V2
    , _direction :: D8
    , _player :: Player
    } deriving (Eq, Show)
makeLenses ''Block

type Board = M.Map V2 Player

data Game = Game
    { _board :: Board
    , _history :: [Block]
    , _currentIndex :: Int
    , _currentBlock :: Maybe Block
    }
makeLenses ''Game

blockTiles :: Block -> [V2]
blockTiles k = map (add (_center k) . act (_direction k)) $ polyominoTiles $ _shape k

isPosFree :: Board -> V2 -> Bool
isPosFree b x = not $ M.member x b

isPosGood :: Board -> Player -> V2 -> Bool
isPosGood b p x = adj [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    where
        adj l = any ex [add x y | y <- l]
        ex y = fromMaybe False $ M.lookup y b >>= return . (p == )

isPosBad :: Board -> Player -> V2 -> Bool
isPosBad b p x = adj [(-1, 0), (1, 0), (0, -1), (0, 1)]
    where
        adj l = any ex [add x y | y <- l]
        ex y = fromMaybe False $ M.lookup y b >>= return . (p == )

isPosInbound :: V2 -> Bool
isPosInbound (x, y) = 0 <= x && x < boardSize && 0 <= y && y < boardSize

isBlockInbound :: Block -> Bool
isBlockInbound k = all isPosInbound $ blockTiles k

isValidBlock :: Board -> Block -> Bool
isValidBlock b k = all (isPosFree b) t && not (any (isPosBad b $ _player k) t) && any (isPosGood b $ _player k) t && all isPosInbound t
    where t = blockTiles k


placeBlock :: Block -> Board -> Board
placeBlock k b = M.union b $ M.fromList [(x, _player k) | x <- blockTiles k]

data Dir = UU | DD | LL | RR
    deriving (Eq, Show)

add :: V2 -> V2 -> V2
add (x0, y0) (x1, y1) = (x0 + x1, y0 + y1)

trans :: Dir -> V2 -> V2
trans UU = add (0, 1)
trans DD = add (0, -1)
trans LL = add (-1, 0)
trans RR = add (1, 0)

available :: Game -> Polyomino -> Player -> Bool
available g pm p = not $ any (\k -> _shape k == pm && _player k == p) $ _history g

currentPlayer :: Game -> Player
currentPlayer g = M.findWithDefault Def (corners !! _currentIndex g) $ _board g