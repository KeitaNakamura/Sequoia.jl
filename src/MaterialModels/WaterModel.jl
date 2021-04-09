struct WaterModel{T} <: MaterialModel
    B::T
    γ::T
end

# https://www.researchgate.net/publication/220789258_Weakly_Compressible_SPH_for_Free_Surface_Flows
# B = 1119 (kPa)
# γ = 7
function WaterModel(; B::Real = 1119e3, γ::Real = 7)
    WaterModel(B, γ)
end

function bulkmodulus(model::WaterModel, F::SecondOrderTensor{3})
    γ = model.γ
    γ * (1/det(F))^γ
end

function update_stress(model::WaterModel, σ::SymmetricSecondOrderTensor{3}, F::SecondOrderTensor{3})
    B = model.B
    γ = model.γ
    p = B * (1/det(F)^γ - 1)
    -p*one(σ)
end
