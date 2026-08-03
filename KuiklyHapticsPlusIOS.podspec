Pod::Spec.new do |spec|
  spec.name         = 'KuiklyHapticsPlusIOS'
  spec.version      = '0.2.0'
  spec.summary      = 'Kuikly Haptics Plus Module for iOS (HRVibrateModule)'
  spec.description  = '跨端手机震动 / 触感反馈 Kuikly Module 的 iOS 原生实现（HRVibrateModule）。'
  spec.homepage     = 'https://github.com/SoFarNoBug/KuiklyHapticsPlus'
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author       = { 'jlj' => 'jlj@example.com' }
  spec.source       = { :git => 'https://github.com/SoFarNoBug/KuiklyHapticsPlus.git', :tag => spec.version.to_s }
  spec.source_files = 'KuiklyHapticsPlusIOS/HRVibrateModule.{h,m}'
  spec.requires_arc = true
  spec.platform     = :ios, '13.0'
  spec.frameworks   = 'CoreHaptics', 'AudioToolbox', 'UIKit'
  spec.dependency 'OpenKuiklyIOSRender'
  spec.swift_version = '5.0'
end
