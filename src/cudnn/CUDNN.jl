module CUDNN

using ..CuArrays: CuArray, libcudnn

include("types.jl")
include("helpers.jl")
include("libcudnn.jl")
include("nnlib.jl")

function __init__()
    # Setup default cudnn handle
    global cudnnHandle
    cudnnHandlePtr = cudnnHandle_t[0]
    cudnnCreate(cudnnHandlePtr)
    cudnnHandle = cudnnHandlePtr[1]
    # destroy cudnn handle at julia exit
    atexit(()->cudnnDestroy(cudnnHandle))
    global CUDNN_VERSION = convert(Int, ccall((:cudnnGetVersion,libcudnn),Csize_t,()))
end

end
