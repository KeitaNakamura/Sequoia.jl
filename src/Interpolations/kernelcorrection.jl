"""
    KernelCorrection(::Kernel)

Kernel correction method [^KC] modifies kernels to achieve stable simulations near boundaries.
Available kernels include `BSpline`s and `GIMP`.

[^KC]: [Nakamura, K., Matsumura, S., & Mizutani, T. (2023). Taylor particle-in-cell transfer and kernel correction for material point method. *Computer Methods in Applied Mechanics and Engineering*, 403, 115720.](https://doi.org/10.1016/j.cma.2022.115720)
"""
struct KernelCorrection{K <: Kernel, P <: AbstractPolynomial} <: Interpolation
    kernel::K
    poly::P
end

KernelCorrection(k::Kernel) = KernelCorrection(k, LinearPolynomial())

get_kernel(kc::KernelCorrection) = kc.kernel
get_polynomial(kc::KernelCorrection) = kc.poly
gridspan(kc::KernelCorrection) = gridspan(get_kernel(kc))
@inline neighboringnodes(kc::KernelCorrection, pt, mesh::CartesianMesh) = neighboringnodes(get_kernel(kc), pt, mesh)

# general version
@inline function update_property!(mp::MPValue{<: KernelCorrection}, pt, mesh::CartesianMesh, filter::AbstractArray{Bool} = Trues(size(mesh)))
    indices = neighboringnodes(mp)
    isnearbounds = size(mp.N) != size(indices) || !alltrue(filter, indices)
    if isnearbounds
        update_property_nearbounds!(mp, pt, mesh, filter)
    else
        @inbounds @simd for ip in eachindex(indices)
            i = indices[ip]
            set_shape_values!(mp, ip, value(difftype(mp), get_kernel(interpolation(mp)), pt, mesh, i))
        end
    end
end

# fast version for B-spline kernels
@inline function update_property!(mp::MPValue{<: KernelCorrection{<: BSpline}}, pt, mesh::CartesianMesh, filter::AbstractArray{Bool} = Trues(size(mesh)))
    indices = neighboringnodes(mp)
    isnearbounds = size(mp.N) != size(indices) || !alltrue(filter, indices)
    if isnearbounds
        update_property_nearbounds!(mp, pt, mesh, filter)
    else
        set_shape_values!(mp, values(difftype(mp), get_kernel(interpolation(mp)), getx(pt), mesh))
    end
end

@inline function update_property_nearbounds!(mp::MPValue{<: KernelCorrection}, pt, mesh::CartesianMesh{dim}, filter::AbstractArray{Bool}) where {dim}
    indices = neighboringnodes(mp)
    kernel = get_kernel(interpolation(mp))
    poly = get_polynomial(interpolation(mp))
    xₚ = getx(pt)

    M = fastsum(eachindex(indices)) do ip
        @inbounds begin
            i = indices[ip]
            xᵢ = mesh[i]
            w = mp.N[ip] = value(kernel, pt, mesh, i) * filter[i]
            P = value(poly, xᵢ - xₚ)
            w * P ⊗ P
        end
    end
    M⁻¹ = inv(M)

    P₀, ∇P₀, ∇∇P₀ = value(hessian, poly, zero(xₚ))
    @inbounds for ip in eachindex(indices)
        i = indices[ip]
        xᵢ = mesh[i]
        w = mp.N[ip]
        P = value(poly, xᵢ - xₚ)
        wq = w * (M⁻¹ ⋅ P)
        hasproperty(mp, :N)   && set_shape_values!(mp, ip, (wq⋅P₀,))
        hasproperty(mp, :∇N)  && set_shape_values!(mp, ip, (wq⋅P₀, wq⋅∇P₀))
        hasproperty(mp, :∇∇N) && set_shape_values!(mp, ip, (wq⋅P₀, wq⋅∇P₀, wq⋅∇∇P₀))
    end
end

Base.show(io::IO, kc::KernelCorrection) = print(io, KernelCorrection, "(", get_kernel(kc), ", ", get_polynomial(kc), ")")
