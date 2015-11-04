//

//  ZLSwipeableView.swift

//  ZLSwipeableViewSwiftDemo

//

//  Created by Zhixuan Lai on 4/27/15.

//  Copyright (c) 2015 Zhixuan Lai. All rights reserved.

//



import UIKit

// data source
public typealias NextViewHandler = () -> UIView?
public typealias PreviousViewHandler = () -> UIView?

// customization
public typealias AnimateViewHandler = (_ view: UIView, _ index: Int, _ views: [UIView], _ swipeableView: ZLSwipeableView) -> ()
public typealias InterpretDirectionHandler = (_ topView: UIView, _ direction: Direction, _ views: [UIView], _ swipeableView: ZLSwipeableView) -> (CGPoint, CGVector)
public typealias ShouldSwipeHandler = (_ view: UIView, _ movement: Movement, _ swipeableView: ZLSwipeableView) -> Bool

// delegates
public typealias DidStartHandler = (_ view: UIView, _ atLocation: CGPoint) -> ()
public typealias SwipingHandler = (_ view: UIView, _ atLocation: CGPoint, _ translation: CGPoint) -> ()
public typealias DidEndHandler = (_ view: UIView, _ atLocation: CGPoint) -> ()
public typealias DidSwipeHandler = (_ view: UIView, _ inDirection: Direction, _ directionVector: CGVector) -> ()
public typealias DidCancelHandler = (_ view: UIView) -> ()
public typealias DidTap = (_ view: UIView, _ atLocation: CGPoint) -> ()
public typealias DidDisappear = (_ view: UIView) -> ()

public struct Movement {
    public let location: CGPoint
    public let translation: CGPoint
    public let velocity: CGPoint
}


class ZLPanGestureRecognizer: UIPanGestureRecognizer {
    
    
    
}



public func ==(lhs: ZLSwipeableViewDirection, rhs: ZLSwipeableViewDirection) -> Bool {
    
    return lhs.rawValue == rhs.rawValue
    
}



public struct ZLSwipeableViewDirection : OptionSetType, CustomStringConvertible {
    
    public var rawValue: UInt
    
    
    
    public init(rawValue: UInt) {
        
        self.rawValue = rawValue
        
    }
    
    
    
    // MARK: NilLiteralConvertible
    
    public init(nilLiteral: ()) {
        
        self.rawValue = 0
        
    }
    
    
    
    // MARK: BitwiseOperationsType
    
    public static var allZeros: ZLSwipeableViewDirection {
        
        return self.init(rawValue: 0)
        
    }
    
    
    
    static var None: ZLSwipeableViewDirection       { return self.init(rawValue: 0b0000) }
    
    static var Left: ZLSwipeableViewDirection       { return self.init(rawValue: 0b0001) }
    
    static var Right: ZLSwipeableViewDirection      { return self.init(rawValue: 0b0010) }
    
    static var Up: ZLSwipeableViewDirection         { return self.init(rawValue: 0b0100) }
    
    static var Down: ZLSwipeableViewDirection       { return self.init(rawValue: 0b1000) }
    
    static var Horizontal: ZLSwipeableViewDirection { return Left.union(Right) }
    
    static var Vertical: ZLSwipeableViewDirection   { return Up.union(Down) }
    
    static var All: ZLSwipeableViewDirection        { return Horizontal.union(Vertical) }
    
    
    
    static func fromPoint(point: CGPoint) -> ZLSwipeableViewDirection {
        
        switch (point.x, point.y) {
            
        case let (x, y) where abs(x)>=abs(y) && x>=0:
            
            return .Right
            
        case let (x, y) where abs(x)>=abs(y) && x<0:
            
            return .Left
            
        case let (x, y) where abs(x)<abs(y) && y<=0:
            
            return .Up
            
        case let (x, y) where abs(x)<abs(y) && y>0:
            
            return .Down
            
        case let (x, y):
            
            return .None
            
        }
        
    }
    
    
    
    public var description: String {
        
        switch self {
            
        case ZLSwipeableViewDirection.None:
            
            return "None"
            
        case ZLSwipeableViewDirection.Left:
            
            return "Left"
            
        case ZLSwipeableViewDirection.Right:
            
            return "Right"
            
        case ZLSwipeableViewDirection.Up:
            
            return "Up"
            
        case ZLSwipeableViewDirection.Down:
            
            return "Down"
            
        case ZLSwipeableViewDirection.Horizontal:
            
            return "Horizontal"
            
        case ZLSwipeableViewDirection.Vertical:
            
            return "Vertical"
            
        case ZLSwipeableViewDirection.All:
            
            return "All"
            
        default:
            
            return "Unknown"
            
        }
        
    }
    
}



