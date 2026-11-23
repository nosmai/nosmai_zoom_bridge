Pod::Spec.new do |s|
  s.name = 'nosmai_zoom_bridge'
  s.version = '0.1.0'
  s.summary = 'Native Nosmai camera publishing for the Zoom Video SDK.'
  s.homepage = 'https://nosmai.com'
  s.author = 'Nosmai'
  s.license = { :type => 'Proprietary' }
  s.source = { :path => '.' }
  s.subspec 'Core' do |core|
    core.source_files = 'Classes/*.{h,mm}', 'Classes/Native/*.{h,cc}', 'Classes/Yuv/source/*.cc', 'Classes/Yuv/include/**/*.h'
    core.exclude_files = 'Classes/Yuv/source/*_neon64.cc'
    core.public_header_files = 'Classes/NosmaiZoomBridgePlugin.h'
  end
  s.subspec 'Neon64' do |neon|
    neon.source_files = 'Classes/Yuv/source/*_neon64.cc'
    neon.compiler_flags = '-march=armv8.2-a+dotprod+i8mm'
  end
  s.dependency 'Flutter'
  s.dependency 'nosmai_effects_sdk'
  s.dependency 'ZoomVideoSDK/ZoomVideoSDK', '2.6.0'
  s.platform = :ios, '15.0'
  s.frameworks = 'CoreVideo', 'QuartzCore'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/Classes/Yuv/include"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) LIBYUV_DISABLE_SVE LIBYUV_DISABLE_SME',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' => '"${PODS_ROOT}/ZoomVideoSDK/zoom-video-sdk-iOS/ZoomVideoSDK.xcframework/ios-arm64-simulator" $(inherited)',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' => '"${PODS_ROOT}/ZoomVideoSDK/zoom-video-sdk-iOS/ZoomVideoSDK.xcframework/ios-arm64" $(inherited)'
  }
end
