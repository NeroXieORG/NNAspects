#
# Be sure to run `pod lib lint NNAspects.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NNAspects'
  s.version          = '1.0.0'
  s.summary          = 'Implementing HOOK & AOP using libffi for Objective-C.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/YiHuaXie/NNAspects'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'NeroXie' => 'xyh30902@163.com' }
  s.source           = { :git => 'https://github.com/YiHuaXie/NNAspects', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }

  s.default_subspecs = 'Core', 'libffi'
  
  # libffi source code from https://github.com/libffi/libffi
  # version 3.3.0
  # how to fix libffi, you can see https://juejin.cn/post/6955652447670894606
  s.subspec 'libffi' do |d|
    d.source_files = 'NNAspects/libffi/**/*.{h,c,m,S}'
    d.public_header_files = 'NNAspects/libffi/**/*.{h}'
  end
  
  s.subspec 'Core' do |d|
    d.source_files = 'NNAspects/Classes/**/*'
    d.public_header_files = 'NNAspects/Classes/Aspects.h'
    d.dependency 'NNAspects/libffi'
  end
end