public class ZLSwipeableView: UIView {
    
    // MARK: - Public
    
    deinit {
        
        timer?.invalidate()
        
        animator.removeAllBehaviors()
        
        pushAnimator.removeAllBehaviors()
        
        views.removeAll()
        
        pushBehaviors.removeAll()
        
    }
    
    
    // MARK: Data Source
    public var numberOfActiveView = UInt(4)
    public var nextView: NextViewHandler? {
        didSet {
            loadViews()
        }
    }
    public var previousView: PreviousViewHandler?
    // Rewinding
    public var history = [UIView]()
    public var numberOfHistoryItem = UInt(10)

    // MARK: Customizable behavior
    public var animateView = ZLSwipeableView.defaultAnimateViewHandler()
    public var interpretDirection = ZLSwipeableView.defaultInterpretDirectionHandler()
    public var shouldSwipeView = ZLSwipeableView.defaultShouldSwipeViewHandler()
    public var minTranslationInPercent = CGFloat(0.25)
    public var minVelocityInPointPerSecond = CGFloat(750)
    public var allowedDirection = Direction.Horizontal
    public var onlySwipeTopCard = false

    // MARK: Delegate
    public var didStart: DidStartHandler?
    public var swiping: SwipingHandler?
    public var didEnd: DidEndHandler?
    public var didSwipe: DidSwipeHandler?
    public var didCancel: DidCancelHandler?
    public var didTap: DidTap?
    public var didDisappear: DidDisappear?

    // MARK: Private properties
    /// Contains subviews added by the user.
    private var containerView = UIView()

    /// Contains auxiliary subviews.
    private var miscContainerView = UIView()

    private var animator: UIDynamicAnimator!

    private var viewManagers = [UIView: ViewManager]()

    private var scheduler = Scheduler()

