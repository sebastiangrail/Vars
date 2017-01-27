import System
import Control.Vars
import System.Concurrency.Channels

-- Simple asynchronous calls
interface Async (m : Type -> Type) where
  Promise : Type -> Type

  -- Run an asynchronous action in another thread, return a 'promise'
  -- which will contain the result when it's done
  async : (action : Vs m a []) -> 
          Vs m (Maybe Var) [Add (maybe [] (\p => [p ::: Promise a]))]

  -- Get the result from a promise, and delete it
  getResult : (p : Var) -> Vs m (Maybe a) [Remove p (Promise a)]
     
-- A channel for transmitting a specific type
data TChannel : Type -> Type where
     MkTChannel : Channel -> TChannel a

Async IO where
  Promise = TChannel

  -- In IO, spawn a thread and create a channel for communicating with it
  -- Store the channel in the Promise
  async prog = do Just pid <- lift $ spawn (do Just chan <- listen 10
                                                     | Nothing => pure ()
                                               res <- run prog
                                               unsafeSend chan res
                                               pure ())
                       | Nothing => pure Nothing
                  Just chan <- lift $ connect pid
                       | Nothing => pure Nothing
                  promise <- new (MkTChannel chan)
                  pure (Just promise)
  -- Receive a message on the channel in the promise. unsafeRecv will block
  -- until it's there
  getResult {a} p = do MkTChannel chan <- get p
                       delete p
                       lift $ unsafeRecv a chan

calcThread : Nat -> IO Nat
calcThread Z = pure Z
calcThread (S k) = do putStrLn "Counting"
                      usleep 1000000
                      v <- calcThread k
                      pure (v + k)

asyncMain : Vs IO () []
asyncMain = do Just promise <- async (lift (calcThread 10))
                    | Nothing => lift (putStrLn "Async call failed")
               lift (putStrLn "Main thread")
               lift (putStr "What's your name? ")
               name <- lift getLine 
               lift (putStrLn ("Hello " ++ name))
               lift (putStrLn "Waiting for the answer")
               Just result <- getResult promise
                    | Nothing => lift (putStrLn "Getting result failed")
               lift (printLn result)

main : IO ()
main = run asyncMain
