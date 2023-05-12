@inline function to_principal(σ::SymmetricSecondOrderTensor{3})
    F = eigen(σ)
    n₁ = F.vectors[:,1]
    n₂ = F.vectors[:,2]
    n₃ = F.vectors[:,3]
    m₁ = symmetric(n₁ ⊗ n₁, :U)
    m₂ = symmetric(n₂ ⊗ n₂, :U)
    m₃ = symmetric(n₃ ⊗ n₃, :U)
    F.values, (m₁, m₂, m₃)
end

@inline function from_principal(σ::Vec{3}, (m₁, m₂, m₃)::NTuple{3, SymmetricSecondOrderTensor{3}})
    σ[1]*m₁ + σ[2]*m₂ + σ[3]*m₃
end

@inline krondelta(x::Type{<: Vec{3}}) = ones(x)
@inline krondelta(x::Type{<: Tensor{Tuple{3,3}}}) = one(x)
@inline krondelta(x::Type{<: Tensor{Tuple{@Symmetry{3,3}}}}) = one(x)
@inline krondelta(x::AbstractTensor) = krondelta(typeof(x))