    // MARK: Life cycle
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        addSubview(containerView)
        addSubview(miscContainerView)
        animator = UIDynamicAnimator(referenceView: self)
    }

    deinit {
        nextView = nil

        didStart = nil
        swiping = nil
        didEnd = nil
        didSwipe = nil
        didCancel = nil
        didDisappear = nil
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        containerView.frame = bounds
    }

    // MARK: Public APIs
    public func topView() -> UIView? {
        return activeViews().first
    }

    // top view first
    public func activeViews() -> [UIView] {
        return allViews().filter() {
            view in
            guard let viewManager = viewManagers[view] else { return false }
            if case .Swiping(_) = viewManager.state {
                return false
            }
            return true
        }.reverse()
    }

    public func loadViews() {
        for _ in UInt(activeViews().count) ..< numberOfActiveView {
            if let nextView = nextView?() {
                insert(nextView, atIndex: 0)
            }
        }
        updateViews()
    }

    public func rewind() {
        var viewToBeRewinded: UIView?
        if let lastSwipedView = history.popLast() {
            viewToBeRewinded = lastSwipedView
        } else if let view = previousView?() {
            viewToBeRewinded = view
        }

        guard let view = viewToBeRewinded else { return }

        if UInt(activeViews().count) == numberOfActiveView && activeViews().first != nil {
            remove(activeViews().last!)
        }
        insert(view, atIndex: allViews().count)
        updateViews()
    }

    public func discardViews() {
        for view in allViews() {
            remove(view)
        }
    }

    public func swipeTopView(inDirection direction: Direction) {
        guard let topView = topView() else { return }
        let (location, directionVector) = interpretDirection(topView: topView, direction: direction, views: activeViews(), swipeableView: self)
        swipeTopView(fromPoint: location, inDirection: directionVector)
    }

    public func swipeTopView(fromPoint location: CGPoint, inDirection directionVector: CGVector) {
        guard let topView = topView(), let topViewManager = viewManagers[topView] else { return }
        topViewManager.state = .Swiping(location, directionVector)
        swipeView(topView, location: location, directionVector: directionVector)
    }

    // MARK: Private APIs
    private func allViews() -> [UIView] {
        return containerView.subviews
    }

    private func insert(view: UIView, atIndex index: Int) {
        guard !allViews().contains(view) else {
            // this view has been schedule to be removed
            guard let viewManager = viewManagers[view] else { return }
            viewManager.state = viewManager.snappingStateAtContainerCenter()
            return
        }

        let viewManager = ViewManager(view: view, containerView: containerView, index: index, miscContainerView: miscContainerView, animator: animator, swipeableView: self)
        viewManagers[view] = viewManager
    }

    private func remove(view: UIView) {
        guard allViews().contains(view) else { return }

        viewManagers.removeValueForKey(view)
        self.didDisappear?(view: view)
    }

    public func updateViews() {
        let activeViews = self.activeViews()
        let inactiveViews = allViews().arrayByRemoveObjectsInArray(activeViews)

        for view in inactiveViews {
            view.userInteractionEnabled = false
        }

        guard let gestureRecognizers = activeViews.first?.gestureRecognizers , gestureRecognizers.filter({ gestureRecognizer in gestureRecognizer.state != .Possible }).count == 0 else { return }

        for i in 0 ..< activeViews.count {
            let view = activeViews[i]
            view.userInteractionEnabled = onlySwipeTopCard ? i == 0 : true
            let shouldBeHidden = i >= Int(numberOfActiveView)
            view.hidden = shouldBeHidden
            guard !shouldBeHidden else { continue }
            animateView(view: view, index: i, views: activeViews, swipeableView: self)
        }
    }

    func swipeView(view: UIView, location: CGPoint, directionVector: CGVector) {
        let direction = Direction.fromPoint(CGPoint(x: directionVector.dx, y: directionVector.dy))

        scheduleToBeRemoved(view) { aView in
            !CGRectIntersectsRect(self.containerView.convertRect(aView.frame, toView: nil), UIScreen.mainScreen().bounds)
        }
        didSwipe?(view: view, inDirection: direction, directionVector: directionVector)
        loadViews()
    }

    func scheduleToBeRemoved(view: UIView, withPredicate predicate: (UIView) -> Bool) {
        guard allViews().contains(view) else { return }

        history.append(view)
        if UInt(history.count) > numberOfHistoryItem {
            history.removeFirst()
        }
        scheduler.scheduleRepeatedly({ () -> Void in
            self.allViews().arrayByRemoveObjectsInArray(self.activeViews()).filter({ view in predicate(view) }).forEach({ view in self.remove(view) })
            }, interval: 0.3) { () -> Bool in
                return self.activeViews().count == self.allViews().count
        }
    }

}

extension CGPoint {
    
    var normalized: CGPoint {
        
        return CGPoint(x: x/magnitude, y: y/magnitude)
        
    }
    
    var magnitude: CGFloat {
        
        return CGFloat(sqrtf(powf(Float(x), 2) + powf(Float(y), 2)))
        
    }
    
    static func areInSameTheDirection(p1: CGPoint, p2: CGPoint) -> Bool {
        
        func signNum(n: CGFloat) -> Int {
            
            return (n < 0.0) ? -1 : (n > 0.0) ? +1 : 0
            
        }
        
        return signNum(p1.x) == signNum(p2.x) && signNum(p1.y) == signNum(p2.y)
        
    }
    
}

// MARK: - Default behaviors
extension ZLSwipeableView {

