"""
   forwardrecurrence!(v, A, B, C, x)

evaluates the orthogonal polynomials at points `x`,
where `A`, `B`, and `C` are `AbstractVector`s containing the recurrence coefficients
as defined in DLMF,
overwriting `v` with the results.
"""
function forwardrecurrence!(v::AbstractVector{T}, A::AbstractVector, B::AbstractVector, C::AbstractVector, x, p0=one(T)) where T
    N = length(v)
    N == 0 && return v
    length(A)+1 ≥ N && length(B)+1 ≥ N && length(C)+1 ≥ N || throw(ArgumentError("A, B, C must contain at least $(N-1) entries"))
    p1 = convert(T, N == 1 ? p0 : muladd(A[1],x,B[1])*p0) # avoid accessing A[1]/B[1] if empty
    _forwardrecurrence!(v, A, B, C, x, convert(T, p0), p1)
end


Base.@propagate_inbounds _forwardrecurrence_next(n, A, B, C, x, p0, p1) = muladd(muladd(A[n],x,B[n]), p1, -C[n]*p0)
# special case for B[n] == 0
Base.@propagate_inbounds _forwardrecurrence_next(n, A, ::Zeros, C, x, p0, p1) = muladd(A[n]*x, p1, -C[n]*p0)
# special case for Chebyshev U
Base.@propagate_inbounds _forwardrecurrence_next(n, A::AbstractFill, ::Zeros, C::Ones, x, p0, p1) = muladd(getindex_value(A)*x, p1, -p0)


# this supports adaptivity: we can populate `v` for large `n`
function _forwardrecurrence!(v::AbstractVector, A::AbstractVector, B::AbstractVector, C::AbstractVector, x, p0, p1)
    N = length(v)
    N == 0 && return v
    v[1] = p0
    N == 1 && return v
    v[2] = p1
    @inbounds for n = 2:N-1
        p1,p0 = _forwardrecurrence_next(n, A, B, C, x, p0, p1),p1
        v[n+1] = p1
    end
    v
end



forwardrecurrence(N::Integer, A::AbstractVector, B::AbstractVector, C::AbstractVector, x) =
    forwardrecurrence!(Vector{promote_type(eltype(A),eltype(B),eltype(C),typeof(x))}(undef, N), A, B, C, x)


"""
clenshaw!(c, A, B, C, x)

evaluates the orthogonal polynomial expansion with coefficients `c` at points `x`,
where `A`, `B`, and `C` are `AbstractVector`s containing the recurrence coefficients
as defined in DLMF,
overwriting `x` with the results.

If `c` is a matrix this treats each column as a separate vector of coefficients, returning a vector
if `x` is a number and a matrix if `x` is a vector.
"""
clenshaw!(c::AbstractVector, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::AbstractVector) =
    clenshaw!(c, A, B, C, x, Ones{eltype(x)}(length(x)), x)

clenshaw!(c::AbstractMatrix, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::Number, f::AbstractVector) =
    clenshaw!(c, A, B, C, x, one(eltype(x)), f)


clenshaw!(c::AbstractMatrix, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::AbstractVector, f::AbstractMatrix) =
    clenshaw!(c, A, B, C, x, Ones{eltype(x)}(length(x)), f)


"""
clenshaw!(c, A, B, C, x, ϕ₀, f)

evaluates the orthogonal polynomial expansion with coefficients `c` at points `x`,
where `A`, `B`, and `C` are `AbstractVector`s containing the recurrence coefficients
as defined in DLMF and ϕ₀ is the zeroth polynomial,
overwriting `f` with the results.
"""
function clenshaw!(c::AbstractVector, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::AbstractVector, ϕ₀::AbstractVector, f::AbstractVector)
    f .= ϕ₀ .* clenshaw.(Ref(c), Ref(A), Ref(B), Ref(C), x)
end


function clenshaw!(c::AbstractMatrix, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::Number, ϕ₀::Number, f::AbstractVector)
    size(c,2) == length(f) || throw(DimensionMismatch("coeffients size and output length must match"))
    @inbounds for j in axes(c,2)
        f[j] = ϕ₀ * clenshaw(view(c,:,j), A, B, C, x)
    end
    f
end

function clenshaw!(c::AbstractMatrix, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::AbstractVector, ϕ₀::AbstractVector, f::AbstractMatrix)
    (size(x,1),size(c,2)) == size(f) || throw(DimensionMismatch("coeffients size and output length must match"))
    @inbounds for j in axes(c,2)
        clenshaw!(view(c,:,j), A, B, C, x, ϕ₀, view(f,:,j))
    end
    f
end

