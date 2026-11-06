// swift-tools-version: 6.0
// Paquete solo para probar el dominio (cálculos puros) en cualquier máquina, incluso Linux:
// swift test --package-path ios
import PackageDescription

let package = Package(
    name: "MPDomain",
    targets: [
        .target(name: "MPDomain", path: "MProgress/Domain"),
        .testTarget(name: "MPDomainTests", dependencies: ["MPDomain"], path: "MProgressTests/Domain"),
    ]
)