    static func defaultAnimateViewHandler() -> AnimateViewHandler {
    
    //public var numPrefetchedViews = 3
    
   // public var nextView: (() -> UIView?)?
    
    // MARK: Animation
    
  //  public var animateView: (view: UIView, index: Int, views: [UIView], swipeableView: ZLSwipeableView) -> () = {
        
        func toRadian(degree: CGFloat) -> CGFloat {
            
            return degree * CGFloat(M_PI/100)
            
        }
        
        func rotateView(view: UIView, forDegree degree: CGFloat, duration: NSTimeInterval, offsetFromCenter offset: CGPoint, swipeableView: ZLSwipeableView) {
            
            UIView.animateWithDuration(duration, delay: 0, options: .AllowUserInteraction, animations: {
                
                view.center = swipeableView.convertPoint(swipeableView.center, fromView: swipeableView.superview)
                
                var transform = CGAffineTransformMakeTranslation(offset.x, offset.y)
                
                transform = CGAffineTransformRotate(transform, toRadian(degree))
                
                transform = CGAffineTransformTranslate(transform, -offset.x, -offset.y)
                
                view.transform = transform
                
                }, completion: nil)
            
        

        return { (view: UIView, index: Int, views: [UIView], swipeableView: ZLSwipeableView) in
            let degree = CGFloat(1)
            let duration = 0.4
            let offset = CGPoint(x: 0, y: CGRectGetHeight(swipeableView.bounds) * 0.3)

            switch index {
            case 0:
                rotateView(view, forDegree: 0, duration: duration, offsetFromCenter: offset, swipeableView: swipeableView)
                
            case 1:
                rotateView(view, forDegree: degree, duration: 0.4, offsetFromCenter: offset, swipeableView: swipeableView)
        
            case 2:
                rotateView(view, forDegree: -degree, duration: 0.4, offsetFromCenter: offset, swipeableView: swipeableView)
                
            default:
                rotateView(view, forDegree: 0, duration: 0.4, offsetFromCenter: offset, swipeableView: swipeableView)
                
            }
            
        }
        
        }
    
    
    
    // MARK: Delegate
    
    var didStart: ((_ view: UIView, _ atLocation: CGPoint) -> ())?
    
    var swiping: ((_ view: UIView, _ atLocation: CGPoint, _ translation: CGPoint) -> ())?
    
    var didEnd: ((_ view: UIView, _ atLocation: CGPoint) -> ())?
    
    var didSwipe: ((_ view: UIView, _ inDirection: ZLSwipeableViewDirection, _ directionVector: CGVector) -> ())?
    
    var didCancel: ((_ view: UIView) -> ())?
    
    
    
    // MARK: Swipe Control
    
    /// in percent
    
    var translationThreshold = CGFloat(0.25)
    
    var velocityThreshold = CGFloat(750)
    
    var direction = ZLSwipeableViewDirection.Horizontal
    
    
    
    var interpretDirection: (_ topView: UIView, _ direction: ZLSwipeableViewDirection, _ views: [UIView], _ swipeableView: ZLSwipeableView) -> (CGPoint, CGVector) = {(topView: UIView, direction: ZLSwipeableViewDirection, views: [UIView], swipeableView: ZLSwipeableView) in
        
        let programmaticSwipeVelocity = CGFloat(1000)
        
        let location = CGPoint(x: topView.center.x, y: topView.center.y*0.7)
        
        var directionVector: CGVector?
        
        switch direction {
            
        case ZLSwipeableViewDirection.Left:
            
            directionVector = CGVector(dx: -programmaticSwipeVelocity, dy: 0)
            
        case ZLSwipeableViewDirection.Right:
            
            directionVector = CGVector(dx: programmaticSwipeVelocity, dy: 0)
            
        case ZLSwipeableViewDirection.Up:
            
            directionVector = CGVector(dx: 0, dy: -programmaticSwipeVelocity)
            
        case ZLSwipeableViewDirection.Down:
            
            directionVector = CGVector(dx: 0, dy: programmaticSwipeVelocity)
            
        default:
            
            directionVector = CGVector(dx: 0, dy: 0)
            
        }
        
        return (location, directionVector!)
        
    }

    func defaultShouldSwipeViewHandler() -> ShouldSwipeHandler {
        return { (view: UIView, movement: Movement, swipeableView: ZLSwipeableView) -> Bool in
            let translation = movement.translation
            let velocity = movement.velocity
            let bounds = swipeableView.bounds
            let minTranslationInPercent = swipeableView.minTranslationInPercent
            let minVelocityInPointPerSecond = swipeableView.minVelocityInPointPerSecond
            let allowedDirection = swipeableView.allowedDirection

            func areTranslationAndVelocityInTheSameDirection() -> Bool {
                return CGPoint.areInSameTheDirection(translation, p2: velocity)
            }

            func isDirectionAllowed() -> Bool {
                return Direction.fromPoint(translation).intersect(allowedDirection) != .None
            }

            func isTranslationLargeEnough() -> Bool {
                return abs(translation.x) > minTranslationInPercent * bounds.width || abs(translation.y) > minTranslationInPercent * bounds.height
            }

            func isVelocityLargeEnough() -> Bool {
                return velocity.magnitude > minVelocityInPointPerSecond
            }

            return isDirectionAllowed() && areTranslationAndVelocityInTheSameDirection() && (isTranslationLargeEnough() || isVelocityLargeEnough())
    
        }
        }
        
        
    func swipeTopView(inDirection direction: ZLSwipeableViewDirection) {
        
        if let topView = topView() {
            
            let (location, directionVector) = interpretDirection(topView: topView, direction: direction, views: views, swipeableView: self)
            
            swipeTopView(topView, direction: direction, location: location, directionVector: directionVector)
            
        }
        }
        
        
        

    }

// MARK: - Deprecated APIs


    
    