Base.@propagate_inbounds _clenshaw_next(n, A, B, C, x, c, bn1, bn2) = muladd(muladd(A[n],x,B[n]), bn1, muladd(-C[n+1],bn2,c[n]))
Base.@propagate_inbounds _clenshaw_next(n, A, ::Zeros, C, x, c, bn1, bn2) = muladd(A[n]*x, bn1, muladd(-C[n+1],bn2,c[n]))
# Chebyshev U
Base.@propagate_inbounds _clenshaw_next(n, A::AbstractFill, ::Zeros, C::Ones, x, c, bn1, bn2) = muladd(getindex_value(A)*x, bn1, -bn2+c[n])

# allow special casing first arg, for ChebyshevT in OrthogonalPolynomialsQuasi
Base.@propagate_inbounds _clenshaw_first(A, B, C, x, c, bn1, bn2) = muladd(muladd(A[1],x,B[1]), bn1, muladd(-C[2],bn2,c[1]))


"""
    clenshaw(c, A, B, C, x)

evaluates the orthogonal polynomial expansion with coefficients `c` at points `x`,
where `A`, `B`, and `C` are `AbstractVector`s containing the recurrence coefficients
as defined in DLMF.
`x` may also be a single `Number`.

If `c` is a matrix this treats each column as a separate vector of coefficients, returning a vector
if `x` is a number and a matrix if `x` is a vector.
"""

function clenshaw(c::AbstractVector, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::Number)
    N = length(c)
    T = promote_type(eltype(c),eltype(A),eltype(B),eltype(C),typeof(x))
    @boundscheck check_clenshaw_recurrences(N, A, B, C)
    N == 0 && return zero(T)
    @inbounds begin
        bn2 = zero(T)
        bn1 = convert(T,c[N])
        N == 1 && return bn1
        for n = N-1:-1:2
            bn1,bn2 = _clenshaw_next(n, A, B, C, x, c, bn1, bn2),bn1
        end
        bn1 = _clenshaw_first(A, B, C, x, c, bn1, bn2)
    end
    bn1
end


clenshaw(c::AbstractVector, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::AbstractVector) =
    clenshaw!(c, A, B, C, copy(x))

function clenshaw(c::AbstractMatrix, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::Number)
    T = promote_type(eltype(c),eltype(A),eltype(B),eltype(C),typeof(x))
    clenshaw!(c, A, B, C, x, Vector{T}(undef, size(c,2)))
end

function clenshaw(c::AbstractMatrix, A::AbstractVector, B::AbstractVector, C::AbstractVector, x::AbstractVector)
    T = promote_type(eltype(c),eltype(A),eltype(B),eltype(C),typeof(x))
    clenshaw!(c, A, B, C, x, Matrix{T}(undef, size(x,1), size(c,2)))
end

###
# Chebyshev T special cases
###

"""
   clenshaw!(c, x)

evaluates the first-kind Chebyshev (T) expansion with coefficients `c` at points `x`,
overwriting `x` with the results.
"""
clenshaw!(c::AbstractVector, x::AbstractVector) = clenshaw!(c, x, x)


"""
   clenshaw!(c, x, f)

evaluates the first-kind Chebyshev (T) expansion with coefficients `c` at points `x`,
overwriting `f` with the results.
"""
function clenshaw!(c::AbstractVector, x::AbstractVector, f::AbstractVector)
    f .= clenshaw.(Ref(c), x)
end

"""
    clenshaw(c, x)

evaluates the first-kind Chebyshev (T) expansion with coefficients `c` at  the points `x`.
`x` may also be a single `Number`.
"""
function clenshaw(c::AbstractVector, x::Number)
    N,T = length(c),promote_type(eltype(c),typeof(x))
    if N == 0
        return zero(T)
    elseif N == 1 # avoid issues with NaN x
        return first(c)*one(x)
    end

    y = 2x
    bk1,bk2 = zero(T),zero(T)
    @inbounds begin
        for k = N:-1:2
            bk1,bk2 = muladd(y,bk1,c[k]-bk2),bk1
        end
        muladd(x,bk1,c[1]-bk2)
    end
end

function clenshaw!(c::AbstractMatrix, x::Number, f::AbstractVector)
    size(c,2) == length(f) || throw(DimensionMismatch("coeffients size and output length must match"))
    @inbounds for j in axes(c,2)
        f[j] = clenshaw(view(c,:,j), x)
    end
    f
end

function clenshaw!(c::AbstractMatrix, x::AbstractVector, f::AbstractMatrix)
    (size(x,1),size(c,2)) == size(f) || throw(DimensionMismatch("coeffients size and output length must match"))
    @inbounds for j in axes(c,2)
        clenshaw!(view(c,:,j), x, view(f,:,j))
    end
    f
end

clenshaw(c::AbstractVector, x::AbstractVector) = clenshaw!(c, copy(x))
clenshaw(c::AbstractMatrix, x::Number) = clenshaw!(c, x, Vector{promote_type(eltype(c),typeof(x))}(undef, size(c,2)))
clenshaw(c::AbstractMatrix, x::AbstractVector) = clenshaw!(c, x, Matrix{promote_type(eltype(c),eltype(x))}(undef, size(x,1), size(c,2)))
