// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"EasyCallCore",products:[.library(name:"EasyCallCore",targets:["EasyCallCore"])],targets:[.target(name:"EasyCallCore",path:"Sources/Core"),.testTarget(name:"EasyCallCoreTests",dependencies:["EasyCallCore"],path:"Tests/Core")])
