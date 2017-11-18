source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

def library
    pod 'KissXML'
    pod 'KissXML/libxml_module'
    pod 'ICSMainFramework', :path => "./Library/ICSMainFramework/"
    pod 'MMWormhole', '~> 2.0.0'
end

def tunnel
    pod 'MMWormhole', '~> 2.0.0'
end

def socket
    pod 'CocoaAsyncSocket', '~> 7.4.3'
end

def model
    #pod 'RealmSwift', '~> 3.0.0'
end

target "Potatso" do
    pod 'Aspects', :path => "./Library/Aspects/"
    pod 'Cartography', '~> 2.0'
    pod 'AsyncSwift'
    pod 'SwiftColor'
    pod 'Appirater'
    pod 'Eureka', '~>  4.0.1'
    pod 'MBProgressHUD'
    pod 'CallbackURLKit'
    pod 'SVPullToRefresh', :git => 'https://github.com/samvermette/SVPullToRefresh'
    pod 'ISO8601DateFormatter', '~> 0.8'
    pod 'Alamofire', '~>  4.5.1'
    pod 'ObjectMapper', '~> 3.0.0'
    pod 'PSOperations', '~> 4.0.0'
    pod 'Fabric'
    pod 'Crashlytics'
    tunnel
    library
    socket
    model
end

target "PacketTunnel" do
    tunnel
    socket
end

target "PacketProcessor" do
    socket
end

target "TodayWidget" do
    pod 'Cartography', '~> 2.0'
    pod 'SwiftColor'
    library
    socket
    model
end

target "PotatsoLibrary" do
    library
    model
end

target "PotatsoModel" do
    model
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ENABLE_BITCODE'] = 'NO'
            config.build_settings['SWIFT_VERSION'] = '4.0'
        end
    end
end

