// The MIT License (MIT)
//
//  Copyright © 2017年 ShowHandAce
//

/**
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import UIKit

open class SCFullscreenPopGesture {
    
    open class func configure() {
        
        UINavigationController.sc_nav_initialize()
        UIViewController.sc_initialize()
    }
    
}

extension UINavigationController {
    
    private var sc_popGestureRecognizerDelegate: _SCFullscreenPopGestureRecognizerDelegate {
        guard let delegate = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_popGestureRecognizerDelegate!) as? _SCFullscreenPopGestureRecognizerDelegate else {
            let popDelegate = _SCFullscreenPopGestureRecognizerDelegate()
            popDelegate.navigationController = self
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_popGestureRecognizerDelegate!, popDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return popDelegate
        }
        return delegate
    }
    
    open class func sc_nav_initialize() {
        // Inject "-pushViewController:animated:"
        DispatchQueue.once(token: "com.UINavigationController.MethodSwizzling", block: {
            let originalMethod = class_getInstanceMethod(self, #selector(pushViewController(_:animated:)))
            let swizzledMethod = class_getInstanceMethod(self, #selector(sc_pushViewController(_:animated:)))
            method_exchangeImplementations(originalMethod!, swizzledMethod!)
        })
    }
    
//    override open class func initialize() {
//        // Inject "-pushViewController:animated:"
//        DispatchQueue.once(token: "com.UINavigationController.MethodSwizzling", block: {
//            let originalMethod = class_getInstanceMethod(self, #selector(pushViewController(_:animated:)))
//            let swizzledMethod = class_getInstanceMethod(self, #selector(sc_pushViewController(_:animated:)))
//            method_exchangeImplementations(originalMethod!, swizzledMethod!)
//        })
//    }
    
    @objc private func sc_pushViewController(_ viewController: UIViewController, animated: Bool) {
        
        if self.interactivePopGestureRecognizer?.view?.gestureRecognizers?.contains(self.sc_fullscreenPopGestureRecognizer) == false {
            
            // Add our own gesture recognizer to where the onboard screen edge pan gesture recognizer is attached to.
            self.interactivePopGestureRecognizer?.view?.addGestureRecognizer(self.sc_fullscreenPopGestureRecognizer)
            
            // Forward the gesture events to the private handler of the onboard gesture recognizer.
            let internalTargets = self.interactivePopGestureRecognizer?.value(forKey: "targets") as? Array<NSObject>
            let internalTarget = internalTargets?.first?.value(forKey: "target")
            let internalAction = NSSelectorFromString("handleNavigationTransition:")
            if let target = internalTarget {
                self.sc_fullscreenPopGestureRecognizer.delegate = self.sc_popGestureRecognizerDelegate
                self.sc_fullscreenPopGestureRecognizer.addTarget(target, action: internalAction)
                
                // Disable the onboard gesture recognizer.
                self.interactivePopGestureRecognizer?.isEnabled = false
            }
        }
        
        // Handle perferred navigation bar appearance.
        self.sc_setupViewControllerBasedNavigationBarAppearanceIfNeeded(viewController)
        
        // Forward to primary implementation.
        self.sc_pushViewController(viewController, animated: animated)
    }
    
    private func sc_setupViewControllerBasedNavigationBarAppearanceIfNeeded(_ appearingViewController: UIViewController) {
        
        if !self.sc_viewControllerBasedNavigationBarAppearanceEnabled {
            return
        }
        
        let blockContainer = _SCViewControllerWillAppearInjectBlockContainer() { [weak self] (_ viewController: UIViewController, _ animated: Bool) -> Void in
            self?.setNavigationBarHidden(viewController.sc_prefersNavigationBarHidden, animated: animated)
        }
        
        // Setup will appear inject block to appearing view controller.
        // Setup disappearing view controller as well, because not every view controller is added into
        // stack by pushing, maybe by "-setViewControllers:".
        appearingViewController.sc_willAppearInjectBlockContainer = blockContainer
        let disappearingViewController = self.viewControllers.last
        if let vc = disappearingViewController {
            if vc.sc_willAppearInjectBlockContainer == nil {
                vc.sc_willAppearInjectBlockContainer = blockContainer
            }
        }
    }
    
    /// The gesture recognizer that actually handles interactive pop.
    public var sc_fullscreenPopGestureRecognizer: UIPanGestureRecognizer {
        guard let pan = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_fullscreenPopGestureRecognizer!) as? UIPanGestureRecognizer else {
            let panGesture = UIPanGestureRecognizer()
            panGesture.maximumNumberOfTouches = 1;
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_fullscreenPopGestureRecognizer!, panGesture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            return panGesture
        }
        return pan
    }
    
    /// A view controller is able to control navigation bar's appearance by itself,
    /// rather than a global way, checking "fd_prefersNavigationBarHidden" property.
    /// Default to true, disable it if you don't want so.
    public var sc_viewControllerBasedNavigationBarAppearanceEnabled: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_viewControllerBasedNavigationBarAppearanceEnabled!) as? Bool else {
                self.sc_viewControllerBasedNavigationBarAppearanceEnabled = true
                return true
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_viewControllerBasedNavigationBarAppearanceEnabled!, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}

fileprivate typealias _SCViewControllerWillAppearInjectBlock = (_ viewController: UIViewController, _ animated: Bool) -> Void

fileprivate class _SCViewControllerWillAppearInjectBlockContainer {
    var block: _SCViewControllerWillAppearInjectBlock?
    init(_ block: @escaping _SCViewControllerWillAppearInjectBlock) {
        self.block = block
    }
}

extension UIViewController {
    
    fileprivate var sc_willAppearInjectBlockContainer: _SCViewControllerWillAppearInjectBlockContainer? {
        get {
            return objc_getAssociatedObject(self, RuntimeKey.KEY_sh_willAppearInjectBlockContainer!) as? _SCViewControllerWillAppearInjectBlockContainer
        }
        set {
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_willAppearInjectBlockContainer!, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    open class func sc_initialize() {
        
        DispatchQueue.once(token: "com.UIViewController.MethodSwizzling", block: {
            let originalMethod = class_getInstanceMethod(self, #selector(viewWillAppear(_:)))
            let swizzledMethod = class_getInstanceMethod(self, #selector(sc_viewWillAppear(_:)))
            method_exchangeImplementations(originalMethod!, swizzledMethod!)
        })
    }
    
//    override open class func initialize() {
//
//        DispatchQueue.once(token: "com.UIViewController.MethodSwizzling", block: {
//            let originalMethod = class_getInstanceMethod(self, #selector(viewWillAppear(_:)))
//            let swizzledMethod = class_getInstanceMethod(self, #selector(sc_viewWillAppear(_:)))
//            method_exchangeImplementations(originalMethod!, swizzledMethod!)
//        })
//    }
    
    @objc private func sc_viewWillAppear(_ animated: Bool) {
        // Forward to primary implementation.
        self.sc_viewWillAppear(animated)
        
        if let block = self.sc_willAppearInjectBlockContainer?.block {
            block(self, animated)
        }
    }
    
    /// Whether the interactive pop gesture is disabled when contained in a navigation stack.
    public var sc_interactivePopDisabled: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_interactivePopDisabled!) as? Bool else {
                return false
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_interactivePopDisabled!, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    /// Indicate this view controller prefers its navigation bar hidden or not,
    /// checked when view controller based navigation bar's appearance is enabled.
    /// Default to false, bars are more likely to show.
    public var sc_prefersNavigationBarHidden: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_prefersNavigationBarHidden!) as? Bool else {
                return false
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_prefersNavigationBarHidden!, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    /// Max allowed initial distance to left edge when you begin the interactive pop
    /// gesture. 0 by default, which means it will ignore this limit.
    public var sc_interactivePopMaxAllowedInitialDistanceToLeftEdge: Double {
        get {
            guard let doubleNum = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_interactivePopMaxAllowedInitialDistanceToLeftEdge!) as? Double else {
                return 0.0
            }
            return doubleNum
        }
        set {
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_interactivePopMaxAllowedInitialDistanceToLeftEdge!, newValue, .OBJC_ASSOCIATION_COPY)
        }
    }
}

private class _SCFullscreenPopGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    
    weak var navigationController: UINavigationController?
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let navigationC = self.navigationController else {
            return false
        }
        
        // Ignore when no view controller is pushed into the navigation stack.
        guard navigationC.viewControllers.count > 1 else {
            return false
        }
        
        // Disable when the active view controller doesn't allow interactive pop.
        guard let topViewController = navigationC.viewControllers.last else {
            return false
        }
        guard !topViewController.sc_interactivePopDisabled else {
            return false
        }
        
        // Ignore pan gesture when the navigation controller is currently in transition.
        guard let trasition = navigationC.value(forKey: "_isTransitioning") as? Bool else {
            return false
        }
        guard !trasition else {
            return false
        }
        
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        
        // Ignore when the beginning location is beyond max allowed initial distance to left edge.
        let beginningLocation = panGesture.location(in: panGesture.view)
        let maxAllowedInitialDistance = topViewController.sc_interactivePopMaxAllowedInitialDistanceToLeftEdge
        guard maxAllowedInitialDistance <= 0 || Double(beginningLocation.x) <= maxAllowedInitialDistance else {
            return false
        }
        
        // Prevent calling the handler when the gesture begins in an opposite direction.
        let translation = panGesture.translation(in: panGesture.view)
        guard translation.x > 0 else {
            return false
        }
        
        return true
    }
}

fileprivate struct RuntimeKey {
    static let KEY_sh_willAppearInjectBlockContainer
        = UnsafeRawPointer(bitPattern: "KEY_sh_willAppearInjectBlockContainer".hashValue)
    static let KEY_sh_interactivePopDisabled
        = UnsafeRawPointer(bitPattern: "KEY_sh_interactivePopDisabled".hashValue)
    static let KEY_sh_prefersNavigationBarHidden
        = UnsafeRawPointer(bitPattern: "KEY_sh_prefersNavigationBarHidden".hashValue)
    static let KEY_sh_interactivePopMaxAllowedInitialDistanceToLeftEdge
        = UnsafeRawPointer(bitPattern: "KEY_sh_interactivePopMaxAllowedInitialDistanceToLeftEdge".hashValue)
    static let KEY_sh_fullscreenPopGestureRecognizer
        = UnsafeRawPointer(bitPattern: "KEY_sh_fullscreenPopGestureRecognizer".hashValue)
    static let KEY_sh_popGestureRecognizerDelegate
        = UnsafeRawPointer(bitPattern: "KEY_sh_popGestureRecognizerDelegate".hashValue)
    static let KEY_sh_viewControllerBasedNavigationBarAppearanceEnabled
        = UnsafeRawPointer(bitPattern: "KEY_sh_viewControllerBasedNavigationBarAppearanceEnabled".hashValue)
    static let KEY_sh_scrollViewPopGestureRecognizerEnable
        = UnsafeRawPointer(bitPattern: "KEY_sh_scrollViewPopGestureRecognizerEnable".hashValue)
}

extension UIScrollView: UIGestureRecognizerDelegate {
    
    private struct AssociatedKeys {
        
        static var shouldRecognizeSimultaneously = "shouldRecognizeSimultaneously"
        
        static var isDirectionalControlEnable = "isDirectionalControlEnable"
        
        static var isScrollHorizontal = "isScrollHorizontal"
                
    }
    
    public var sc_scrollViewPopGestureRecognizerEnable: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, RuntimeKey.KEY_sh_scrollViewPopGestureRecognizerEnable!) as? Bool else {
                return false
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, RuntimeKey.KEY_sh_scrollViewPopGestureRecognizerEnable!, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    public var shouldRecognizeSimultaneously: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, &AssociatedKeys.shouldRecognizeSimultaneously) as? Bool else {
                return false
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.shouldRecognizeSimultaneously, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    public var isDirectionalControlEnable: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, &AssociatedKeys.isDirectionalControlEnable) as? Bool else {
                return false
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isDirectionalControlEnable, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    public var isScrollHorizontal: Bool {
        get {
            guard let bools = objc_getAssociatedObject(self, &AssociatedKeys.isScrollHorizontal) as? Bool else {
                return false
            }
            return bools
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isScrollHorizontal, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.sc_scrollViewPopGestureRecognizerEnable, self.contentOffset.x <= 0, let gestureDelegate = otherGestureRecognizer.delegate {
            if gestureDelegate.isKind(of: _SCFullscreenPopGestureRecognizerDelegate.self) {
                return true
            }
        }
        return self.shouldRecognizeSimultaneously
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if self.isDirectionalControlEnable {
            if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
                let point = gestureRecognizer.translation(in: gestureRecognizer.view)
                if self.isScrollHorizontal {
                    return abs(point.x) >= abs(point.y)
                } else {
                    return abs(point.x) <= abs(point.y)
                }
                
            }
        }
        return true
    }
    
}

fileprivate extension DispatchQueue {
    
    private static var _onceTracker = [String]()
    
    /**
     Executes a block of code, associated with a unique token, only once.  The code is thread safe and will
     only execute the code once even in the presence of multithreaded calls.
     
     - parameter token: A unique reverse DNS style name such as com.vectorform.<name> or a GUID
     - parameter block: Block to execute once
     */
    class func once(token: String, block: () -> Void) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if _onceTracker.contains(token) {
            return
        }
        
        _onceTracker.append(token)
        block()
    }
}