    @available(*, deprecated: 1, message: "Use numberOfActiveView")
    public var numPrefetchedViews: UInt {
        get {
            return numberOfActiveView
        }
        set(newValue){
            numberOfActiveView = newValue

        }
    }
    
    public func swipeTopView(fromPoint location: CGPoint, inDirection directionVector: CGVector) {
        
        if let topView = topView() {
            
            let direction = ZLSwipeableViewDirection.fromPoint(CGPoint(x: directionVector.dx, y: directionVector.dy))
            
            swipeTopView(topView, direction: direction, location: location, directionVector: directionVector)
            
        }
        
    }

    @available(*, deprecated: 1, message: "Use allowedDirection")
    public var direction: Direction {
        get {
            return allowedDirection
        }
        set(newValue){
            allowedDirection = newValue
        }
    }

    @available(*, deprecated: 1, message: "Use minTranslationInPercent")
    public var translationThreshold: CGFloat {
        get {
            return minTranslationInPercent
        }
        set(newValue){
            minTranslationInPercent = newValue
        }
    }

    @available(*, deprecated: 1, message: "Use minVelocityInPointPerSecond")
    public var velocityThreshold: CGFloat {
        get {
            return minVelocityInPointPerSecond
            
        }
    }
    
    private func swipeTopView(topView: UIView, direction: ZLSwipeableViewDirection, location: CGPoint, directionVector: CGVector) {
        
        unsnapView()
        
        pushView(topView, fromPoint: location, inDirection: directionVector)
        
        removeFromViews(topView)
        
        loadViews()
        
        didSwipe?(view: topView, inDirection: direction, directionVector: directionVector)
        
    }
    
    
    
    // MARK: View Management
    
    private var views = [UIView]()
    
    
    
    public func topView() -> UIView? {
        
        return views.first
        
    }
    
    
    
    public func loadViews() {
        
        if views.count<numPrefetchedViews {
            
            for i in (views.count..<numPrefetchedViews) {
                
                if let nextView = nextView?() {
                    
                    nextView.addGestureRecognizer(ZLPanGestureRecognizer(target: self, action: Selector("handlePan:")))
                    
                    views.append(nextView)
                    
                    containerView.addSubview(nextView)
                    
                    containerView.sendSubviewToBack(nextView)
                    
                }
                
            }
            
        }
        
        
        if let topView = topView() {
            
            animateViews()
            
        }
        
    }
    


// MARK: - Helper extensions
public func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
    return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    // point: in the swipeableView's coordinate
    
    public func insertTopView(view: UIView, fromPoint point: CGPoint) {
        
        if views.contains(view) {
            
            print("Error: trying to insert a view that has been added")
            
        } else {
            
            if cleanUpWithPredicate({ aView in aView == view }).count == 0 {
                
                view.center = point
                
            }
            
            view.addGestureRecognizer(ZLPanGestureRecognizer(target: self, action: Selector("handlePan:")))
            
            views.insert(view, atIndex: 0)
            
            containerView.addSubview(view)
            
            snapView(view, toPoint: convertPoint(center, fromView: superview))
            
            animateViews()
            
        }
        
    }
    
    
    
    private func animateViews() {
        
        if let topView = topView() {
            
            for gestureRecognizer in topView.gestureRecognizers! {
                
                if gestureRecognizer.state != .Possible {
                    
                    return
                    
                }
                
            }
            
        }
        
        
        
        for i in (0..<views.count) {
            
            var view = views[i]
            
            view.userInteractionEnabled = i == 0
            
            animateView(view: view, index: i, views: views, swipeableView: self)
            
        }
        
    }
    
    
    
    public func discardViews() {
        
        unsnapView()
        
        //   detachView()
        
        animator.removeAllBehaviors()
        
        for aView in views {
            
            removeFromContainerView(aView)
            
        }
        
        views.removeAll(keepCapacity: false)
        
    }
    
    
    
    private func removeFromViews(view: UIView) {
        
        for i in 0..<views.count {
            
            if views[i] == view {
                
                view.userInteractionEnabled = false
                
                views.removeAtIndex(i)
                
                return
                
            }
            
        }
        
    }
    
