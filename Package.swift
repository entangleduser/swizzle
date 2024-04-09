// swift-tools-version:5.7
import PackageDescription

let package = Package(
 name: "Swizzle",
 platforms: [.macOS(.v13), .iOS(.v12)],
 products: [
  .library(name: "Swizzle", targets: ["Swizzle"])
 ],
 targets: [
  .target(name: "Swizzle")
 ]
)
