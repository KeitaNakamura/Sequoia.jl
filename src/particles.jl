abstract type SamplingAlgorithm end

struct GridSampling <: SamplingAlgorithm end

function point_sampling(::GridSampling, l::T, domain::Vararg{Tuple{T, T}, dim}) where {dim, T}
    minmax((xmin,xmax)) = (xmin+l/2, xmax)
    vec(CartesianMesh(l, minmax.(domain)...))
end

struct PoissonDiskSampling{RNG} <: SamplingAlgorithm
    rng::RNG
    parallel::Bool
end
PoissonDiskSampling() = PoissonDiskSampling(Random.default_rng(), true)
PoissonDiskSampling(rng; parallel=false) = PoissonDiskSampling(rng, parallel)

# Determine minimum distance between particles for Poisson disk sampling
# so that the number of generated particles is almost the same as the grid sampling.
# This empirical equation is slightly different from a previous work (https://kola.opus.hbz-nrw.de/frontdoor/deliver/index/docId/2129/file/MA_Thesis_Nilles_signed.pdf)
poisson_disk_sampling_minimum_distance(l::Real, dim::Int) = l/(1.37)^(1/√dim)
function point_sampling(pds::PoissonDiskSampling, l::T, domain::Vararg{Tuple{T, T}, dim}) where {dim, T}
    d = poisson_disk_sampling_minimum_distance(l, dim)
    reinterpret(Vec{dim, T}, poisson_disk_sampling(pds.rng, T, d, domain...; pds.parallel))
end

function generate_particles(::Type{ParticleProperty}, points::AbstractVector{<: Vec}) where {ParticleProperty}
    particles = StructVector{ParticleProperty}(undef, length(points))
    fillzero!(particles)
    getx(particles) .= points
    particles
end

"""
    generate_particles([ParticleProperty], mesh; spacing=0.5, alg=PoissonDiskSampling())

Generate particles with particle `spacing` by sampling `alg`orithm.
"""
function generate_particles(::Type{ParticleProperty}, mesh::CartesianMesh{dim, T}; spacing::Real=0.5, alg::SamplingAlgorithm=PoissonDiskSampling()) where {ParticleProperty, dim, T}
    domain = tuple.(Tuple(first(mesh)), Tuple(last(mesh)))
    points = point_sampling(alg, Sequoia.spacing(mesh) * T(spacing), domain...)
    particles = generate_particles(ParticleProperty, points)
    _reorder_particles!(particles, mesh)
end

function generate_particles(mesh::CartesianMesh{dim, T}; spacing::Real=0.5, alg::SamplingAlgorithm=PoissonDiskSampling()) where {dim, T}
    generate_particles(@NamedTuple{x::Vec{dim, T}}, mesh; spacing, alg).x
end

function _reorder_particles!(particles::AbstractVector, mesh::CartesianMesh)
    ptsinblks = map(_->Int[], CartesianIndices(blocksize(mesh)))
    for p in eachindex(particles)
        I = whichblock(getx(particles)[p], mesh)
        I === nothing || push!(ptsinblks[I], p)
    end
    reorder_particles!(particles, ptsinblks)
end
