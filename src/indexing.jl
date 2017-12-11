const _allowscalar = Ref(true)

allowscalar(flag = true) = (_allowscalar[] = flag)

function assertscalar(op = "Operation")
  _allowscalar[] || error("$op is disabled")
  return
end

Base.IndexStyle(::Type{<:CuArray}) = IndexLinear()

function _getindex(xs::CuArray{T}, i::Integer) where T
  buf = Mem.view(xs.buf, (i-1)*sizeof(T))
  return Mem.download(T, buf)[1]
end

function Base.getindex(xs::CuArray{T}, i::Integer) where T
  ndims(xs) > 0 && assertscalar("scalar getindex")
  _getindex(xs, i)
end

function _setindex!(xs::CuArray{T}, v::T, i::Integer) where T
  buf = Mem.view(xs.buf, (i-1)*sizeof(T))
  Mem.upload!(buf, T[v])
end

function Base.setindex!(xs::CuArray{T}, v::T, i::Integer) where T
  assertscalar("scalar setindex!")
  _setindex!(xs, v, i)
end

Base.setindex!(xs::CuArray, v, i::Integer) = xs[i] = convert(eltype(xs), v)

# Vector indexing

using Base.Cartesian

# For now, this triggers scalar indexing in `checkbounds`
# Base.to_index(x::CuArray, i::AbstractArray) = cu(i)
# instead:
to_index(x) = x
to_index(x::AbstractArray) = cu(x)

@generated function index_kernel(dest::AbstractArray, src::AbstractArray, idims, Is)
    N = length(Is.parameters)
    quote
        i = (blockIdx().x-1) * blockDim().x + threadIdx().x
        i > length(dest) && return
        is = ind2sub(idims, i)
        @nexprs $N i -> @inbounds I_i = Is[i][is[i]]
        @inbounds dest[i] = @ncall $N getindex src i -> I_i
        return
    end
end

function Base._unsafe_getindex!(dest::CuArray, src::CuArray, Is::Union{Real, AbstractArray}...)
    idims = map(length, Is)
    blk, thr = cudims(dest)
    @cuda (blk, thr) index_kernel(dest, src, idims, to_index.(Is))
    return dest
end
