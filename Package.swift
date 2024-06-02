// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenAIAssistantsAPI",
    products: [
        .library(
            name: "OpenAIAssistantsAPI",
            targets: ["OpenAIAssistantsAPI"]
        ),
    ],
    targets: [
        .target(
            name: "OpenAIAssistantsAPI"),
        .testTarget(
            name: "OpenAIAssistantsAPITests",
            dependencies: ["OpenAIAssistantsAPI"]
        ),
    ]
)
