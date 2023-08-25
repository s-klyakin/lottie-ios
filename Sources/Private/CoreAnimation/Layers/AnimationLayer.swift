// Created by Cal Stephens on 12/14/21.
// Copyright © 2021 Airbnb Inc. All rights reserved.

import QuartzCore

// MARK: - AnimationLayer

/// A type of `CALayer` that can be used in a Lottie animation
///  - Layers backed by a `LayerModel` subclass should subclass `BaseCompositionLayer`
protocol AnimationLayer: CALayer {
  /// Instructs this layer to setup its `CAAnimation`s
  /// using the given `LayerAnimationContext`
  func setupAnimations(context: LayerAnimationContext) throws
}

extension CALayer {

    public static func animation(withName name: String) -> CALayer? {
        guard let animation = LottieAnimation.named(name) else {return nil}
        return MainThreadAnimationLayer.layer(animation: animation)
    }
    
    public static func animation(withPath path: String) -> CALayer? {
        guard let animation = LottieAnimation.filepath(path) else {return nil}
        return MainThreadAnimationLayer.layer(animation: animation)
    }
    
    public static func animationLayer(_ animation: LottieAnimation) -> CALayer {
        return MainThreadAnimationLayer.layer(animation: animation)
    }
}


extension MainThreadAnimationLayer {
    static func layer(animation: LottieAnimation, imageProvider: AnimationImageProvider? = nil) -> MainThreadAnimationLayer {
        let layer = MainThreadAnimationLayer(animation: animation, imageProvider: imageProvider ?? BundleImageProvider(bundle: Bundle.main, searchPath: nil), textProvider: DefaultTextProvider(), fontProvider: DefaultFontProvider(), maskAnimationToBounds: true, logger: LottieLogger.shared)
            
            let fromStartFrame = animation.startFrame
            let toEndFrame = animation.endFrame
            let duration = Double(abs(toEndFrame - fromStartFrame)) / animation.framerate
            let anim = CABasicAnimation(keyPath: "currentFrame")
            anim.speed = 1
            anim.fromValue = fromStartFrame
            anim.toValue = toEndFrame
            anim.duration = duration
            anim.fillMode = CAMediaTimingFillMode.both
            anim.repeatCount = 1
            anim.autoreverses = false
            anim.isRemovedOnCompletion = false
            layer.add(anim, forKey: "anim")
            layer.shouldRasterize = false
            return layer
        }
}

// MARK: - LayerAnimationContext

// Context describing the timing parameters of the current animation
struct LayerAnimationContext {
  /// The animation being played
  let animation: LottieAnimation

  /// The timing configuration that should be applied to `CAAnimation`s
  let timingConfiguration: CoreAnimationLayer.CAMediaTimingConfiguration

  /// The absolute frame number that this animation begins at
  let startFrame: AnimationFrameTime

  /// The absolute frame number that this animation ends at
  let endFrame: AnimationFrameTime

  /// The set of custom Value Providers applied to this animation
  let valueProviderStore: ValueProviderStore

  /// Information about whether or not an animation is compatible with the Core Animation engine
  let compatibilityTracker: CompatibilityTracker

  /// The logger that should be used for assertions and warnings
  let logger: LottieLogger

  /// The AnimationKeypath represented by the current layer
  var currentKeypath: AnimationKeypath

  /// The `AnimationTextProvider`
  var textProvider: AnimationTextProvider

  /// Records the given animation keypath so it can be logged or collected into a list
  ///  - Used for `CoreAnimationLayer.logHierarchyKeypaths()` and `allHierarchyKeypaths()`
  var recordHierarchyKeypath: ((String) -> Void)?

  /// A closure that remaps the given frame in the child layer's local time to a frame
  /// in the animation's overall global time
  private(set) var timeRemapping: ((AnimationFrameTime) -> AnimationFrameTime) = { $0 }

  /// Adds the given component string to the `AnimationKeypath` stored
  /// that describes the current path being configured by this context value
  func addingKeypathComponent(_ component: String) -> LayerAnimationContext {
    var context = self
    context.currentKeypath.keys.append(component)
    return context
  }

  /// The `AnimationProgressTime` for the given `AnimationFrameTime` within this layer,
  /// accounting for the `timeRemapping` applied to this layer
  func progressTime(for frame: AnimationFrameTime) -> AnimationProgressTime {
    animation.progressTime(forFrame: timeRemapping(frame), clamped: false)
  }

  /// The real-time `TimeInterval` for the given `AnimationFrameTime` within this layer,
  /// accounting for the `timeRemapping` applied to this layer
  func time(for frame: AnimationFrameTime) -> TimeInterval {
    animation.time(forFrame: timeRemapping(frame))
  }

  /// Chains an additional `timeRemapping` closure onto this layer context
  func withTimeRemapping(
    _ additionalTimeRemapping: @escaping (AnimationFrameTime) -> AnimationFrameTime)
    -> LayerAnimationContext
  {
    var copy = self
    copy.timeRemapping = { [existingTimeRemapping = timeRemapping] time in
      existingTimeRemapping(additionalTimeRemapping(time))
    }
    return copy
  }
}