    private func removeFromContainerView(aView: UIView) {
        
        for gestureRecognizer in aView.gestureRecognizers!{
            
            if gestureRecognizer.isKindOfClass(ZLPanGestureRecognizer.classForCoder()) {
                
                aView.removeGestureRecognizer(gestureRecognizer)
                
            }
            
        }
        
        aView.removeFromSuperview()
        
    }
    
    
    
    // MARK: - Private properties
    
    private var containerView = UIView()
    
    
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        setup()
        
    }
    
    
    
    required public init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        
        setup()
        
    }
    
    
    
    private func setup() {
        
        animator = UIDynamicAnimator(referenceView: self)
        
        pushAnimator = UIDynamicAnimator(referenceView: self)
        
        
        
        addSubview(containerView)
        
        addSubview(anchorContainerView)
        
    }
    
    
    
    
    
    override public func layoutSubviews() {
        
        super.layoutSubviews()
        
        containerView.frame = bounds
        
    }
    
    
    
    // MARK: Animator
    
    private var animator: UIDynamicAnimator!
    
    static private let anchorViewWidth = CGFloat(1000)
    
    private var anchorView = UIView(frame: CGRect(x: 0, y: 0, width: anchorViewWidth, height: anchorViewWidth))
    
    private var anchorContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    
    
    
    func handlePan(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translationInView(self)
        
        let location = recognizer.locationInView(self)
        
        let topView = recognizer.view!
        
        switch recognizer.state {
            
        case .Began:
            
            unsnapView()
            
            attachView(topView, toPoint: location)
            
            didStart?(view: topView, atLocation: location)
            
        case .Changed:
            
            unsnapView()
            
            attachView(topView, toPoint: location)
            
            swiping?(view: topView, atLocation: location, translation: translation)
            
        case .Ended, .Cancelled:
            
            detachView()
            
            let velocity = recognizer.velocityInView(self)
            
            let velocityMag = velocity.magnitude
            
            
            
            let directionChecked = ZLSwipeableViewDirection.fromPoint(translation).intersect(direction) != .None
            
            let signChecked = CGPoint.areInSameTheDirection(translation, p2: velocity)
            
            let translationChecked = abs(translation.x) > translationThreshold * bounds.width ||
                
                abs(translation.y) > translationThreshold * bounds.height
            
            let velocityChecked = velocityMag > velocityThreshold
            
            if directionChecked && signChecked && (translationChecked || velocityChecked){
                
                let normalizedTrans = translation.normalized
                
                let throwVelocity = max(velocityMag, velocityThreshold)
                
                let directionVector = CGVector(dx: normalizedTrans.x*throwVelocity, dy: normalizedTrans.y*throwVelocity)
                swipeTopView(topView, direction: direction, location: location, directionVector: directionVector)
                
                
                
                //                pushView(topView, fromPoint: location, inDirection: directionVector)
                
                //                removeFromViews(topView)
                
                //                didSwipe?(view: topView, inDirection: ZLSwipeableViewDirection.fromPoint(translation))
                
                //                loadViews()
                
            } else {
                
                snapView(topView, toPoint: convertPoint(center, fromView: superview))
                
                didCancel?(view: topView)
            }
            
            didEnd?(view: topView, atLocation: location)
            
        default:
            
            break
            
        }
        
    }
    
    
    
    private var snapBehavior: UISnapBehavior!
    
    private func snapView(aView: UIView, toPoint point: CGPoint) {
        
        unsnapView()
        
        snapBehavior = UISnapBehavior(item: aView, snapToPoint: point)
        
        snapBehavior!.damping = 0.75
        
        animator.addBehavior(snapBehavior)
        
    }
    
    private func unsnapView() {
        
        //     animator.removeBehavior(snapBehavior)
        
        snapBehavior = nil
        
    }
    
    
    
    private var attachmentViewToAnchorView: UIAttachmentBehavior?
    
    private var attachmentAnchorViewToPoint: UIAttachmentBehavior?
    
    private func attachView(aView: UIView, toPoint point: CGPoint) {
        
        if let attachmentViewToAnchorView = attachmentViewToAnchorView, let attachmentAnchorViewToPoint = attachmentAnchorViewToPoint {
            
            attachmentAnchorViewToPoint.anchorPoint = point
            
        } else {
            
            anchorView.center = point
            
            anchorView.backgroundColor = UIColor.blueColor()
            
            anchorView.hidden = true
            
            anchorContainerView.addSubview(anchorView)
            
            
            
            // attach aView to anchorView
            
            let p = aView.center
            
            attachmentViewToAnchorView = UIAttachmentBehavior(item: aView, offsetFromCenter: UIOffset(horizontal: -(p.x - point.x), vertical: -(p.y - point.y)), attachedToItem: anchorView, offsetFromCenter: UIOffsetZero)
            
            attachmentViewToAnchorView!.length = 0
            
            
            
            // attach anchorView to point
            
            attachmentAnchorViewToPoint = UIAttachmentBehavior(item: anchorView, offsetFromCenter: UIOffsetZero, attachedToAnchor: point)
            
            attachmentAnchorViewToPoint!.damping = 100
            
            attachmentAnchorViewToPoint!.length = 0
            
            
            
            animator.addBehavior(attachmentViewToAnchorView!)
            
            animator.addBehavior(attachmentAnchorViewToPoint!)
            
        }
        
    }
    
    private func detachView() {
        
        animator.removeBehavior(attachmentViewToAnchorView!)
        
        animator.removeBehavior(attachmentAnchorViewToPoint!)
        
        attachmentViewToAnchorView = nil
        
        attachmentAnchorViewToPoint = nil
        
    }
    
    
    
    // MARK: pushAnimator
    
    private var pushAnimator: UIDynamicAnimator!
    
    private var timer: NSTimer?
    
    private var pushBehaviors = [(UIView, UIView, UIAttachmentBehavior, UIPushBehavior)]()
    
    func cleanUp(timer: NSTimer) {
        
        cleanUpWithPredicate() { aView in
            
            !CGRectIntersectsRect(self.convertRect(aView.frame, toView: nil), UIScreen.mainScreen().bounds)
            
        }
        
        if pushBehaviors.count == 0 {
            
            timer.invalidate()
            
            self.timer = nil
            
        }
        
    }
    
    private func cleanUpWithPredicate(predicate: (UIView) -> Bool) -> [Int] {
        
        var indexes = [Int]()
        
        for i in 0..<pushBehaviors.count {
            
            let (anchorView, aView, attachment, push) = pushBehaviors[i]
            
            if predicate(aView) {
                
                anchorView.removeFromSuperview()
                
                removeFromContainerView(aView)
                
                pushAnimator.removeBehavior(attachment)
                
                pushAnimator.removeBehavior(push)
                
                indexes.append(i)
                
            }
            
        }
        
        
        
        for index in Array(indexes.reverse()) {
            
            pushBehaviors.removeAtIndex(index)
            
        }
        
        return indexes
        
    }
    
    
    
    private func pushView(aView: UIView, fromPoint point: CGPoint, inDirection direction: CGVector) {
        
        let anchorView = UIView(frame: CGRect(x: 0, y: 0, width: ZLSwipeableView.anchorViewWidth, height: ZLSwipeableView.anchorViewWidth))
        
        anchorView.center = point
        
        anchorView.backgroundColor = UIColor.greenColor()
        
        anchorView.hidden = true
        
        anchorContainerView.addSubview(anchorView)
        
        
        
        let p = aView.convertPoint(aView.center, fromView: aView.superview)
        
        let point = aView.convertPoint(point, fromView: aView.superview)
        
        let attachmentViewToAnchorView = UIAttachmentBehavior(item: aView, offsetFromCenter: UIOffset(horizontal: -(p.x - point.x), vertical: -(p.y - point.y)), attachedToItem: anchorView, offsetFromCenter: UIOffsetZero)
        
        attachmentViewToAnchorView.length = 0
        
        
        
        let pushBehavior = UIPushBehavior(items: [anchorView], mode: .Instantaneous)
        
        pushBehavior.pushDirection = direction
        
        
        
        pushAnimator.addBehavior(attachmentViewToAnchorView)
        
        pushAnimator.addBehavior(pushBehavior)
        
        
        
        pushBehaviors.append((anchorView, aView, attachmentViewToAnchorView, pushBehavior))
        
        
        
        if timer == nil {
            
            timer = NSTimer.scheduledTimerWithTimeInterval(0.3, target: self, selector: "cleanUp:", userInfo: nil, repeats: true)
            
        }
        
    }
    
    
    
    // MARK: - ()
    
}

