Pod::Spec.new do |spec|
  spec.name         = 'KuiklyHapticsPlusIOS'
  spec.version      = '0.0.2'
  spec.summary      = 'Kuikly Haptics Plus Module for iOS (HRVibrateModule)'
  spec.description  = '跨端手机震动 / 触感反馈 Kuikly Module 的 iOS 原生实现（HRVibrateModule）。'
  spec.homepage     = 'https://github.com/jlj/KuiklyHapticsPlus'
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author       = { 'jlj' => 'jlj@example.com' }
  spec.source       = { :git => 'https://github.com/jlj/KuiklyHapticsPlus.git', :tag => spec.version.to_s }
  spec.source_files = 'HRVibrateModule.{h,m}'
  spec.requires_arc = true
  spec.platform     = :ios, '13.0'
  spec.dependency 'OpenKuiklyIOSRender'
  spec.swift_version = '5.0'
end
