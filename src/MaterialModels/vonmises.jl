struct VonMises{T} <: MaterialModel
    elastic::LinearElastic{T}
    q_y::T
end

function VonMises{T}(; q_y::Real, kwargs...) where {T}
    elastic = LinearElastic{T}(; kwargs...)
    VonMises{T}(elastic, q_y)
end

function VonMises{T}(mode_type::Symbol; c::Real, kwargs...) where {T}
    if mode_type == :plane_strain
        q_y = √3c
    else
        throw(ArgumentError("Supported model type is :plane_strain"))
    end
    elastic = LinearElastic{T}(; kwargs...)
    VonMises{T}(elastic, q_y)
end

VonMises(args...; kwargs...) = VonMises{Float64}(args...; kwargs...)

function update_stress(model::VonMises, σ::SymmetricTensor{2, 3}, dϵ::SymmetricTensor{2, 3})::typeof(σ)
    # compute the stress at the elastic trial state
    De = model.elastic.D
    σ_trial = σ + De ⊡ dϵ
    # compute the yield function at the elastic trial state
    dfdσ, f_trial = gradient(σ_trial -> yield_function(model, σ_trial), σ_trial, :all)
    if f_trial ≤ 0.0
        σ = σ_trial
    else
        # compute the increment of the plastic multiplier
        dgdσ = plastic_flow(model, σ_trial)
        Δγ = f_trial / (dgdσ ⊡ De ⊡ dfdσ)
        # compute the stress
        σ = σ_trial - Δγ * (De ⊡ dgdσ)
    end
    σ
end

function yield_function(model::VonMises, σ::SymmetricTensor{2, 3})::eltype(σ)
    s = dev(σ)
    q = sqrt(3/2 * s ⊡ s)
    return q - model.q_y
end

function plastic_flow(model::VonMises, σ::SymmetricTensor{2, 3})::typeof(σ)
    s = dev(σ)
    _s_ = sqrt(s ⊡ s)
    if _s_ < √eps(eltype(σ))
        dgdσ = zero(s)
    else
        dgdσ = sqrt(3/2) * s / _s_
    end
    return dgdσ
end
