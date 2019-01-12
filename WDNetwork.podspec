Pod::Spec.new do |s|
  s.name          = "WDNetwork"
  s.version       = "0.0.1"
  s.summary       = "A Netwoking base on AFNetworking"
  s.homepage      = "https://github.com/kwdx/WDNetwork"
  s.license       = "MIT"
  s.author             = { "warden" => "wenduo_mail@163.com" }
  s.platform      = :ios, "9.0"
  s.source        = { :git => "https://github.com/kwdx/WDNetwork.git", :tag => "#{s.version}" }
  s.source_files  = "WDNetwork/*.{h,m}"
  s.frameworks    = "UIKit", "Foundation"
  s.requires_arc  = true
  
  s.dependency 'AFNetworking'
end
